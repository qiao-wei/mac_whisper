import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/subtitle.dart';
import '../widgets/subtitle_list.dart';
import '../widgets/timeline.dart';
import '../widgets/video_preview.dart';

class EditorPage extends StatefulWidget {
  final String videoPath;
  const EditorPage({super.key, required this.videoPath});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  int _selectedIndex = -1;
  final List<Subtitle> _subtitles = [];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() => _initialized = true);
      });
    _generateSampleSubtitles();
  }

  void _generateSampleSubtitles() {
    _subtitles.addAll([
      Subtitle(
        index: 1,
        startTime: const Duration(seconds: 0),
        endTime: const Duration(seconds: 3),
        text: '欢迎使用字幕编辑器',
      ),
      Subtitle(
        index: 2,
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 6),
        text: '这是第二条字幕',
      ),
      Subtitle(
        index: 3,
        startTime: const Duration(seconds: 6),
        endTime: const Duration(seconds: 9),
        text: '你可以编辑字幕内容',
      ),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSubtitle() {
    final position = _controller.value.position;
    setState(() {
      _subtitles.add(Subtitle(
        index: _subtitles.length + 1,
        startTime: position,
        endTime: position + const Duration(seconds: 3),
        text: '新字幕',
      ));
    });
  }

  void _deleteSubtitle(int index) {
    setState(() {
      _subtitles.removeAt(index);
      for (int i = 0; i < _subtitles.length; i++) {
        _subtitles[i] = Subtitle(
          index: i + 1,
          startTime: _subtitles[i].startTime,
          endTime: _subtitles[i].endTime,
          text: _subtitles[i].text,
        );
      }
      if (_selectedIndex >= _subtitles.length) {
        _selectedIndex = _subtitles.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: VideoPreview(
                    controller: _controller,
                    initialized: _initialized,
                    subtitles: _subtitles,
                  ),
                ),
                Container(width: 1, color: Colors.grey.shade800),
                Expanded(
                  flex: 2,
                  child: SubtitleList(
                    subtitles: _subtitles,
                    selectedIndex: _selectedIndex,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                    onAdd: _addSubtitle,
                    onDelete: _deleteSubtitle,
                    onUpdate: (i, text) {
                      setState(() {
                        _subtitles[i] = Subtitle(
                          index: _subtitles[i].index,
                          startTime: _subtitles[i].startTime,
                          endTime: _subtitles[i].endTime,
                          text: text,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Timeline(
            controller: _controller,
            initialized: _initialized,
            subtitles: _subtitles,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 48,
      color: const Color(0xFF2D2D2D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'mac_whisper - 字幕编辑器',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('导出'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
