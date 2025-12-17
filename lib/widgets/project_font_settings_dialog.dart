import 'package:flutter/material.dart';
import '../models/srt_font_config.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'font_settings_controls.dart';

/// Dialog for editing project-specific SRT font settings
class ProjectFontSettingsDialog extends StatefulWidget {
  final String projectId;
  final void Function(SrtFontConfig config)? onConfigChanged;

  const ProjectFontSettingsDialog({
    super.key,
    required this.projectId,
    this.onConfigChanged,
  });

  @override
  State<ProjectFontSettingsDialog> createState() =>
      _ProjectFontSettingsDialogState();
}

class _ProjectFontSettingsDialogState extends State<ProjectFontSettingsDialog> {
  SrtFontConfig _config = SrtFontConfig();
  bool _isLoading = true;
  bool _hasProjectConfig = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final hasCustom = await SrtFontConfig.hasProjectConfig(widget.projectId);
    final config = await SrtFontConfig.loadForProject(widget.projectId);
    setState(() {
      _config = config;
      _hasProjectConfig = hasCustom;
      _isLoading = false;
    });
  }

  /// Update config and save immediately
  void _updateConfig(SrtFontConfig newConfig) {
    setState(() {
      _config = newConfig;
      _hasProjectConfig = true;
    });
    // Save in background
    newConfig.saveForProject(widget.projectId);
    // Notify parent of change
    widget.onConfigChanged?.call(newConfig);
  }

  Future<void> _resetToGlobal() async {
    await SrtFontConfig.clearProjectConfig(widget.projectId);
    final globalConfig = await SrtFontConfig.load();
    setState(() {
      _config = globalConfig;
      _hasProjectConfig = false;
    });
    // Notify parent of change
    widget.onConfigChanged?.call(globalConfig);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacWhisperApp.of(context)?.theme ?? const AppTheme();

    if (_isLoading) {
      return Dialog(
        backgroundColor: theme.settingsDialog,
        child: const SizedBox(
          width: 500,
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Dialog(
      backgroundColor: theme.settingsDialog,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields, color: theme.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Font Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          _hasProjectConfig
                              ? 'Using custom settings'
                              : 'Using global settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hasProjectConfig
                                ? Colors.green.shade400
                                : theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content - Using shared controls
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ThemedFontSettingsControls(
                  config: _config,
                  onConfigChanged: _updateConfig,
                  theme: theme,
                  showPreview: true,
                  spacing: 20,
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.border)),
              ),
              child: Row(
                children: [
                  if (_hasProjectConfig)
                    TextButton.icon(
                      onPressed: _resetToGlobal,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset to Global'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
