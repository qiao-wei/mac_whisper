import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../services/binary_service.dart';
import '../widgets/video_preview.dart';
import '../models/subtitle.dart';

class SubtitleItem {
  int? dbId;
  int id;
  String startTime;
  String endTime;
  String text;
  String translatedText;
  bool selected;

  SubtitleItem({
    this.dbId,
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
    required this.translatedText,
    this.selected = false,
  });
}

class SubtitleEditorPage extends StatefulWidget {
  final String? videoPath;
  final String? projectName;
  final String? projectId;

  const SubtitleEditorPage(
      {super.key, this.videoPath, this.projectName, this.projectId});

  @override
  State<SubtitleEditorPage> createState() => _SubtitleEditorPageState();
}

class _SubtitleEditorPageState extends State<SubtitleEditorPage> {
  bool _showPreview = true;
  String _previewMode = 'text';
  final Map<String, TextEditingController> _cellControllers = {};
  final Map<String, FocusNode> _cellFocusNodes = {};
  final _db = DatabaseService();
  bool _isEditingTitle = false;
  late String _title;
  final _titleController = TextEditingController();
  bool _isGenerating = false;
  String _progressText = '';
  String _selectedModel = 'base';
  bool _isDownloading = false;
  bool _downloadCancelled = false;
  static const _models = ['tiny', 'base', 'small', 'medium', 'large-v3'];
  final _scrollController = ScrollController();
  Process? _currentProcess;
  List<SubtitleItem> _previousSubtitles = [];
  final List<List<SubtitleItem>> _undoStack = [];
  final List<List<SubtitleItem>> _redoStack = [];
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  int? _hoveredRowId;

  List<SubtitleItem> _subtitles = [];

  @override
  void initState() {
    super.initState();
    _title = (widget.projectName ?? 'Subtitle Editor')
        .replaceAll(RegExp(r'\.[^.]+$'), '');
    _loadSubtitles();
    _loadSelectedModel();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final videoPath = await _db.getProjectVideoPath(widget.projectId!);
    if (videoPath != null) {
      _videoController = VideoPlayerController.file(File(videoPath));
      await _videoController!.initialize();
      setState(() => _videoInitialized = true);
    }
  }

  Future<void> _loadSelectedModel() async {
    final model = await _db.getConfig('selected_model');
    if (model != null && _models.contains(model)) {
      setState(() => _selectedModel = model);
    }
  }

  Future<void> _loadSubtitles() async {
    if (widget.projectId != null) {
      final data = await _db.getSubtitles(widget.projectId!);
      if (data.isNotEmpty) {
        setState(() {
          _subtitles = data
              .asMap()
              .entries
              .map((e) => SubtitleItem(
                    dbId: e.value['id'] as int,
                    id: e.key + 1,
                    startTime: _formatMsToTime(e.value['start_time'] as int),
                    endTime: _formatMsToTime(e.value['end_time'] as int),
                    text: e.value['text'] as String,
                    translatedText: e.value['translated_text'] as String? ?? '',
                    selected: e.key == 0,
                  ))
              .toList();
        });
        return;
      }
    }
  }

  Future<void> _saveSubtitles() async {
    if (widget.projectId == null) return;
    final data = _subtitles
        .map((s) => {
              'start_time': _parseTimeToMs(s.startTime),
              'end_time': _parseTimeToMs(s.endTime),
              'text': s.text,
              'translated_text': s.translatedText,
            })
        .toList();
    await _db.saveSubtitles(widget.projectId!, data);
  }

  Future<void> _updateProjectName(String name) async {
    if (widget.projectId != null) {
      await _db.updateProjectName(widget.projectId!, name);
    }
  }

  SubtitleItem? get _activeSubtitle =>
      _subtitles.where((s) => s.selected).firstOrNull;
  int get _selectedCount => _subtitles.where((s) => s.selected).length;

  List<SubtitleItem> _cloneSubtitles() => _subtitles
      .map((s) => SubtitleItem(
          dbId: s.dbId,
          id: s.id,
          startTime: s.startTime,
          endTime: s.endTime,
          text: s.text,
          translatedText: s.translatedText,
          selected: s.selected))
      .toList();

  void _pushUndo() {
    _undoStack.add(_cloneSubtitles());
    _redoStack.clear();
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_cloneSubtitles());
    setState(() => _subtitles = _undoStack.removeLast());
    _saveSubtitles();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_cloneSubtitles());
    setState(() => _subtitles = _redoStack.removeLast());
    _saveSubtitles();
  }

  // Expected file sizes for whisper GGML models (in bytes) - from HuggingFace
  static const _modelExpectedSizes = {
    'tiny': 77691713, // ~74 MB
    'base': 147951465, // ~141 MB
    'small': 487601967, // ~465 MB
    'medium': 1533763059, // ~1.43 GB
    'large': 3095033483, // ~2.88 GB (large-v3)
  };

  Future<bool> _isModelDownloaded(String model) async {
    final home = Platform.environment['HOME'];
    final dir = Directory('$home/.cache/whisper');
    if (!dir.existsSync()) return false;

    // Look for GGML model file (ggml-{model}.bin)
    final modelFile = File('${dir.path}/ggml-$model.bin');
    if (!modelFile.existsSync()) return false;

    // Check if file size matches expected size (complete download)
    final expectedSize = _modelExpectedSizes[model];
    if (expectedSize == null) return true; // Unknown model, assume complete

    final actualSize = modelFile.lengthSync();
    // Allow 1% tolerance for size comparison
    return actualSize >= expectedSize * 0.99;
  }

  void _stopProcess() {
    _currentProcess?.kill();
    _currentProcess = null;
    // Close HTTP client if downloading via HTTP
    if (_httpClient != null) {
      _downloadCancelled = true;
      _httpClient?.close(force: true);
      _httpClient = null;
    }
    // Restore previous subtitles or clear partial extraction
    if (_isGenerating) {
      if (_previousSubtitles.isNotEmpty) {
        _subtitles = List.from(_previousSubtitles);
      } else {
        _subtitles.clear();
      }
      _previousSubtitles.clear();
    }
    setState(() {
      _isGenerating = false;
      _isDownloading = false;
      _progressText = '';
    });
  }

  // Whisper GGML model download URLs from HuggingFace (whisper.cpp format)
  static const _modelUrls = {
    'tiny':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    'base':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    'small':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
    'medium':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin',
    'large':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin',
  };

  HttpClient? _httpClient;

  Future<bool> _downloadModel(String model) async {
    final url = _modelUrls[model];
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown model: $model')),
      );
      return false;
    }

    final home = Platform.environment['HOME'];
    final cacheDir = Directory('$home/.cache/whisper');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final fileName = url.split('/').last;
    final filePath = '${cacheDir.path}/$fileName';
    final file = File(filePath);

    // Check for existing partial download
    int existingBytes = 0;
    if (file.existsSync()) {
      existingBytes = file.lengthSync();
    }

    final dialogMessage = existingBytes > 0
        ? 'Model "$model" has a partial download (${(existingBytes / 1024 / 1024).toStringAsFixed(1)} MB). Resume download?'
        : 'Model "$model" is not downloaded. Download now?';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingBytes > 0 ? 'Resume Download' : 'Download Model'),
        content: Text(dialogMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existingBytes > 0 ? 'Resume' : 'Download')),
        ],
      ),
    );
    if (confirm != true) return false;

    setState(() {
      _isDownloading = true;
      _downloadCancelled = false;
      _progressText = 'Downloading 0%';
    });

    try {
      _httpClient = HttpClient();
      final request = await _httpClient!.getUrl(Uri.parse(url));

      // Add Range header for resume support
      if (existingBytes > 0) {
        request.headers.add('Range', 'bytes=$existingBytes-');
      }

      final response = await request.close();

      // Check response status
      // 200 = full content, 206 = partial content (resume supported)
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      // If server doesn't support resume (returns 200 instead of 206), start from beginning
      final bool resuming = response.statusCode == 206;
      int totalLength;
      int downloadedBytes;

      if (resuming) {
        // Server supports resume - get total length from Content-Range header
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          // Format: "bytes 1000-9999/10000"
          final match = RegExp(r'/(\d+)').firstMatch(contentRange);
          totalLength = match != null ? int.parse(match.group(1)!) : -1;
        } else {
          totalLength = existingBytes + response.contentLength;
        }
        downloadedBytes = existingBytes;
      } else {
        // Server doesn't support resume - start fresh
        totalLength = response.contentLength;
        downloadedBytes = 0;
      }

      // Open file in append mode if resuming, write mode otherwise
      final sink =
          file.openWrite(mode: resuming ? FileMode.append : FileMode.write);

      await for (final chunk in response) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalLength > 0) {
          final percent = (downloadedBytes / totalLength * 100).round();
          setState(() => _progressText = 'Downloading $percent%');
        }
      }
      await sink.close();
      _httpClient = null;

      return await _isModelDownloaded(model);
    } catch (e) {
      // Don't show error if download was cancelled by user
      if (mounted && !_downloadCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
      return false;
    } finally {
      setState(() {
        _isDownloading = false;
        _progressText = '';
      });
    }
  }

  static const _audioExtractorChannel =
      MethodChannel('com.macwhisper/audio_extractor');
  final _binaryService = BinaryService();

  Future<void> _generateSubtitles() async {
    final videoPath = await _db.getProjectVideoPath(widget.projectId!);
    if (videoPath == null) return;

    // Check if model is downloaded first
    if (!await _isModelDownloaded(_selectedModel)) {
      if (!await _downloadModel(_selectedModel)) return;
    }

    // Then ask about replacing existing subtitles
    if (_subtitles.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Subtitles'),
          content: const Text('This will delete existing subtitles. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Replace')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    _previousSubtitles = List.from(_subtitles);
    setState(() {
      _isGenerating = true;
      _progressText = 'Extracting audio...';
      _subtitles = [];
    });

    String? audioPath;
    try {
      // Step 1: Extract audio from video using native macOS APIs (outputs WAV)
      final appSupportDir = await _binaryService.appSupportDir;
      final videoName =
          videoPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final wavPath = '$appSupportDir/$videoName.wav';

      audioPath =
          await _audioExtractorChannel.invokeMethod<String>('extractAudio', {
        'videoPath': videoPath,
        'outputPath': wavPath,
      });

      if (audioPath == null) {
        throw Exception('Audio extraction returned null');
      }

      // Step 2: Transcribe audio using bundled whisper-cli
      setState(() => _progressText = 'Transcribing...');

      final whisperCliPath = await _binaryService.whisperCliPath;
      final home = Platform.environment['HOME'];
      final modelPath = '$home/.cache/whisper/ggml-$_selectedModel.bin';
      final srtPath = '$appSupportDir/$videoName.srt';

      // Verify model file exists
      final modelFile = File(modelPath);
      if (!modelFile.existsSync()) {
        throw Exception(
            'Model file not found: $modelPath. Please download the $_selectedModel model first.');
      }

      // Remove existing SRT file if any
      final srtFile = File(srtPath);
      if (srtFile.existsSync()) {
        srtFile.deleteSync();
      }

      print('Running whisper-cli: $whisperCliPath -m $modelPath -f $audioPath');

      _currentProcess = await Process.start(whisperCliPath, [
        '-m', modelPath,
        '-f', audioPath,
        '-l', 'auto', // Auto-detect language
        '-osrt', // Output SRT format
        '-of',
        '$appSupportDir/$videoName', // Output file path (without extension)
        '-pp', // Print progress
      ]);

      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        print('whisper stdout: $data');
        _parseWhisperCliOutput(data);
      });

      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('whisper stderr: $data');
        // Parse progress from whisper-cli
        final progressMatch = RegExp(r'progress\s*=\s*(\d+)').firstMatch(data);
        if (progressMatch != null) {
          setState(
              () => _progressText = 'Transcribing ${progressMatch.group(1)}%');
        }
      });

      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;

      if (exitCode == 0) {
        // Read generated SRT file
        if (_subtitles.isEmpty && srtFile.existsSync()) {
          _parseSrt(await srtFile.readAsString());
        }
        await _saveSubtitles();
      } else {
        throw Exception('Transcription failed (exit code: $exitCode)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      // Clean up temporary audio file
      if (audioPath != null) {
        try {
          File(audioPath).deleteSync();
        } catch (_) {}
      }
      _previousSubtitles.clear();
      setState(() {
        _isGenerating = false;
        _progressText = '';
      });
    }
  }

  void _parseWhisperCliOutput(String data) {
    // Parse whisper-cli output format: [00:00:00.000 --> 00:00:02.000] text
    final regex = RegExp(
        r'\[(\d{2}:\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[.,]\d{3})\]\s*(.*)');
    for (final line in data.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final start = match.group(1)!.replaceAll('.', ',');
        final end = match.group(2)!.replaceAll('.', ',');
        final text = match.group(3)?.trim() ?? '';
        if (text.isNotEmpty) {
          setState(() => _subtitles.add(SubtitleItem(
              id: _subtitles.length + 1,
              startTime: start,
              endTime: end,
              text: text,
              translatedText: '')));
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut);
            }
          });
        }
      }
    }
  }

  void _parseWhisperOutput(String data) {
    // Match whisper output: [00:00.000 --> 00:02.320] text (MM:SS.mmm format)
    final regex = RegExp(
        r'\[(\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}[.,]\d{3})\]\s*(.*)');
    for (final line in data.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        // Convert MM:SS.mmm to HH:MM:SS,mmm
        final start = '00:${match.group(1)!.replaceAll('.', ',')}';
        final end = '00:${match.group(2)!.replaceAll('.', ',')}';
        final text = match.group(3)?.trim() ?? '';
        if (text.isNotEmpty) {
          setState(() => _subtitles.add(SubtitleItem(
              id: _subtitles.length + 1,
              startTime: start,
              endTime: end,
              text: text,
              translatedText: '')));
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut);
            }
          });
        }
      }
    }
  }

  void _parseSrt(String content) {
    final blocks = content.trim().split(RegExp(r'\n\n+'));
    final items = <SubtitleItem>[];
    for (var i = 0; i < blocks.length; i++) {
      final lines = blocks[i].split('\n');
      if (lines.length >= 3) {
        final timeParts = lines[1].split(' --> ');
        if (timeParts.length == 2) {
          items.add(SubtitleItem(
            id: i + 1,
            startTime: timeParts[0].trim(),
            endTime: timeParts[1].trim(),
            text: lines.sublist(2).join('\n'),
            translatedText: '',
          ));
        }
      }
    }
    setState(() => _subtitles = items);
  }

  int _parseTimeToMs(String timeStr) {
    final parts = timeStr.split(':');
    final secParts = parts[2].split(',');
    return (int.parse(parts[0]) * 3600 +
                int.parse(parts[1]) * 60 +
                int.parse(secParts[0])) *
            1000 +
        int.parse(secParts[1]);
  }

  String _formatMsToTime(int totalMs) {
    final h = (totalMs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((totalMs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((totalMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final ms = (totalMs % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  double _getProgressPercentage(String timeStr) {
    final totalSeconds = _parseTimeToMs(timeStr) / 1000;
    const mockTotalDuration = 120.0;
    return (totalSeconds / mockTotalDuration * 100).clamp(0, 100);
  }

  void _handleRowClick(int id) {
    setState(() {
      for (var sub in _subtitles) {
        sub.selected = sub.id == id;
      }
    });
    final subtitle = _subtitles.firstWhere((s) => s.id == id);
    if (_videoController != null && _videoInitialized) {
      final duration = _parseDuration(subtitle.startTime) +
          const Duration(milliseconds: 100);
      _videoController!.seekTo(duration);
    }
  }

  void _handleSeek(Duration position) {
    // Find subtitle at this position
    for (var i = 0; i < _subtitles.length; i++) {
      final sub = _subtitles[i];
      final startTime = _parseDuration(sub.startTime);
      final endTime = _parseDuration(sub.endTime);
      if (position >= startTime && position <= endTime) {
        setState(() {
          for (var s in _subtitles) {
            s.selected = s.id == sub.id;
          }
        });
        // Scroll to this row (approximate row height of 48)
        if (_scrollController.hasClients) {
          final targetOffset = i * 48.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        break;
      }
    }
  }

  void _handleCheckboxClick(int index) {
    final selectedIndices = _subtitles
        .asMap()
        .entries
        .where((e) => e.value.selected)
        .map((e) => e.key)
        .toList();
    setState(() {
      if (selectedIndices.isEmpty) {
        _subtitles[index].selected = true;
      } else {
        final minSel = selectedIndices.reduce((a, b) => a < b ? a : b);
        final maxSel = selectedIndices.reduce((a, b) => a > b ? a : b);
        if (index >= minSel && index <= maxSel) {
          if (index == minSel || index == maxSel) {
            _subtitles[index].selected = false;
          }
        } else {
          final start = index < minSel ? index : minSel;
          final end = index > maxSel ? index : maxSel;
          for (var i = 0; i < _subtitles.length; i++) {
            _subtitles[i].selected = i >= start && i <= end;
          }
        }
      }
    });
  }

  void _handleMerge() {
    final selectedIndices = _subtitles
        .asMap()
        .entries
        .where((e) => e.value.selected)
        .map((e) => e.key)
        .toList();
    if (selectedIndices.length < 2) return;
    _pushUndo();
    final firstIdx = selectedIndices.reduce((a, b) => a < b ? a : b);
    final lastIdx = selectedIndices.reduce((a, b) => a > b ? a : b);
    final mergedSubs = _subtitles.sublist(firstIdx, lastIdx + 1);
    final newItem = SubtitleItem(
      id: mergedSubs.first.id,
      startTime: mergedSubs.first.startTime,
      endTime: mergedSubs.last.endTime,
      text: mergedSubs.map((s) => s.text).join(' '),
      translatedText: mergedSubs.map((s) => s.translatedText).join(' '),
      selected: true,
    );
    setState(() {
      _subtitles = [
        ..._subtitles.sublist(0, firstIdx),
        newItem,
        ..._subtitles.sublist(lastIdx + 1)
      ];
      for (var i = 0; i < _subtitles.length; i++) {
        _subtitles[i].id = i + 1;
      }
    });
    _saveSubtitles();
  }

  void _handleSplit() {
    final selectedIdx = _subtitles.indexWhere((s) => s.selected);
    if (selectedIdx == -1) return;
    _pushUndo();
    final original = _subtitles[selectedIdx];
    final startMs = _parseTimeToMs(original.startTime);
    final endMs = _parseTimeToMs(original.endTime);
    final midMs = startMs + (endMs - startMs) ~/ 2;
    final midTimeStr = _formatMsToTime(midMs);
    final firstHalf = SubtitleItem(
        id: original.id,
        startTime: original.startTime,
        endTime: midTimeStr,
        text: original.text,
        translatedText: original.translatedText,
        selected: true);
    final secondHalf = SubtitleItem(
        id: original.id + 1,
        startTime: midTimeStr,
        endTime: original.endTime,
        text: '',
        translatedText: '');
    setState(() {
      _subtitles = [
        ..._subtitles.sublist(0, selectedIdx),
        firstHalf,
        secondHalf,
        ..._subtitles.sublist(selectedIdx + 1)
      ];
      for (var i = 0; i < _subtitles.length; i++) {
        _subtitles[i].id = i + 1;
      }
    });
    _saveSubtitles();
  }

  void _saveCellValue(int id, String field, String newValue) {
    final idx = _subtitles.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final oldValue = switch (field) {
      'startTime' => _subtitles[idx].startTime,
      'endTime' => _subtitles[idx].endTime,
      'text' => _subtitles[idx].text,
      'translatedText' => _subtitles[idx].translatedText,
      _ => '',
    };
    if (oldValue != newValue) {
      _pushUndo();
      setState(() {
        switch (field) {
          case 'startTime':
            _subtitles[idx].startTime = newValue;
            break;
          case 'endTime':
            _subtitles[idx].endTime = newValue;
            break;
          case 'text':
            _subtitles[idx].text = newValue;
            break;
          case 'translatedText':
            _subtitles[idx].translatedText = newValue;
            break;
        }
      });
      _saveSubtitles();
    }
  }

  void _handleDelete(int id) {
    _pushUndo();
    setState(() {
      _subtitles.removeWhere((s) => s.id == id);
      for (var i = 0; i < _subtitles.length; i++) {
        _subtitles[i].id = i + 1;
      }
    });
    _saveSubtitles();
  }

  @override
  void dispose() {
    for (final c in _cellControllers.values) c.dispose();
    for (final f in _cellFocusNodes.values) f.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                        flex: _showPreview ? 60 : 100,
                        child: _buildSubtitleList()),
                    if (_showPreview)
                      Expanded(flex: 40, child: _buildPreviewPanel()),
                  ],
                ),
                Positioned(
                  left: _showPreview
                      ? MediaQuery.of(context).size.width * 0.6 - 14
                      : MediaQuery.of(context).size.width - 28,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _showPreview = !_showPreview),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E2029),
                            border: Border.all(color: Colors.grey.shade700),
                            shape: BoxShape.circle),
                        child: Icon(
                            _showPreview
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                            size: 16,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(6)),
              child:
                  const Icon(Icons.subtitles, color: Colors.white, size: 16)),
          const SizedBox(width: 12),
          _isEditingTitle
              ? SizedBox(
                  width: 600,
                  child: TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 18),
                    decoration: const InputDecoration(
                        isDense: true, border: InputBorder.none),
                    onSubmitted: (v) => setState(() {
                      _title = v;
                      _isEditingTitle = false;
                      _updateProjectName(v);
                    }),
                    onTapOutside: (_) => setState(() {
                      _title = _titleController.text;
                      _isEditingTitle = false;
                      _updateProjectName(_titleController.text);
                    }),
                  ),
                )
              : GestureDetector(
                  onDoubleTap: () => setState(() {
                    _titleController.text = _title;
                    _isEditingTitle = true;
                  }),
                  child: Text(_title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 18)),
                ),
          const Spacer(),
          // ElevatedButton(
          //     onPressed: () {},
          //     style: ElevatedButton.styleFrom(
          //         backgroundColor: const Color(0xFF2563EB),
          //         padding:
          //             const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          //     child: const Text('Merge to Video',
          //         style: TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          OutlinedButton(
              onPressed: _showExportDialog,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade600),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              child:
                  const Text('Export', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildSubtitleList() {
    return Container(
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade800))),
      child: Column(
        children: [
          _buildToolbar(),
          _buildTableHeader(),
          Expanded(
              child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _subtitles.length,
                  itemBuilder: (_, i) => _buildSubtitleRow(_subtitles[i], i))),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.undo, size: 18),
              color: _undoStack.isNotEmpty ? Colors.grey : Colors.grey.shade700,
              onPressed: _undoStack.isNotEmpty ? _undo : null),
          IconButton(
              icon: const Icon(Icons.redo, size: 18),
              color: _redoStack.isNotEmpty ? Colors.grey : Colors.grey.shade700,
              onPressed: _redoStack.isNotEmpty ? _redo : null),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.grey,
              onPressed: _selectedCount > 0
                  ? () {
                      _pushUndo();
                      setState(() => _subtitles.removeWhere((s) => s.selected));
                      _saveSubtitles();
                    }
                  : null),
          _buildMergeSplitButton(
              Icons.merge, 'Merge', _selectedCount >= 2, _handleMerge),
          _buildMergeSplitButton(
              Icons.content_cut, 'Split', _selectedCount == 1, _handleSplit),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.purple.shade900.withOpacity(0.6),
                Colors.blue.shade900.withOpacity(0.6)
              ]),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: Colors.purple.shade700.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.memory, size: 14, color: Colors.purple.shade300),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedModel,
                  dropdownColor: const Color(0xFF1E1E2E),
                  underline: const SizedBox(),
                  isDense: true,
                  icon: Icon(Icons.expand_more,
                      size: 16, color: Colors.purple.shade300),
                  items: _models
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.toUpperCase(),
                              style: TextStyle(
                                  color: Colors.purple.shade100,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.5))))
                      .toList(),
                  onChanged: _isGenerating || _isDownloading
                      ? null
                      : (v) {
                          setState(() => _selectedModel = v!);
                          _db.setConfig('selected_model', v!);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isGenerating || _isDownloading
              ? ElevatedButton(
                  onPressed: _stopProcess,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 6),
                    Text(_progressText, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 6),
                    const Icon(Icons.stop, size: 14)
                  ]))
              : ElevatedButton(
                  onPressed: _generateSubtitles,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 46),
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                  child: const Text('Transcribe',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 12))),
          const SizedBox(width: 8),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //   decoration: BoxDecoration(
          //       color: const Color(0xFF1E2433),
          //       borderRadius: BorderRadius.circular(6),
          //       border:
          //           Border.all(color: Colors.blue.shade900.withOpacity(0.3))),
          //   child: Row(children: [
          //     Icon(Icons.translate, size: 16, color: Colors.blue.shade400),
          //     const SizedBox(width: 8),
          //     Text('Translate All',
          //         style: TextStyle(
          //             color: Colors.blue.shade400,
          //             fontSize: 14,
          //             fontWeight: FontWeight.w500))
          //   ]),
          // ),
          // const SizedBox(width: 12),
          // Row(children: [
          //   const Text('English',
          //       style: TextStyle(color: Colors.grey, fontSize: 14)),
          //   const SizedBox(width: 4),
          //   Icon(Icons.keyboard_arrow_down,
          //       size: 14, color: Colors.grey.shade600)
          // ]),
        ],
      ),
    );
  }

  Widget _buildMergeSplitButton(
      IconData icon, String label, bool enabled, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: enabled ? Colors.blue.shade400 : Colors.grey.shade700),
              if (enabled) ...[
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: Colors.blue.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Checkbox(
                  value: _subtitles.isNotEmpty &&
                      _selectedCount == _subtitles.length,
                  tristate: true,
                  onChanged: (_) => setState(() {
                        final selectAll = _selectedCount != _subtitles.length;
                        for (var s in _subtitles) s.selected = selectAll;
                      }))),
          const SizedBox(
              width: 120,
              child: Text('TIME',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          const Expanded(
              child: Text('SUBTITLE TEXT',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          // const Expanded(
          //     child: Text('TRANSLATED TEXT',
          //         style: TextStyle(
          //             color: Colors.grey,
          //             fontSize: 11,
          //             fontWeight: FontWeight.w600))),
          const SizedBox(
              width: 96,
              child: Text('ACTIONS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildSubtitleRow(SubtitleItem sub, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredRowId = sub.id),
      onExit: (_) => setState(() => _hoveredRowId = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: sub.selected
              ? const Color(0xFF111C30)
              : (_hoveredRowId == sub.id ? const Color(0xFF0D1420) : null),
          border: Border(
              left: BorderSide(
                  color: sub.selected ? Colors.blue : Colors.transparent,
                  width: 2),
              bottom: BorderSide(color: Colors.grey.shade800.withOpacity(0.5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 40,
                child: Checkbox(
                    value: sub.selected,
                    onChanged: (_) => _handleCheckboxClick(index))),
            SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditableCell(sub, 'startTime', true),
                    const SizedBox(height: 4),
                    _buildEditableCell(sub, 'endTime', true),
                  ],
                )),
            Expanded(child: _buildEditableCell(sub, 'text', false)),
            // Expanded(child: _buildEditableCell(sub, 'translatedText', false)),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      color: Colors.grey.shade600,
                      onPressed: () => _handleDelete(sub.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                  const SizedBox(width: 8),
                  // IconButton(
                  //     icon: const Icon(Icons.text_fields, size: 16),
                  //     color: Colors.grey.shade600,
                  //     onPressed: () {},
                  //     padding: EdgeInsets.zero,
                  //     constraints: const BoxConstraints()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCell(SubtitleItem sub, String field, bool isTime) {
    final key = '${sub.id}_$field';
    String value;
    switch (field) {
      case 'startTime':
        value = sub.startTime;
        break;
      case 'endTime':
        value = sub.endTime;
        break;
      case 'text':
        value = sub.text;
        break;
      case 'translatedText':
        value = sub.translatedText;
        break;
      default:
        value = '';
    }

    _cellControllers.putIfAbsent(key, () => TextEditingController(text: value));
    _cellFocusNodes.putIfAbsent(key, () => FocusNode());
    final controller = _cellControllers[key]!;
    final focusNode = _cellFocusNodes[key]!;

    // Sync controller text if subtitle value changed externally
    if (controller.text != value && !focusNode.hasFocus) {
      controller.text = value;
    }

    final textColor = isTime
        ? Colors.grey
        : (field == 'translatedText'
            ? Colors.grey.shade400
            : Colors.grey.shade300);

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          setState(() {
            for (var s in _subtitles) s.selected = s.id == sub.id;
          });
          if (_videoController != null && _videoInitialized) {
            _videoController!.seekTo(_parseDuration(sub.startTime) +
                const Duration(milliseconds: 10));
          }
        } else {
          _saveCellValue(sub.id, field, controller.text);
        }
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: isTime ? 1 : null,
        style: TextStyle(
            fontSize: 14,
            fontFamily: isTime ? 'monospace' : null,
            color: textColor),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.blue)),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _videoInitialized && _videoController != null
                    ? VideoPreview(
                        controller: _videoController!,
                        initialized: _videoInitialized,
                        subtitles: _subtitles
                            .map((item) => Subtitle(
                                  index: item.id,
                                  startTime: _parseDuration(item.startTime),
                                  endTime: _parseDuration(item.endTime),
                                  text: item.text,
                                ))
                            .toList(),
                        onSeek: _handleSeek,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Duration _parseDuration(String time) {
    final parts = time.split(':');
    final secondParts = parts[2].split(',');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(secondParts[0]),
      milliseconds: secondParts.length > 1 ? int.parse(secondParts[1]) : 0,
    );
  }

  Future<void> _exportSubtitles(String format) async {
    final content = format == 'SRT'
        ? _generateSRT()
        : format == 'VTT'
            ? _generateVTT()
            : _generateASS();
    final ext = format.toLowerCase();
    final fileName = '${widget.projectName ?? 'subtitles'}.$ext';

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Subtitle File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to $outputPath')),
        );
      }
    }
  }

  String _generateSRT() {
    final buffer = StringBuffer();
    for (var i = 0; i < _subtitles.length; i++) {
      final sub = _subtitles[i];
      buffer.writeln(i + 1);
      buffer.writeln(
          '${sub.startTime.replaceAll(',', ',')} --> ${sub.endTime.replaceAll(',', ',')}');
      buffer.writeln(sub.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _generateVTT() {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < _subtitles.length; i++) {
      final sub = _subtitles[i];
      buffer.writeln(
          '${sub.startTime.replaceAll(',', '.')} --> ${sub.endTime.replaceAll(',', '.')}');
      buffer.writeln(sub.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _generateASS() {
    final buffer = StringBuffer();
    buffer.writeln('[Script Info]');
    buffer.writeln('Title: ${widget.projectName ?? 'Subtitles'}');
    buffer.writeln('ScriptType: v4.00+');
    buffer.writeln('\n[V4+ Styles]');
    buffer.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    buffer.writeln(
        'Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1');
    buffer.writeln('\n[Events]');
    buffer.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
    for (var sub in _subtitles) {
      final start = sub.startTime.replaceAll(',', '.').substring(0, 10);
      final end = sub.endTime.replaceAll(',', '.').substring(0, 10);
      buffer.writeln('Dialogue: 0,$start,$end,Default,,0,0,0,,${sub.text}');
    }
    return buffer.toString();
  }

  void _showExportDialog() {
    String selectedFormat = 'SRT';
    bool mergeToVideo = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF161d2c),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Export Options',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          'Select the format and merge options for your subtitles.',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Format',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                              color: const Color(0xFF101622),
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: ['SRT', 'VTT', 'ASS']
                                .map((format) => Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => selectedFormat = format),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: selectedFormat == format
                                                ? const Color(0xFF2c3752)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(format,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: selectedFormat ==
                                                          format
                                                      ? Colors.white
                                                      : Colors.grey.shade400)),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      // const Padding(
                      //   padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      //   child: Text('Select Export Language',
                      //       style: TextStyle(
                      //           fontSize: 16,
                      //           fontWeight: FontWeight.bold,
                      //           color: Colors.white)),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: 16, vertical: 12),
                      //   child: Column(
                      //     children: [
                      //       Container(
                      //         height: 36,
                      //         decoration: BoxDecoration(
                      //           border:
                      //               Border.all(color: const Color(0xFF324467)),
                      //           borderRadius: BorderRadius.circular(8),
                      //           color: const Color(0xFF101622),
                      //         ),
                      //         child: DropdownButtonHideUnderline(
                      //           child: DropdownButton<String>(
                      //             value: 'original',
                      //             isExpanded: true,
                      //             dropdownColor: const Color(0xFF1E1E2E),
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 12),
                      //             icon: Icon(Icons.expand_more,
                      //                 size: 20, color: Colors.grey.shade400),
                      //             items: const [
                      //               DropdownMenuItem(
                      //                   value: 'original',
                      //                   child: Text(
                      //                       'Original Language (English)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //               DropdownMenuItem(
                      //                   value: 'translation1',
                      //                   child: Text(
                      //                       'Translated Language 1 (Spanish)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //               DropdownMenuItem(
                      //                   value: 'translation2',
                      //                   child: Text(
                      //                       'Translated Language 2 (French)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //             ],
                      //             onChanged: (v) {},
                      //           ),
                      //         ),
                      //       ),
                      //       const SizedBox(height: 12),
                      //       Container(
                      //         height: 36,
                      //         decoration: BoxDecoration(
                      //           border:
                      //               Border.all(color: const Color(0xFF324467)),
                      //           borderRadius: BorderRadius.circular(8),
                      //           color: const Color(0xFF101622),
                      //         ),
                      //         child: DropdownButtonHideUnderline(
                      //           child: DropdownButton<String>(
                      //             value: 'none',
                      //             isExpanded: true,
                      //             dropdownColor: const Color(0xFF1E1E2E),
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 12),
                      //             icon: Icon(Icons.expand_more,
                      //                 size: 20, color: Colors.grey.shade400),
                      //             items: const [
                      //               DropdownMenuItem(
                      //                   value: 'none',
                      //                   child: Text('None',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //               DropdownMenuItem(
                      //                   value: 'original',
                      //                   child: Text(
                      //                       'Original Language (English)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //               DropdownMenuItem(
                      //                   value: 'translation1',
                      //                   child: Text(
                      //                       'Translated Language 1 (Spanish)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //               DropdownMenuItem(
                      //                   value: 'translation2',
                      //                   child: Text(
                      //                       'Translated Language 2 (French)',
                      //                       style: TextStyle(
                      //                           fontSize: 13,
                      //                           color: Colors.white))),
                      //             ],
                      //             onChanged: (v) {},
                      //           ),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const Padding(
                      //   padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      //   child: Text('Video Output',
                      //       style: TextStyle(
                      //           fontSize: 16,
                      //           fontWeight: FontWeight.bold,
                      //           color: Colors.white)),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 16),
                      //   child: Row(
                      //     children: [
                      //       Checkbox(
                      //         value: mergeToVideo,
                      //         onChanged: (v) =>
                      //             setState(() => mergeToVideo = v ?? false),
                      //         fillColor: WidgetStateProperty.resolveWith(
                      //             (states) =>
                      //                 states.contains(WidgetState.selected)
                      //                     ? const Color(0xFF135bec)
                      //                     : Colors.transparent),
                      //         side: BorderSide(
                      //             color: Colors.grey.shade700, width: 2),
                      //       ),
                      //       const SizedBox(width: 8),
                      //       const Text('Merge subtitles into original video',
                      //           style: TextStyle(
                      //               fontSize: 14, color: Colors.white)),
                      //     ],
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      //   child: Text(
                      //       'This option is only available for local video files.',
                      //       style: TextStyle(
                      //           fontSize: 12, color: Colors.grey.shade400)),
                      // ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111722).withOpacity(0.6),
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exportSubtitles(selectedFormat);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF135bec),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: Text(mergeToVideo ? 'Export & Merge' : 'Export',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
