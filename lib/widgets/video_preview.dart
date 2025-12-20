import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle.dart';
import '../models/srt_font_config.dart';

class VideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  final bool initialized;
  final List<Subtitle> subtitles;
  final SrtFontConfig? fontConfig;
  final void Function(Duration position)? onSeek;

  const VideoPreview({
    super.key,
    required this.controller,
    required this.initialized,
    required this.subtitles,
    this.fontConfig,
    this.onSeek,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  final FocusNode _focusNode = FocusNode();
  static const _seekStep = Duration(seconds: 5);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyDown(KeyEvent event) {
    if (!widget.initialized) return;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (widget.controller.value.isPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBackward();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekForward();
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

  void _enterFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenVideoPlayer(
            controller: widget.controller,
            subtitles: widget.subtitles,
            fontConfig: widget.fontConfig,
            onSeek: widget.onSeek,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Get the alignment for subtitles based on fontConfig position
  Alignment _getSubtitleAlignment() {
    final position = widget.fontConfig?.position ?? SubtitlePosition.bottom;
    switch (position) {
      case SubtitlePosition.top:
        return Alignment.topCenter;
      case SubtitlePosition.center:
        return Alignment.center;
      case SubtitlePosition.bottom:
        return Alignment.bottomCenter;
    }
  }

  /// Get the padding for subtitles based on fontConfig position
  EdgeInsets _getSubtitlePadding(double videoHeight) {
    final position = widget.fontConfig?.position ?? SubtitlePosition.bottom;
    final marginPercent = widget.fontConfig?.marginPercent ?? 5.0;
    final marginPixels = videoHeight * (marginPercent / 100);
    switch (position) {
      case SubtitlePosition.top:
        return EdgeInsets.only(top: marginPixels, left: 20, right: 20);
      case SubtitlePosition.center:
        return const EdgeInsets.symmetric(horizontal: 20);
      case SubtitlePosition.bottom:
        return EdgeInsets.only(bottom: marginPixels, left: 20, right: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyDown(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        onDoubleTap: widget.initialized ? _enterFullscreen : null,
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.initialized)
                AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final videoHeight = constraints.maxHeight;
                      return Stack(
                        children: [
                          VideoPlayer(widget.controller),
                          Positioned.fill(
                            child: Align(
                              alignment: _getSubtitleAlignment(),
                              child: Padding(
                                padding: _getSubtitlePadding(videoHeight),
                                child: ValueListenableBuilder(
                                  valueListenable: widget.controller,
                                  builder: (_, value, __) {
                                    final text = _getCurrentSubtitle();
                                    if (text == null) return const SizedBox();
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical:
                                              widget.fontConfig?.bgPadding ??
                                                  4),
                                      decoration: BoxDecoration(
                                        color: (widget.fontConfig?.bgColor ??
                                                Colors.black)
                                            .withOpacity(
                                                widget.fontConfig?.bgOpacity ??
                                                    0.54),
                                        borderRadius: BorderRadius.circular(
                                            widget.fontConfig?.bgCornerRadius ??
                                                4),
                                      ),
                                      child: Text(
                                        text,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily:
                                              widget.fontConfig?.fontFamily ==
                                                      'System Default'
                                                  ? null
                                                  : widget.fontConfig?.fontFamily,
                                          color: widget.fontConfig?.fontColor ??
                                              Colors.white,
                                          fontSize:
                                              widget.fontConfig?.fontSize ?? 18,
                                          fontWeight:
                                              (widget.fontConfig?.isBold ?? false)
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                const CircularProgressIndicator(),
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
              SizedBox(
                width: 40,
                child: Text(
                  _formatDuration(value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
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
                              Container(
                                height: 4,
                                width: constraints.maxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
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
              SizedBox(
                width: 40,
                child: Text(
                  _formatDuration(value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: widget.initialized ? _enterFullscreen : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Fullscreen',
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

// Fullscreen video player overlay
class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final List<Subtitle> subtitles;
  final SrtFontConfig? fontConfig;
  final void Function(Duration position)? onSeek;

  const _FullscreenVideoPlayer({
    required this.controller,
    required this.subtitles,
    this.fontConfig,
    this.onSeek,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  final FocusNode _focusNode = FocusNode();
  bool _showControls = true;
  Timer? _hideControlsTimer;
  static const _seekStep = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  void _handleKeyDown(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (widget.controller.value.isPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
        _showControlsTemporarily();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBackward();
        _showControlsTemporarily();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekForward();
        _showControlsTemporarily();
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

  String? _getCurrentSubtitle() {
    final pos = widget.controller.value.position;
    for (final sub in widget.subtitles) {
      if (pos >= sub.startTime && pos <= sub.endTime) {
        return sub.text;
      }
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Get the alignment for subtitles based on fontConfig position
  Alignment _getSubtitleAlignment() {
    final position = widget.fontConfig?.position ?? SubtitlePosition.bottom;
    switch (position) {
      case SubtitlePosition.top:
        return Alignment.topCenter;
      case SubtitlePosition.center:
        return Alignment.center;
      case SubtitlePosition.bottom:
        return Alignment.bottomCenter;
    }
  }

  /// Get the padding for subtitles based on fontConfig position
  /// Uses percentage of video height for consistent positioning when merged
  EdgeInsets _getSubtitlePadding(double videoHeight) {
    final position = widget.fontConfig?.position ?? SubtitlePosition.bottom;
    final marginPercent = widget.fontConfig?.marginPercent ?? 5.0;
    final marginPixels = videoHeight * (marginPercent / 100);
    // Add extra space for controls at bottom (about 60px for fullscreen)
    final controlsOffset = position == SubtitlePosition.bottom ? 60 : 0;
    switch (position) {
      case SubtitlePosition.top:
        return EdgeInsets.only(top: marginPixels, left: 40, right: 40);
      case SubtitlePosition.center:
        return const EdgeInsets.symmetric(horizontal: 40);
      case SubtitlePosition.bottom:
        return EdgeInsets.only(
            bottom: marginPixels + controlsOffset, left: 40, right: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKeyDown(event);
          return KeyEventResult.handled;
        },
        child: MouseRegion(
          onHover: (_) => _showControlsTemporarily(),
          child: GestureDetector(
            onTap: _showControlsTemporarily,
            onDoubleTap: () => Navigator.of(context).pop(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: widget.controller.value.aspectRatio,
                    child: VideoPlayer(widget.controller),
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate video height from screen dimensions
                      final videoHeight = constraints.maxWidth /
                          widget.controller.value.aspectRatio;
                      return Align(
                        alignment: _getSubtitleAlignment(),
                        child: Padding(
                          padding: _getSubtitlePadding(videoHeight),
                          child: ValueListenableBuilder(
                            valueListenable: widget.controller,
                            builder: (_, value, __) {
                              final text = _getCurrentSubtitle();
                              if (text == null) return const SizedBox();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: widget.fontConfig?.fontFamily ==
                                            'System Default'
                                        ? null
                                        : widget.fontConfig?.fontFamily,
                                    color: widget.fontConfig?.fontColor ??
                                        Colors.white,
                                    fontSize:
                                        (widget.fontConfig?.fontSize ?? 18) *
                                            1.5,
                                    fontWeight:
                                        (widget.fontConfig?.isBold ?? false)
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_showControls) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Exit Fullscreen (Esc)',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildControls(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (_, value, __) {
        return Container(
          padding: const EdgeInsets.all(20),
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
                  size: 32,
                ),
                onPressed: () {
                  value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                },
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 50,
                child: Text(
                  _formatDuration(value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
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
                      height: 24,
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
                              Container(
                                height: 6,
                                width: constraints.maxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Container(
                                height: 6,
                                width: constraints.maxWidth * progress,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
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
              const SizedBox(width: 16),
              SizedBox(
                width: 50,
                child: Text(
                  _formatDuration(value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit,
                    color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Exit Fullscreen',
              ),
            ],
          ),
        );
      },
    );
  }
}
