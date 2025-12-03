import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

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

  const SubtitleEditorPage({super.key, this.videoPath, this.projectName, this.projectId});

  @override
  State<SubtitleEditorPage> createState() => _SubtitleEditorPageState();
}

class _SubtitleEditorPageState extends State<SubtitleEditorPage> {
  bool _showPreview = true;
  String _previewMode = 'text';
  int? _editingId;
  String? _editingField;
  final _editController = TextEditingController();
  final _focusNode = FocusNode();
  final _db = DatabaseService();
  bool _isEditingTitle = false;
  late String _title;
  final _titleController = TextEditingController();
  bool _isGenerating = false;
  String _progressText = '';
  String _selectedModel = 'base';
  bool _isDownloading = false;
  static const _models = ['tiny', 'base', 'small', 'medium', 'large'];
  final _scrollController = ScrollController();
  Process? _currentProcess;
  List<SubtitleItem> _previousSubtitles = [];
  final List<List<SubtitleItem>> _undoStack = [];
  final List<List<SubtitleItem>> _redoStack = [];

  List<SubtitleItem> _subtitles = [];

  @override
  void initState() {
    super.initState();
    _title = widget.projectName ?? 'Subtitle Editor';
    _loadSubtitles();
    _loadSelectedModel();
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
          _subtitles = data.asMap().entries.map((e) => SubtitleItem(
            dbId: e.value['id'] as int,
            id: e.key + 1,
            startTime: _formatMsToTime(e.value['start_time'] as int),
            endTime: _formatMsToTime(e.value['end_time'] as int),
            text: e.value['text'] as String,
            translatedText: e.value['translated_text'] as String? ?? '',
            selected: e.key == 0,
          )).toList();
        });
        return;
      }
    }
  }

  Future<void> _saveSubtitles() async {
    if (widget.projectId == null) return;
    final data = _subtitles.map((s) => {
      'start_time': _parseTimeToMs(s.startTime),
      'end_time': _parseTimeToMs(s.endTime),
      'text': s.text,
      'translated_text': s.translatedText,
    }).toList();
    await _db.saveSubtitles(widget.projectId!, data);
  }

  Future<void> _updateProjectName(String name) async {
    if (widget.projectId != null) {
      await _db.updateProjectName(widget.projectId!, name);
    }
  }

  SubtitleItem? get _activeSubtitle => _subtitles.where((s) => s.selected).firstOrNull;
  int get _selectedCount => _subtitles.where((s) => s.selected).length;

  List<SubtitleItem> _cloneSubtitles() => _subtitles.map((s) => SubtitleItem(dbId: s.dbId, id: s.id, startTime: s.startTime, endTime: s.endTime, text: s.text, translatedText: s.translatedText, selected: s.selected)).toList();

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

  Future<bool> _isModelDownloaded(String model) async {
    final home = Platform.environment['HOME'];
    final dir = Directory('$home/.cache/whisper');
    if (!dir.existsSync()) return false;
    return dir.listSync().any((f) => f.path.contains('/$model'));
  }

  void _stopProcess() {
    _currentProcess?.kill();
    _currentProcess = null;
    // Delete partial model download
    if (_isDownloading || _progressText.contains('Downloading')) {
      final home = Platform.environment['HOME'];
      final dir = Directory('$home/.cache/whisper');
      if (dir.existsSync()) {
        for (final f in dir.listSync()) {
          if (f.path.contains('/$_selectedModel')) {
            try { f.deleteSync(); } catch (_) {}
          }
        }
      }
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
    setState(() { _isGenerating = false; _isDownloading = false; _progressText = ''; });
  }

  Future<bool> _downloadModel(String model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Model'),
        content: Text('Model "$model" is not downloaded. Download now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
        ],
      ),
    );
    if (confirm != true) return false;
    setState(() { _isDownloading = true; _progressText = 'Downloading 0%'; });
    try {
      // Use python to download the model directly
      _currentProcess = await Process.start('python3', ['-c', 'import whisper; whisper.load_model("$model")'], environment: {'PYTHONUNBUFFERED': '1'});
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        final match = RegExp(r'(\d+)%').firstMatch(data);
        if (match != null) setState(() => _progressText = 'Downloading ${match.group(1)}%');
      });
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        final match = RegExp(r'(\d+)%').firstMatch(data);
        if (match != null) setState(() => _progressText = 'Downloading ${match.group(1)}%');
      });
      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;
      return exitCode == 0 || await _isModelDownloaded(model);
    } finally {
      setState(() { _isDownloading = false; _progressText = ''; });
    }
  }

  Future<void> _generateSubtitles() async {
    final videoPath = await _db.getProjectVideoPath(widget.projectId!);
    if (videoPath == null) return;
    if (_subtitles.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Subtitles'),
          content: const Text('This will delete existing subtitles. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (!await _isModelDownloaded(_selectedModel)) {
      if (!await _downloadModel(_selectedModel)) return;
    }
    _previousSubtitles = List.from(_subtitles);
    setState(() { _isGenerating = true; _progressText = 'Extracting...'; _subtitles = []; });
    try {
      _currentProcess = await Process.start('whisper', [videoPath, '--model', _selectedModel, '--verbose', 'True', '--output_format', 'srt', '--output_dir', '/tmp'], environment: {'PYTHONUNBUFFERED': '1'});
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        print('stdout: $data');
        _parseWhisperOutput(data);
      });
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        print('stderr: $data');
        final match = RegExp(r'(\d+)%').firstMatch(data);
        if (match != null && data.contains('MiB')) {
          setState(() => _progressText = 'Downloading ${match.group(1)}%');
        } else if (data.contains('Detecting language') || data.contains('Detected language')) {
          setState(() => _progressText = 'Extracting...');
        }
        _parseWhisperOutput(data);
      });
      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;
      if (exitCode == 0) {
        // If no subtitles parsed in real-time, read from SRT file
        if (_subtitles.isEmpty) {
          final srtPath = '/tmp/${videoPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '.srt')}';
          final srtFile = File(srtPath);
          if (await srtFile.exists()) {
            _parseSrt(await srtFile.readAsString());
          }
        }
        await _saveSubtitles();
      }
    } finally {
      _previousSubtitles.clear();
      setState(() { _isGenerating = false; _progressText = ''; });
    }
  }

  void _parseWhisperOutput(String data) {
    // Match whisper output: [00:00.000 --> 00:02.320] text (MM:SS.mmm format)
    final regex = RegExp(r'\[(\d{2}:\d{2}[.,]\d{3})\s*-->\s*(\d{2}:\d{2}[.,]\d{3})\]\s*(.*)');
    for (final line in data.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        // Convert MM:SS.mmm to HH:MM:SS,mmm
        final start = '00:${match.group(1)!.replaceAll('.', ',')}';
        final end = '00:${match.group(2)!.replaceAll('.', ',')}';
        final text = match.group(3)?.trim() ?? '';
        if (text.isNotEmpty) {
          setState(() => _subtitles.add(SubtitleItem(id: _subtitles.length + 1, startTime: start, endTime: end, text: text, translatedText: '')));
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
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
    return (int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(secParts[0])) * 1000 + int.parse(secParts[1]);
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
  }

  void _handleCheckboxClick(int index) {
    final selectedIndices = _subtitles.asMap().entries.where((e) => e.value.selected).map((e) => e.key).toList();
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
    final selectedIndices = _subtitles.asMap().entries.where((e) => e.value.selected).map((e) => e.key).toList();
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
      _subtitles = [..._subtitles.sublist(0, firstIdx), newItem, ..._subtitles.sublist(lastIdx + 1)];
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
    final firstHalf = SubtitleItem(id: original.id, startTime: original.startTime, endTime: midTimeStr, text: original.text, translatedText: original.translatedText, selected: true);
    final secondHalf = SubtitleItem(id: original.id + 1, startTime: midTimeStr, endTime: original.endTime, text: '', translatedText: '');
    setState(() {
      _subtitles = [..._subtitles.sublist(0, selectedIdx), firstHalf, secondHalf, ..._subtitles.sublist(selectedIdx + 1)];
      for (var i = 0; i < _subtitles.length; i++) {
        _subtitles[i].id = i + 1;
      }
    });
    _saveSubtitles();
  }

  void _startEditing(int id, String field) {
    final sub = _subtitles.firstWhere((s) => s.id == id);
    String value;
    switch (field) {
      case 'startTime': value = sub.startTime; break;
      case 'endTime': value = sub.endTime; break;
      case 'text': value = sub.text; break;
      case 'translatedText': value = sub.translatedText; break;
      default: return;
    }
    _editController.text = value;
    setState(() {
      _editingId = id;
      _editingField = field;
      if (field == 'translatedText') _previewMode = 'translatedText';
      else if (field == 'text') _previewMode = 'text';
      for (var s in _subtitles) {
        s.selected = s.id == id;
      }
    });
    Future.delayed(const Duration(milliseconds: 50), () => _focusNode.requestFocus());
  }

  void _stopEditing() {
    if (_editingId != null && _editingField != null) {
      final idx = _subtitles.indexWhere((s) => s.id == _editingId);
      if (idx != -1) {
        final oldValue = switch (_editingField) {
          'startTime' => _subtitles[idx].startTime,
          'endTime' => _subtitles[idx].endTime,
          'text' => _subtitles[idx].text,
          'translatedText' => _subtitles[idx].translatedText,
          _ => '',
        };
        if (oldValue != _editController.text) _pushUndo();
        setState(() {
          switch (_editingField) {
            case 'startTime': _subtitles[idx].startTime = _editController.text; break;
            case 'endTime': _subtitles[idx].endTime = _editController.text; break;
            case 'text': _subtitles[idx].text = _editController.text; break;
            case 'translatedText': _subtitles[idx].translatedText = _editController.text; break;
          }
        });
        _saveSubtitles();
      }
    }
    setState(() {
      _editingId = null;
      _editingField = null;
    });
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
    _editController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
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
                    Expanded(flex: _showPreview ? 60 : 100, child: _buildSubtitleList()),
                    if (_showPreview) Expanded(flex: 40, child: _buildPreviewPanel()),
                  ],
                ),
                Positioned(
                  left: _showPreview ? MediaQuery.of(context).size.width * 0.6 - 14 : MediaQuery.of(context).size.width - 28,
                  top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _showPreview = !_showPreview),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: const Color(0xFF1E2029), border: Border.all(color: Colors.grey.shade700), shape: BoxShape.circle),
                        child: Icon(_showPreview ? Icons.chevron_right : Icons.chevron_left, size: 16, color: Colors.grey),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.subtitles, color: Colors.white, size: 16)),
          const SizedBox(width: 12),
          _isEditingTitle
              ? SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onSubmitted: (v) => setState(() { _title = v; _isEditingTitle = false; _updateProjectName(v); }),
                    onTapOutside: (_) => setState(() { _title = _titleController.text; _isEditingTitle = false; _updateProjectName(_titleController.text); }),
                  ),
                )
              : GestureDetector(
                  onDoubleTap: () => setState(() { _titleController.text = _title; _isEditingTitle = true; }),
                  child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple.shade900.withOpacity(0.6), Colors.blue.shade900.withOpacity(0.6)]),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.purple.shade700.withOpacity(0.5)),
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
                  icon: Icon(Icons.expand_more, size: 16, color: Colors.purple.shade300),
                  items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase(), style: TextStyle(color: Colors.purple.shade100, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)))).toList(),
                  onChanged: _isGenerating || _isDownloading ? null : (v) { setState(() => _selectedModel = v!); _db.setConfig('selected_model', v!); },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _isGenerating || _isDownloading
              ? ElevatedButton(onPressed: _stopProcess, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 8), Text(_progressText, style: const TextStyle(fontSize: 12)), const SizedBox(width: 8), const Icon(Icons.stop, size: 16)]))
              : ElevatedButton(onPressed: _generateSubtitles, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: const Text('Generate Subtitles', style: TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: const Text('Merge to Video', style: TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade600), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: const Text('Export Subtitles', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildSubtitleList() {
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade800))),
      child: Column(
        children: [
          _buildToolbar(),
          _buildTableHeader(),
          Expanded(child: ListView.builder(controller: _scrollController, itemCount: _subtitles.length, itemBuilder: (_, i) => _buildSubtitleRow(_subtitles[i], i))),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.undo, size: 18), color: _undoStack.isNotEmpty ? Colors.grey : Colors.grey.shade700, onPressed: _undoStack.isNotEmpty ? _undo : null),
          IconButton(icon: const Icon(Icons.redo, size: 18), color: _redoStack.isNotEmpty ? Colors.grey : Colors.grey.shade700, onPressed: _redoStack.isNotEmpty ? _redo : null),
          IconButton(icon: const Icon(Icons.delete_outline, size: 18), color: Colors.grey, onPressed: _selectedCount > 0 ? () { _pushUndo(); setState(() => _subtitles.removeWhere((s) => s.selected)); _saveSubtitles(); } : null),
          _buildMergeSplitButton(Icons.merge, 'Merge', _selectedCount >= 2, _handleMerge),
          _buildMergeSplitButton(Icons.content_cut, 'Split', _selectedCount == 1, _handleSplit),
          Container(width: 1, height: 16, color: Colors.grey.shade700, margin: const EdgeInsets.symmetric(horizontal: 8)),
          IconButton(icon: const Icon(Icons.upload, size: 18), color: Colors.grey, onPressed: () {}),
          IconButton(icon: const Icon(Icons.format_align_justify, size: 18), color: Colors.grey, onPressed: () {}),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF1E2433), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade900.withOpacity(0.3))),
            child: Row(children: [Icon(Icons.translate, size: 16, color: Colors.blue.shade400), const SizedBox(width: 8), Text('Translate All', style: TextStyle(color: Colors.blue.shade400, fontSize: 14, fontWeight: FontWeight.w500))]),
          ),
          const SizedBox(width: 12),
          Row(children: [const Text('English', style: TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey.shade600)]),
        ],
      ),
    );
  }

  Widget _buildMergeSplitButton(IconData icon, String label, bool enabled, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: enabled ? Colors.blue.shade400 : Colors.grey.shade700),
              if (enabled) ...[const SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.blue.shade400, fontSize: 12, fontWeight: FontWeight.w600))],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
      child: Row(
        children: [
          SizedBox(width: 40, child: Checkbox(value: _subtitles.isNotEmpty && _selectedCount == _subtitles.length, tristate: true, onChanged: (_) => setState(() { final selectAll = _selectedCount != _subtitles.length; for (var s in _subtitles) s.selected = selectAll; }))),
          const SizedBox(width: 96, child: Text('START TIME', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600))),
          const SizedBox(width: 96, child: Text('END TIME', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600))),
          const Expanded(child: Text('SUBTITLE TEXT', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600))),
          const Expanded(child: Text('TRANSLATED TEXT', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600))),
          const SizedBox(width: 96, child: Text('ACTIONS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildSubtitleRow(SubtitleItem sub, int index) {
    return GestureDetector(
      onTap: () => _handleRowClick(sub.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: sub.selected ? const Color(0xFF111C30) : null,
          border: Border(left: BorderSide(color: sub.selected ? Colors.blue : Colors.transparent, width: 2), bottom: BorderSide(color: Colors.grey.shade800.withOpacity(0.5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 40, child: Checkbox(value: sub.selected, onChanged: (_) => _handleCheckboxClick(index))),
            SizedBox(width: 96, child: _buildEditableCell(sub, 'startTime', true)),
            SizedBox(width: 96, child: _buildEditableCell(sub, 'endTime', true)),
            Expanded(child: _buildEditableCell(sub, 'text', false)),
            Expanded(child: _buildEditableCell(sub, 'translatedText', false)),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(icon: const Icon(Icons.delete_outline, size: 16), color: Colors.grey.shade600, onPressed: () => _handleDelete(sub.id), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.text_fields, size: 16), color: Colors.grey.shade600, onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.settings, size: 16), color: Colors.grey.shade600, onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCell(SubtitleItem sub, String field, bool isTime) {
    final isEditing = _editingId == sub.id && _editingField == field;
    String value;
    switch (field) {
      case 'startTime': value = sub.startTime; break;
      case 'endTime': value = sub.endTime; break;
      case 'text': value = sub.text; break;
      case 'translatedText': value = sub.translatedText; break;
      default: value = '';
    }
    if (isEditing) {
      return isTime
          ? TextField(controller: _editController, focusNode: _focusNode, style: const TextStyle(fontSize: 14, fontFamily: 'monospace'), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue)), filled: true, fillColor: const Color(0xFF1E2433)), onSubmitted: (_) => _stopEditing(), onTapOutside: (_) => _stopEditing())
          : TextField(controller: _editController, focusNode: _focusNode, maxLines: null, style: const TextStyle(fontSize: 14), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue)), filled: true, fillColor: const Color(0xFF1E2433)), onTapOutside: (_) => _stopEditing());
    }
    return GestureDetector(
      onTap: () => _startEditing(sub.id, field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.transparent)),
        child: Text(value, style: TextStyle(fontSize: 14, color: isTime ? Colors.grey : (field == 'translatedText' ? Colors.grey.shade400 : Colors.grey.shade300), fontFamily: isTime ? 'monospace' : null)),
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
              decoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade800)),
              child: Stack(
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)]))),
                  Center(child: Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, size: 32, color: Colors.white))),
                  if (_activeSubtitle != null)
                    Positioned(
                      left: 32, right: 32, bottom: 48,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                        child: Text(_previewMode == 'text' ? _activeSubtitle!.text : _activeSubtitle!.translatedText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      ),
                    ),
                  Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(4)), child: const Text('FPS: 24.0', style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace')))),
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                      child: Column(
                        children: [
                          Container(height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _activeSubtitle != null ? _getProgressPercentage(_activeSubtitle!.startTime) / 100 : 0, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))))),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_activeSubtitle?.startTime.split(',')[0].replaceFirst(RegExp(r'^00:'), '') ?? '00:00', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace')), const Text('02:00', style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'))]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Preview Mode', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Modifications in the list update in real-time', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}
