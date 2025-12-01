import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle.dart';

class VideoPreview extends StatelessWidget {
  final VideoPlayerController controller;
  final bool initialized;
  final List<Subtitle> subtitles;

  const VideoPreview({
    super.key,
    required this.controller,
    required this.initialized,
    required this.subtitles,
  });

  String? _getCurrentSubtitle() {
    if (!initialized) return null;
    final pos = controller.value.position;
    for (final sub in subtitles) {
      if (pos >= sub.startTime && pos <= sub.endTime) {
        return sub.text;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (initialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            )
          else
            const CircularProgressIndicator(),
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, value, __) {
                final text = _getCurrentSubtitle();
                if (text == null) return const SizedBox();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, value, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                value.isPlaying ? controller.pause() : controller.play();
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
