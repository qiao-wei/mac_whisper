import 'package:flutter/material.dart';
import '../models/srt_font_config.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'font_settings_controls.dart';

class SrtFontSettingsTab extends StatefulWidget {
  const SrtFontSettingsTab({super.key});

  @override
  State<SrtFontSettingsTab> createState() => _SrtFontSettingsTabState();
}

class _SrtFontSettingsTabState extends State<SrtFontSettingsTab> {
  SrtFontConfig _config = SrtFontConfig();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await SrtFontConfig.load();
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  /// Update config and save immediately
  void _updateConfig(SrtFontConfig newConfig) {
    setState(() => _config = newConfig);
    // Save in background
    newConfig.save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacWhisperApp.of(context)?.theme ?? const AppTheme();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Scrollable controls
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Global SRT Font Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default font settings for all projects. Changes are saved automatically.',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  // Shared font settings controls without preview
                  ThemedFontSettingsControls(
                    config: _config,
                    onConfigChanged: _updateConfig,
                    theme: theme,
                    showPreview: false,
                    spacing: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Fixed preview at bottom
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: _config.bgPadding,
                    ),
                    decoration: BoxDecoration(
                      color: _config.bgColor.withOpacity(_config.bgOpacity),
                      borderRadius:
                          BorderRadius.circular(_config.bgCornerRadius),
                    ),
                    child: Text(
                      'Sample Subtitle Text\n示例字幕文本',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _config.fontFamily == 'System Default'
                            ? null
                            : _config.fontFamily,
                        fontSize: _config.fontSize,
                        fontWeight:
                            _config.isBold ? FontWeight.bold : FontWeight.normal,
                        color: _config.fontColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
