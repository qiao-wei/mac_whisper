import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle.dart';

class Timeline extends StatelessWidget {
  final VideoPlayerController controller;
  final bool initialized;
  final List<Subtitle> subtitles;

  const Timeline({
    super.key,
    required this.controller,
    required this.initialized,
    required this.subtitles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: const Color(0xFFF5F5F7),
      child: Column(
        children: [
          Container(height: 1, color: Colors.grey.shade300),
          Expanded(
            child: initialized
                ? ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (_, value, __) => _buildTimeline(value),
                  )
                : const Center(child: Text('加载中...')),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(VideoPlayerValue value) {
    final duration = value.duration.inMilliseconds;
    if (duration == 0) return const SizedBox();
    final position = value.position.inMilliseconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) {
            final ratio = details.localPosition.dx / width;
            controller
                .seekTo(Duration(milliseconds: (duration * ratio).toInt()));
          },
          child: Stack(
            children: [
              _buildSubtitleBlocks(width, duration),
              _buildPlayhead(width, position, duration),
              _buildTimeMarkers(width, duration),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtitleBlocks(double width, int duration) {
    return Positioned(
      top: 30,
      left: 0,
      right: 0,
      height: 30,
      child: Stack(
        children: subtitles.map((sub) {
          final start = sub.startTime.inMilliseconds / duration * width;
          final end = sub.endTime.inMilliseconds / duration * width;
          return Positioned(
            left: start,
            width: end - start,
            top: 0,
            bottom: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                sub.text,
                style: const TextStyle(fontSize: 10, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayhead(double width, int position, int duration) {
    final x = position / duration * width;
    return Positioned(
      left: x - 1,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Colors.red,
      ),
    );
  }

  Widget _buildTimeMarkers(double width, int duration) {
    final markers = <Widget>[];
    final interval = duration > 60000 ? 10000 : 5000;
    for (int ms = 0; ms <= duration; ms += interval) {
      final x = ms / duration * width;
      markers.add(Positioned(
        left: x,
        top: 8,
        child: Text(
          _formatMs(ms),
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        ),
      ));
    }
    return Stack(children: markers);
  }

  String _formatMs(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
