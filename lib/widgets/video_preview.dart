import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle.dart';

class VideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  final bool initialized;
  final List<Subtitle> subtitles;
  final void Function(Duration position)? onSeek;

  const VideoPreview({
    super.key,
    required this.controller,
    required this.initialized,
    required this.subtitles,
    this.onSeek,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  final FocusNode _focusNode = FocusNode();
  Timer? _seekTimer;
  static const _seekStep = Duration(seconds: 5);
  static const _continuousSeekInterval = Duration(milliseconds: 100);
  static const _continuousSeekStep = Duration(milliseconds: 500);

  @override
  void dispose() {
    _focusNode.dispose();
    _seekTimer?.cancel();
    super.dispose();
  }

  void _handleKeyDown(KeyEvent event) {
    if (!widget.initialized) return;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        // Toggle play/pause
        if (widget.controller.value.isPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Seek backward - only start timer on first press
        if (_seekTimer == null) {
          _seekBackward();
          _seekTimer = Timer.periodic(_continuousSeekInterval, (_) {
            _seekBackwardContinuous();
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Seek forward - only start timer on first press
        if (_seekTimer == null) {
          _seekForward();
          _seekTimer = Timer.periodic(_continuousSeekInterval, (_) {
            _seekForwardContinuous();
          });
        }
      }
    } else if (event is KeyUpEvent) {
      // Stop continuous seeking when key is released
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekTimer?.cancel();
        _seekTimer = null;
      }
    }
  }

  void _seekBackward() {
    final currentPos = widget.controller.value.position;
    final newPos = currentPos - _seekStep;
    final clampedPos = newPos < Duration.zero ? Duration.zero : newPos;
    widget.controller.seekTo(clampedPos);
    widget.onSeek?.call(clampedPos);
  }

  void _seekForward() {
    final currentPos = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPos = currentPos + _seekStep;
    final clampedPos = newPos > duration ? duration : newPos;
    widget.controller.seekTo(clampedPos);
    widget.onSeek?.call(clampedPos);
  }

  void _seekBackwardContinuous() {
    final currentPos = widget.controller.value.position;
    final newPos = currentPos - _continuousSeekStep;
    final clampedPos = newPos < Duration.zero ? Duration.zero : newPos;
    widget.controller.seekTo(clampedPos);
    widget.onSeek?.call(clampedPos);
  }

  void _seekForwardContinuous() {
    final currentPos = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPos = currentPos + _continuousSeekStep;
    final clampedPos = newPos > duration ? duration : newPos;
    widget.controller.seekTo(clampedPos);
    widget.onSeek?.call(clampedPos);
  }

  String? _getCurrentSubtitle() {
    if (!widget.initialized) return null;
    final pos = widget.controller.value.position;
    for (final sub in widget.subtitles) {
      if (pos >= sub.startTime && pos <= sub.endTime) {
        return sub.text;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyDown,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.initialized)
                AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                )
              else
                const CircularProgressIndicator(),
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: ValueListenableBuilder(
                  valueListenable: widget.controller,
                  builder: (_, value, __) {
                    final text = _getCurrentSubtitle();
                    if (text == null) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
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
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (ctx) => GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final box = ctx.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final pos = (details.localPosition.dx / box.size.width)
                            .clamp(0.0, 1.0);
                        final seekPosition = value.duration * pos;
                        widget.controller.seekTo(seekPosition);
                        widget.onSeek?.call(seekPosition);
                      }
                    },
                    onTapDown: (details) {
                      final box = ctx.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final pos = (details.localPosition.dx / box.size.width)
                            .clamp(0.0, 1.0);
                        final seekPosition = value.duration * pos;
                        widget.controller.seekTo(seekPosition);
                        widget.onSeek?.call(seekPosition);
                      }
                    },
                    child: Container(
                      height: 20,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = value.duration.inMilliseconds > 0
                              ? value.position.inMilliseconds /
                                  value.duration.inMilliseconds
                              : 0.0;
                          return Stack(
                            children: [
                              // Background bar
                              Container(
                                height: 4,
                                width: constraints.maxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Progress fill (left to right)
                              Container(
                                height: 4,
                                width: constraints.maxWidth * progress,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
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
