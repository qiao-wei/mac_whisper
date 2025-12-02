import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui' as ui;
import '../models/project.dart';
import '../services/database_service.dart';
import 'editor_page.dart';
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
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    final dashPath = Path();
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(metric.extractPath(distance, distance + dashWidth), Offset.zero);
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
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getProjects();
    if (projects.isEmpty) {
      // Insert sample data on first run
      final samples = [
        Project(id: '1', name: 'My Vacation Video.mp4', status: ProjectStatus.completed, createdAt: DateTime.now()),
        Project(id: '2', name: 'Podcast Interview Ep5.mp3', status: ProjectStatus.inProgress, createdAt: DateTime.now().subtract(const Duration(days: 1))),
        Project(id: '3', name: 'Product Demo.mov', status: ProjectStatus.inProgress, createdAt: DateTime.now().subtract(const Duration(days: 5))),
      ];
      for (final p in samples) {
        await _db.insertProject(p);
      }
      setState(() { _projects = samples; _isLoading = false; });
    } else {
      setState(() { _projects = projects; _isLoading = false; });
    }
  }

  Future<void> _updateProject(Project p) async {
    await _db.updateProject(p);
    setState(() {});
  }

  List<Project> get _filteredProjects {
    return _projects.where((p) {
      if (_activeTab == 'In Progress') return p.status == ProjectStatus.inProgress;
      if (_activeTab == 'Completed') return p.status == ProjectStatus.completed;
      return true;
    }).where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(videoPath: result.files.single.path!)));
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
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade800))),
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
                        onTap: () => setState(() => _isRightPanelOpen = !_isRightPanelOpen),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2430),
                            border: Border.all(color: Colors.grey.shade700),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_isRightPanelOpen ? Icons.chevron_right : Icons.chevron_left, size: 16, color: Colors.grey),
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
                    gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFEC4899)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CaptionPro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Welcome Back', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem('All Projects', Icons.dashboard_outlined),
          _buildMenuItem('In Progress', Icons.access_time),
          _buildMenuItem('Completed', Icons.check_circle_outline),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('v2.4.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
              Icon(icon, size: 20, color: isActive ? Colors.white : Colors.grey),
              const SizedBox(width: 12),
              Text(name, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.w500)),
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
              IconButton(icon: const Icon(Icons.refresh, color: Colors.grey, size: 18), onPressed: () {}),
              IconButton(icon: const Icon(Icons.settings, color: Colors.grey, size: 18), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 24),
          Text(_activeTab, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF13161F), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade800)),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search projects by name...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFF13161F), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade800)),
                child: const Row(
                  children: [
                    Text('Sort by: Last Modified', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                  ],
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

  void _openSubtitleEditor({String? projectId, String? projectName}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubtitleEditorPage(projectId: projectId, projectName: projectName)));
  }

  Widget _buildProjectItem(Project project) {
    return _ProjectItemWidget(
      project: project,
      isSelected: _selectedProjectId == project.id,
      onTap: () => setState(() => _selectedProjectId = _selectedProjectId == project.id ? null : project.id),
      onDoubleTap: () => _openSubtitleEditor(projectId: project.id, projectName: project.name),
      onStatusToggle: () {
        project.status = project.status == ProjectStatus.completed ? ProjectStatus.inProgress : ProjectStatus.completed;
        _updateProject(project);
      },
      onNameChanged: (name) {
        project.name = name;
        _updateProject(project);
      },
    );
  }

  Widget _buildNewProjectPanel() {
    return Container(
      color: const Color(0xFF0F1219),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Start a New Project', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Get started by uploading a file or pasting a link below', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          InkWell(
            onTap: _openFile,
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _DashedBorderPainter(color: Colors.grey.shade700, radius: 20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 220),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: const Color(0xFF13161F), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.cloud_upload_outlined, size: 24, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text('Drag & Drop Audio/Video File Here', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade200)),
                    const SizedBox(height: 8),
                    Text('Supports MP3, WAV, MP4, MOV, etc.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade700)),
                      child: const Text('Choose File', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Colors.grey.shade800)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: Colors.grey))),
              Expanded(child: Container(height: 1, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text('Paste Audio/Video Link', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500))),
          const SizedBox(height: 8),
          Container(
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFF13161F), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade700)),
            child: const TextField(
              style: TextStyle(fontSize: 14),
              decoration: InputDecoration(hintText: 'https://', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _openSubtitleEditor(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Start Extraction', style: TextStyle(fontWeight: FontWeight.w600)),
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
  const _ProjectItemWidget({required this.project, required this.isSelected, required this.onTap, required this.onDoubleTap, required this.onStatusToggle, required this.onNameChanged});
  @override
  State<_ProjectItemWidget> createState() => _ProjectItemWidgetState();
}

class _ProjectItemWidgetState extends State<_ProjectItemWidget> {
  bool _isHovered = false;
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isVideo = project.name.endsWith('.mp4') || project.name.endsWith('.mov');
    final statusColor = project.status == ProjectStatus.completed ? Colors.green : Colors.orange;
    final statusText = project.status == ProjectStatus.completed ? 'Completed' : 'Editing';

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
            color: widget.isSelected ? const Color(0xFF1A1E29) : const Color(0xFF13161F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.isSelected ? Colors.blue : (_isHovered ? Colors.grey.shade700 : Colors.transparent)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                child: Icon(isVideo ? Icons.movie : Icons.music_note, color: isVideo ? Colors.blue : Colors.purple, size: 24),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
                              onSubmitted: (_) { widget.onNameChanged(_nameController.text); setState(() => _isEditingName = false); },
                              onTapOutside: (_) { widget.onNameChanged(_nameController.text); setState(() => _isEditingName = false); },
                            ),
                          )
                        : GestureDetector(
                            onDoubleTap: () => setState(() => _isEditingName = true),
                            child: Text(_nameController.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                    const SizedBox(height: 4),
                    const Text('Size: 45MB • Duration: 12:30', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${project.createdAt.month}/${project.createdAt.day}/${project.createdAt.year}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
