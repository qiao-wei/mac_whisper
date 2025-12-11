import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Theme provider to manage app theme state
class ThemeProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  bool _isDark = false;

  bool get isDark => _isDark;
  AppTheme get theme => AppTheme(isDark: _isDark);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeMode = await _db.getConfig('theme_mode');
    _isDark = themeMode == 'dark';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    await _db.setConfig('theme_mode', _isDark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _isDark = isDark;
    await _db.setConfig('theme_mode', isDark ? 'dark' : 'light');
    notifyListeners();
  }
}
