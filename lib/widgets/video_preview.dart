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
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, value, __) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final pos = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                      controller.seekTo(value.duration * pos);
                    }
                  },
                  onTapDown: (details) {
                    final box = ctx.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final pos = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                      controller.seekTo(value.duration * pos);
                    }
                  },
                  child: Container(
                    height: 20,
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = value.duration.inMilliseconds > 0
                              ? value.position.inMilliseconds / value.duration.inMilliseconds
                              : 0.0;
                          return Container(
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
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
                    _formatDuration(value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
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
