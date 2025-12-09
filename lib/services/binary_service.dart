import 'dart:io';
import 'package:path/path.dart' as path;

/// Service for managing bundled binary executables (whisper-cli)
class BinaryService {
  static final BinaryService _instance = BinaryService._internal();
  factory BinaryService() => _instance;
  BinaryService._internal();

  String? _whisperCliPath;
  String? _appSupportDir;

  /// Get the Application Support directory for storing binaries and models
  Future<String> get appSupportDir async {
    if (_appSupportDir != null) return _appSupportDir!;

    final home = Platform.environment['HOME'];
    _appSupportDir = '$home/Library/Application Support/MacWhisper';

    final dir = Directory(_appSupportDir!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    return _appSupportDir!;
  }

  /// Get the path to whisper-cli executable
  Future<String> get whisperCliPath async {
    if (_whisperCliPath != null) return _whisperCliPath!;
    _whisperCliPath = await _getBinaryPath('whisper-cli');
    return _whisperCliPath!;
  }

  /// Get binary path - checks bundled location first, then project root, then system PATH
  Future<String> _getBinaryPath(String binaryName) async {
    // Try bundled location in app bundle (production)
    final bundledPath = await _getBundledBinaryPath(binaryName);
    if (bundledPath != null && File(bundledPath).existsSync()) {
      return bundledPath;
    }

    // Fall back to project root (development)
    final devPath = _getDevBinaryPath(binaryName);
    if (devPath != null && File(devPath).existsSync()) {
      return devPath;
    }

    // Fall back to system PATH
    final systemPath = await _getSystemBinaryPath(binaryName);
    if (systemPath != null) {
      return systemPath;
    }

    throw Exception(
        'Binary not found: $binaryName. Please install $binaryName or place it in the project root.');
  }

  /// Try to find binary in system PATH using 'which'
  Future<String?> _getSystemBinaryPath(String binaryName) async {
    try {
      final result = await Process.run('which', [binaryName]);
      if (result.exitCode == 0) {
        final binaryPath = (result.stdout as String).trim();
        if (binaryPath.isNotEmpty && File(binaryPath).existsSync()) {
          return binaryPath;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get path to binary in app bundle Resources
  Future<String?> _getBundledBinaryPath(String binaryName) async {
    // Get the executable path and derive the Resources path
    final executable = Platform.resolvedExecutable;
    final appBundle = path.dirname(path.dirname(executable));
    final resourcesPath = path.join(appBundle, 'Resources', binaryName);
    return resourcesPath;
  }

  /// Get path to binary in project root (for development)
  String? _getDevBinaryPath(String binaryName) {
    // In development, binaries are in project root
    // Get the directory containing the running script
    final scriptDir = Platform.script.toFilePath();
    var current = Directory(path.dirname(scriptDir));

    // Walk up to find project root (where pubspec.yaml is)
    for (var i = 0; i < 10; i++) {
      final pubspec = File(path.join(current.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        return path.join(current.path, binaryName);
      }
      current = current.parent;
    }

    // Fallback: try current working directory
    final cwdPath = path.join(Directory.current.path, binaryName);
    if (File(cwdPath).existsSync()) {
      return cwdPath;
    }

    return null;
  }

  /// Get the models directory path
  Future<String> get modelsDir async {
    final home = Platform.environment['HOME'];
    final dir = Directory('$home/.cache/whisper');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }
}
