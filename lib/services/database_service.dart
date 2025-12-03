import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'uf_app.db');
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration handled - columns already exist in schema
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        video_path TEXT,
        thumbnail_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE subtitles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        text TEXT NOT NULL,
        translated_text TEXT,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE config(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Projects
  Future<List<Project>> getProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'created_at DESC');
    return maps.map((m) => Project(
      id: m['id'] as String,
      name: m['name'] as String,
      status: ProjectStatus.values[m['status'] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      videoPath: m['video_path'] as String?,
      thumbnailPath: m['thumbnail_path'] as String?,
    )).toList();
  }

  Future<void> insertProject(Project p) async {
    final db = await database;
    await db.insert('projects', {
      'id': p.id,
      'name': p.name,
      'status': p.status.index,
      'created_at': p.createdAt.millisecondsSinceEpoch,
      'video_path': p.videoPath,
      'thumbnail_path': p.thumbnailPath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProject(Project p) async {
    final db = await database;
    await db.update('projects', {
      'name': p.name,
      'status': p.status.index,
      'video_path': p.videoPath,
      'thumbnail_path': p.thumbnailPath,
    }, where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProjectName(String id, String name) async {
    final db = await database;
    final count = await db.update('projects', {'name': name}, where: 'id = ?', whereArgs: [id]);
    print('updateProjectName: id=$id, name=$name, updated=$count rows');
  }

  // Subtitles
  Future<List<Map<String, dynamic>>> getSubtitles(String projectId) async {
    final db = await database;
    return db.query('subtitles', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'sort_order');
  }

  Future<void> insertSubtitle(String projectId, int startTime, int endTime, String text, String? translatedText, int sortOrder) async {
    final db = await database;
    await db.insert('subtitles', {
      'project_id': projectId,
      'start_time': startTime,
      'end_time': endTime,
      'text': text,
      'translated_text': translatedText,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateSubtitle(int id, int startTime, int endTime, String text, String? translatedText) async {
    final db = await database;
    await db.update('subtitles', {
      'start_time': startTime,
      'end_time': endTime,
      'text': text,
      'translated_text': translatedText,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtitle(int id) async {
    final db = await database;
    await db.delete('subtitles', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtitlesByProject(String projectId) async {
    final db = await database;
    await db.delete('subtitles', where: 'project_id = ?', whereArgs: [projectId]);
  }

  Future<void> saveSubtitles(String projectId, List<Map<String, dynamic>> subtitles) async {
    final db = await database;
    await db.delete('subtitles', where: 'project_id = ?', whereArgs: [projectId]);
    for (var i = 0; i < subtitles.length; i++) {
      final s = subtitles[i];
      await db.insert('subtitles', {
        'project_id': projectId,
        'start_time': s['start_time'],
        'end_time': s['end_time'],
        'text': s['text'],
        'translated_text': s['translated_text'],
        'sort_order': i,
      });
    }
  }

  // Config
  Future<String?> getConfig(String key) async {
    final db = await database;
    final result = await db.query('config', where: 'key = ?', whereArgs: [key]);
    return result.isEmpty ? null : result.first['value'] as String;
  }

  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert('config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
