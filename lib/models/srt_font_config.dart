import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SrtFontConfig {
  String fontFamily;
  double fontSize;
  bool isBold;
  Color fontColor;

  SrtFontConfig({
    this.fontFamily = 'System Default',
    this.fontSize = 16.0,
    this.isBold = false,
    this.fontColor = Colors.white,
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

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'isBold': isBold,
        'fontColor': fontColor.value,
      };

  factory SrtFontConfig.fromJson(Map<String, dynamic> json) {
    return SrtFontConfig(
      fontFamily: json['fontFamily'] ?? 'System Default',
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      isBold: json['isBold'] ?? false,
      fontColor: Color(json['fontColor'] ?? Colors.white.value),
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

  Future<void> save() async {
    final db = DatabaseService();
    await db.setConfig('srt_font_config', jsonEncode(toJson()));
  }

  SrtFontConfig copyWith({
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    Color? fontColor,
  }) {
    return SrtFontConfig(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      fontColor: fontColor ?? this.fontColor,
    );
  }
}
