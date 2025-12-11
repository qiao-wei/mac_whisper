class Subtitle {
  final int index;
  Duration startTime;
  Duration endTime;
  String text;

  Subtitle({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  String get startTimeStr => _formatDuration(startTime);
  String get endTimeStr => _formatDuration(endTime);

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }
}
