import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import '../models/project.dart';
import '../services/database_service.dart';
import '../services/binary_service.dart';
// import 'editor_page.dart';
import 'subtitle_editor_page.dart';

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));
    final dashPath = Path();
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
            metric.extractPath(distance, distance + dashWidth), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeTab = 'All Projects';
  bool _isRightPanelOpen = true;
  String _searchQuery = '';
  String? _selectedProjectId;
  final _db = DatabaseService();
  final _binaryService = BinaryService();
  List<Project> _projects = [];
  bool _isLoading = true;
  bool _isDragging = false;
  String _sortBy = 'modified';
  bool _sortAsc = false;
  String _appVersion = 'v1.0.0';
  final _urlController = TextEditingController();
  bool _isDownloading = false;
  String _downloadProgress = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadSortPreference();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await _db.getConfig('app_version');
    if (version != null) setState(() => _appVersion = version);
  }

  Future<void> _loadSortPreference() async {
    final sort = await _db.getConfig('sort_by');
    final asc = await _db.getConfig('sort_asc');
    if (sort != null) setState(() => _sortBy = sort);
    if (asc != null) setState(() => _sortAsc = asc == 'true');
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getProjects();
    setState(() {
      _projects = projects;
      _isLoading = false;
    });
  }

  Future<void> _updateProject(Project p) async {
    await _db.updateProject(p);
    setState(() {});
  }

  Future<void> _deleteProject(Project p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${p.name}"?'),
        actions: [
          CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deleteProject(p.id);
    setState(() => _projects.removeWhere((proj) => proj.id == p.id));
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    final path = file.path;
    final name = file.name;
    final ext = name.split('.').last.toLowerCase();
    if (!['mp4', 'mov', 'mp3', 'wav', 'avi', 'mkv', 'm4a'].contains(ext))
      return;
    final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        status: ProjectStatus.inProgress,
        createdAt: DateTime.now(),
        videoPath: path);
    await _db.insertProject(project);
    setState(() => _projects.insert(0, project));
    if (mounted)
      _openSubtitleEditor(projectId: project.id, projectName: project.name);
  }

  List<Project> get _filteredProjects {
    var filtered = _projects
        .where((p) {
          if (_activeTab == 'In Progress')
            return p.status == ProjectStatus.inProgress;
          if (_activeTab == 'Completed')
            return p.status == ProjectStatus.completed;
          return true;
        })
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'name':
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'created':
          result = b.createdAt.compareTo(a.createdAt);
          break;
        case 'modified':
        default:
          result = b.modifiedAt.compareTo(a.modifiedAt);
      }
      return _sortAsc ? -result : result;
    });

    return filtered;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF101622),
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Container(
                        height: 96,
                        width: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.5),
                          border: Border.all(
                              color: const Color(0xFF334155).withOpacity(0.8)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.subtitles,
                            size: 48, color: Color(0xFF135BEC)),
                      ),
                      const SizedBox(height: 24),
                      const Text('MacWhisper',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2)),
                      const SizedBox(height: 8),
                      Text('Version $_appVersion',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 18)),
                      const SizedBox(height: 16),
                      const Text(
                        'A powerful macOS app for effortless subtitle extraction, editing, and translation from any audio or video source.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 16,
                            height: 1.5),
                      ),
                      const SizedBox(height: 48),
                      const Text('Core Features',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _buildFeatureCard(
                              Icons.movie,
                              'Smart Extraction',
                              'Automatically generate accurate subtitles from audio and video files.',
                              true),
                          _buildFeatureCard(
                              Icons.edit_square,
                              'Intuitive Editing',
                              'Easily proofread, modify timings, and edit text content.',
                              true),
                          _buildFeatureCard(
                              Icons.desktop_mac,
                              'Native macOS Feel',
                              'A clean and fluid interface that perfectly integrates with macOS.',
                              true),
                          _buildFeatureCard(
                              Icons.merge_type,
                              'Video Merging',
                              'Seamlessly merge your finished subtitles back into the original video.',
                              false),
                          _buildFeatureCard(
                              Icons.link,
                              'URL Support',
                              'Extract content directly from web links to simplify your workflow.',
                              false),
                          _buildFeatureCard(
                              Icons.translate,
                              'One-Click Translation',
                              'Instantly translate your subtitles into multiple languages.',
                              false),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.only(top: 24),
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade800)),
                        ),
                        child: const Text(
                            '© 2024 The MacWhisper Team. All Rights Reserved.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      IconData icon, String title, String description, bool enabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        border: Border.all(color: const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 32,
              color: enabled ? const Color(0xFF135BEC) : Colors.grey.shade700),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      enabled ? const Color(0xFFF1F5F9) : Colors.grey.shade600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(description,
              style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.grey : Colors.grey.shade700),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'mp3', 'wav', 'avi', 'mkv', 'm4a'],
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final file = result.files.single;
      final project = Project(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: file.name,
          status: ProjectStatus.inProgress,
          createdAt: DateTime.now(),
          videoPath: file.path);
      await _db.insertProject(project);
      setState(() => _projects.insert(0, project));
      if (mounted)
        _openSubtitleEditor(projectId: project.id, projectName: project.name);
    }
  }

  Future<void> _handleUrlExtraction() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Starting download...';
    });

    try {
      final ytdlpPath = await _binaryService.ytdlpPath;
      final appSupportDir = await _binaryService.appSupportDir;
      final outputPath = '$appSupportDir/%(title)s.%(ext)s';

      final process = await Process.start(ytdlpPath, [
        '-f',
        'best[ext=mp4]/best',
        '-o',
        outputPath,
        '--newline',
        '--no-playlist',
        url,
      ]);

      String? downloadedFilePath;
      String videoTitle = 'Downloaded Video';

      process.stdout.transform(utf8.decoder).listen((data) {
        print('yt-dlp stdout: $data');
        // Parse progress
        final progressMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(data);
        if (progressMatch != null) {
          setState(() =>
              _downloadProgress = 'Downloading ${progressMatch.group(1)}%');
        }
        // Parse destination
        final destMatch =
            RegExp(r'\[download\] Destination: (.+)').firstMatch(data);
        if (destMatch != null) {
          downloadedFilePath = destMatch.group(1);
        }
        // Parse merger output
        final mergeMatch =
            RegExp(r'\[Merger\] Merging formats into "(.+)"').firstMatch(data);
        if (mergeMatch != null) {
          downloadedFilePath = mergeMatch.group(1);
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('yt-dlp stderr: $data');
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0 && downloadedFilePath != null) {
        videoTitle = downloadedFilePath!.split('/').last;
        final project = Project(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: videoTitle,
          status: ProjectStatus.inProgress,
          createdAt: DateTime.now(),
          videoPath: downloadedFilePath,
        );
        await _db.insertProject(project);
        setState(() {
          _projects.insert(0, project);
          _urlController.clear();
        });
        if (mounted) {
          _openSubtitleEditor(projectId: project.id, projectName: project.name);
        }
      } else {
        throw Exception('Download failed (exit code: $exitCode)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMainContent()),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isRightPanelOpen ? 450 : 0,
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(color: Colors.grey.shade800))),
                      child: _isRightPanelOpen ? _buildNewProjectPanel() : null,
                    ),
                  ],
                ),
                Positioned(
                  right: _isRightPanelOpen ? 438 : -12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _isRightPanelOpen = !_isRightPanelOpen),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2430),
                            border: Border.all(color: Colors.grey.shade700),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              _isRightPanelOpen
                                  ? Icons.chevron_right
                                  : Icons.chevron_left,
                              size: 16,
                              color: Colors.grey),
                        ),
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

  Widget _buildSidebar() {
    return Container(
      width: 256,
      color: const Color(0xFF080A0F),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('MacWhisper',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem('All Projects', Icons.dashboard_outlined),
          _buildMenuItem('In Progress', Icons.access_time),
          _buildMenuItem('Completed', Icons.check_circle_outline),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_appVersion,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String name, IconData icon) {
    final isActive = _activeTab == name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _activeTab = name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2563EB) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: isActive ? Colors.white : Colors.grey),
              const SizedBox(width: 12),
              Text(name,
                  style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                  onPressed: _loadProjects),
              IconButton(
                  icon:
                      const Icon(Icons.settings, color: Colors.grey, size: 18),
                  onPressed: _showSettingsDialog),
            ],
          ),
          const SizedBox(height: 24),
          Text(_activeTab,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                      color: const Color(0xFF13161F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800)),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search projects by name...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _sortAsc = !_sortAsc);
                    _db.setConfig('sort_asc', _sortAsc.toString());
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                        color: const Color(0xFF13161F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade800)),
                    child: Icon(
                        _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                        color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () async {
                      final box = context.findRenderObject() as RenderBox;
                      final offset = box.localToGlobal(Offset.zero);
                      final result = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(
                            offset.dx,
                            offset.dy + box.size.height,
                            offset.dx + box.size.width,
                            0),
                        color: const Color(0xFF1F2430),
                        items: [
                          const PopupMenuItem(
                              value: 'modified',
                              child: Text('Last Modified',
                                  style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(
                              value: 'created',
                              child: Text('Creation Time',
                                  style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(
                              value: 'name',
                              child: Text('Name',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      );
                      if (result != null) {
                        setState(() => _sortBy = result);
                        await _db.setConfig('sort_by', result);
                      }
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF13161F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade800)),
                      child: Row(
                        children: [
                          Text(
                              'Sort by: ${_sortBy == 'modified' ? 'Last Modified' : _sortBy == 'created' ? 'Creation Time' : 'Name'}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProjects.length,
              itemBuilder: (_, i) => _buildProjectItem(_filteredProjects[i]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubtitleEditor(
      {String? projectId, String? projectName}) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SubtitleEditorPage(
                projectId: projectId, projectName: projectName)));
    if (mounted) {
      final projects = await _db.getProjects();
      print(
          'Reloaded ${projects.length} projects: ${projects.map((p) => p.name).toList()}');
      setState(() => _projects = projects);
    }
  }

  Widget _buildProjectItem(Project project) {
    return _ProjectItemWidget(
      key: ValueKey(project.id),
      project: project,
      isSelected: _selectedProjectId == project.id,
      onTap: () => setState(() => _selectedProjectId =
          _selectedProjectId == project.id ? null : project.id),
      onDoubleTap: () =>
          _openSubtitleEditor(projectId: project.id, projectName: project.name),
      onStatusToggle: () {
        project.status = project.status == ProjectStatus.completed
            ? ProjectStatus.inProgress
            : ProjectStatus.completed;
        _updateProject(project);
      },
      onNameChanged: (name) {
        project.name = name;
        _updateProject(project);
      },
      onDelete: () => _deleteProject(project),
    );
  }

  Widget _buildNewProjectPanel() {
    return Container(
      color: const Color(0xFF0F1219),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Start a New Project',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Get started by uploading a file or pasting a link below',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          DropTarget(
            onDragEntered: (_) => setState(() => _isDragging = true),
            onDragExited: (_) => setState(() => _isDragging = false),
            onDragDone: (details) {
              setState(() => _isDragging = false);
              _handleFileDrop(details);
            },
            child: CustomPaint(
              painter: _DashedBorderPainter(
                  color: _isDragging ? Colors.blue : Colors.grey.shade700,
                  radius: 20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 220),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                    color: _isDragging
                        ? const Color(0xFF1A2332)
                        : const Color(0xFF13161F),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: _isDragging
                              ? Colors.blue.shade800
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.cloud_upload_outlined,
                          size: 24,
                          color:
                              _isDragging ? Colors.blue.shade200 : Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        _isDragging
                            ? 'Drop file here'
                            : 'Drag & Drop Audio/Video File Here',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isDragging
                                ? Colors.blue.shade200
                                : Colors.grey.shade200)),
                    const SizedBox(height: 8),
                    Text('Supports MP3, WAV, MP4, MOV, etc.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 24),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _openFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade700)),
                          child: const Text('Choose File',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: Container(height: 1, color: Colors.grey.shade800)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: TextStyle(color: Colors.grey))),
              Expanded(
                  child: Container(height: 1, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 24),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Paste Audio/Video Link',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
          const SizedBox(height: 8),
          Container(
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFF13161F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700)),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(fontSize: 14),
              enabled: !_isDownloading,
              decoration: const InputDecoration(
                  hintText: 'https://',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _handleUrlExtraction,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: _isDownloading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_downloadProgress,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Text('Start Extraction',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectItemWidget extends StatefulWidget {
  final Project project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onStatusToggle;
  final Function(String) onNameChanged;
  final VoidCallback onDelete;
  const _ProjectItemWidget(
      {super.key,
      required this.project,
      required this.isSelected,
      required this.onTap,
      required this.onDoubleTap,
      required this.onStatusToggle,
      required this.onNameChanged,
      required this.onDelete});
  @override
  State<_ProjectItemWidget> createState() => _ProjectItemWidgetState();
}

class _ProjectItemWidgetState extends State<_ProjectItemWidget> {
  bool _isHovered = false;
  bool _isEditingName = false;
  late TextEditingController _nameController;
  String _fileInfo = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _loadFileInfo();
  }

  Future<void> _loadFileInfo() async {
    final path = widget.project.videoPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        final sizeStr = size > 1024 * 1024
            ? '${(size / (1024 * 1024)).toStringAsFixed(1)}MB'
            : '${(size / 1024).toStringAsFixed(1)}KB';

        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final duration = controller.value.duration;
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        final durationStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
        controller.dispose();

        setState(() => _fileInfo = 'Size: $sizeStr • Duration: $durationStr');
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _ProjectItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.name != widget.project.name) {
      _nameController.text = widget.project.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isVideo =
        project.name.endsWith('.mp4') || project.name.endsWith('.mov');
    final statusColor = project.status == ProjectStatus.completed
        ? Colors.green
        : Colors.orange;
    final statusText =
        project.status == ProjectStatus.completed ? 'Completed' : 'Editing';

    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF1A1E29)
                : const Color(0xFF13161F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.isSelected
                    ? Colors.blue
                    : (_isHovered ? Colors.grey.shade700 : Colors.transparent)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade800.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(isVideo ? Icons.movie : Icons.music_note,
                    color: isVideo ? Colors.blue : Colors.purple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isEditingName
                        ? SizedBox(
                            height: 24,
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder()),
                              onSubmitted: (_) {
                                widget.onNameChanged(_nameController.text);
                                setState(() => _isEditingName = false);
                              },
                              onTapOutside: (_) {
                                widget.onNameChanged(_nameController.text);
                                setState(() => _isEditingName = false);
                              },
                            ),
                          )
                        : GestureDetector(
                            onDoubleTap: () =>
                                setState(() => _isEditingName = true),
                            child: Text(_nameController.text,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                    const SizedBox(height: 4),
                    Text(_fileInfo,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onStatusToggle,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: statusColor.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusText,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${project.createdAt.month}/${project.createdAt.day}/${project.createdAt.year}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.delete_outline,
                        size: 20,
                        color: _isHovered
                            ? Colors.red.shade400
                            : Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
