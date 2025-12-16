import 'package:flutter/material.dart';
import '../models/srt_font_config.dart';
import '../main.dart';
import '../theme/app_theme.dart';

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
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Font Family
                    _buildLabel('Font Family', theme),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        border: Border.all(color: theme.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _config.fontFamily,
                          isExpanded: true,
                          dropdownColor: theme.surface,
                          style:
                              TextStyle(color: theme.textPrimary, fontSize: 14),
                          items: SrtFontConfig.availableFonts.map((font) {
                            return DropdownMenuItem(
                              value: font,
                              child: Text(
                                font,
                                style: TextStyle(
                                  fontFamily:
                                      font == 'System Default' ? null : font,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _updateConfig(
                                  _config.copyWith(fontFamily: value));
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Font Size
                    _buildLabel(
                        'Font Size: ${_config.fontSize.toInt()}px', theme),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF2563EB),
                        inactiveTrackColor: theme.border,
                        thumbColor: const Color(0xFF2563EB),
                        overlayColor: const Color(0xFF2563EB).withAlpha(51),
                      ),
                      child: Slider(
                        value: _config.fontSize,
                        min: 14,
                        max: 48,
                        divisions: 34,
                        onChanged: (value) {
                          _updateConfig(_config.copyWith(fontSize: value));
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Font Weight
                    _buildLabel('Font Weight', theme),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildWeightOption('Normal', false, theme),
                        const SizedBox(width: 12),
                        _buildWeightOption('Bold', true, theme),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Preview
                    _buildLabel('Preview', theme),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.border),
                      ),
                      child: Center(
                        child: Text(
                          'Sample Subtitle\n示例字幕',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _config.fontFamily == 'System Default'
                                ? null
                                : _config.fontFamily,
                            fontSize: _config.fontSize,
                            fontWeight: _config.isBold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _config.fontColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    TextButton(
                      onPressed: _resetToGlobal,
                      child: Text(
                        'Reset to Global',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: theme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, AppTheme theme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.textPrimary,
      ),
    );
  }

  Widget _buildWeightOption(String label, bool isBold, AppTheme theme) {
    final isSelected = _config.isBold == isBold;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _updateConfig(_config.copyWith(isBold: isBold));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : theme.surface,
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : theme.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.textPrimary,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
