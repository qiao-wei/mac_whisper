enum ProjectStatus { inProgress, completed }

class Project {
  final String id;
  final String name;
  final String? thumbnailPath;
  final ProjectStatus status;
  final DateTime createdAt;
  final String? videoPath;

  Project({
    required this.id,
    required this.name,
    this.thumbnailPath,
    required this.status,
    required this.createdAt,
    this.videoPath,
  });
}
