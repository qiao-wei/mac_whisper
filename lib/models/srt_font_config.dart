import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Subtitle position options
enum SubtitlePosition { top, center, bottom }

class SrtFontConfig {
  String fontFamily;
  double fontSize;
  bool isBold;
  Color fontColor;
  SubtitlePosition position;
  double marginPercent; // Margin from edge as percentage of video height (0-50)

  SrtFontConfig({
    this.fontFamily = 'System Default',
    this.fontSize = 16.0,
    this.isBold = false,
    this.fontColor = Colors.white,
    this.position = SubtitlePosition.bottom,
    this.marginPercent = 5.0, // 5% from edge by default
  });

  static const List<String> availableFonts = [
    'System Default',
    'Arial',
    'Helvetica',
    'Times New Roman',
    'Courier New',
    'Georgia',
    'Verdana',
    'Trebuchet MS',
    'SF Pro',
    'Menlo',
  ];

  /// Preset colors for the font color picker
  static const List<Color> presetColors = [
    Colors.white,
    Color(0xFFFFFF00), // Yellow
    Color(0xFF00FFFF), // Cyan
    Color(0xFF00FF00), // Green
    Color(0xFFFF6B6B), // Light Red
    Color(0xFFFFB347), // Orange
    Color(0xFFDA70D6), // Orchid
    Color(0xFF87CEEB), // Sky Blue
  ];

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'isBold': isBold,
        'fontColor': fontColor.value,
        'position': position.index,
        'marginPercent': marginPercent,
      };

  factory SrtFontConfig.fromJson(Map<String, dynamic> json) {
    return SrtFontConfig(
      fontFamily: json['fontFamily'] ?? 'System Default',
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      isBold: json['isBold'] ?? false,
      fontColor: Color(json['fontColor'] ?? Colors.white.value),
      position: SubtitlePosition.values[json['position'] ?? 2],
      marginPercent:
          (json['marginPercent'] ?? json['marginPixels'] ?? 5.0).toDouble(),
    );
  }

  static Future<SrtFontConfig> load() async {
    final db = DatabaseService();
    final configStr = await db.getConfig('srt_font_config');
    if (configStr != null) {
      try {
        return SrtFontConfig.fromJson(jsonDecode(configStr));
      } catch (_) {}
    }
    return SrtFontConfig();
  }

  /// Load project-specific config, falls back to global if not set
  static Future<SrtFontConfig> loadForProject(String? projectId) async {
    if (projectId == null) return load();

    final db = DatabaseService();
    final configStr = await db.getConfig('srt_font_config_$projectId');
    if (configStr != null) {
      try {
        return SrtFontConfig.fromJson(jsonDecode(configStr));
      } catch (_) {}
    }
    // Fall back to global config
    return load();
  }

  /// Check if project has custom config
  static Future<bool> hasProjectConfig(String projectId) async {
    final db = DatabaseService();
    final configStr = await db.getConfig('srt_font_config_$projectId');
    return configStr != null;
  }

  Future<void> save() async {
    final db = DatabaseService();
    await db.setConfig('srt_font_config', jsonEncode(toJson()));
  }

  /// Save config for specific project
  Future<void> saveForProject(String projectId) async {
    final db = DatabaseService();
    await db.setConfig('srt_font_config_$projectId', jsonEncode(toJson()));
  }

  /// Clear project-specific config (revert to global)
  static Future<void> clearProjectConfig(String projectId) async {
    final db = DatabaseService();
    // Delete by setting empty - or we could add a delete method to DatabaseService
    await db.setConfig('srt_font_config_$projectId', '');
  }

  SrtFontConfig copyWith({
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    Color? fontColor,
    SubtitlePosition? position,
    double? marginPercent,
  }) {
    return SrtFontConfig(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      fontColor: fontColor ?? this.fontColor,
      position: position ?? this.position,
      marginPercent: marginPercent ?? this.marginPercent,
    );
  }
}
