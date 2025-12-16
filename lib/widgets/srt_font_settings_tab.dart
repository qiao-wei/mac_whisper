import 'package:flutter/material.dart';
import '../models/srt_font_config.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class SrtFontSettingsTab extends StatefulWidget {
  const SrtFontSettingsTab({super.key});

  @override
  State<SrtFontSettingsTab> createState() => _SrtFontSettingsTabState();
}

class _SrtFontSettingsTabState extends State<SrtFontSettingsTab> {
  SrtFontConfig _config = SrtFontConfig();
  bool _isLoading = true;
  final FocusNode _sliderFocusNode = FocusNode();

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

    return SingleChildScrollView(
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

            // Font Family
            _buildSectionTitle('Font Family', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  items: SrtFontConfig.availableFonts.map((font) {
                    return DropdownMenuItem(
                      value: font,
                      child: Text(
                        font,
                        style: TextStyle(
                          fontFamily: font == 'System Default' ? null : font,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateConfig(_config.copyWith(fontFamily: value));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Font Size
            _buildSectionTitle(
                'Font Size: ${_config.fontSize.toInt()}px', theme),
            const SizedBox(height: 12),
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
                focusNode: _sliderFocusNode,
                onChangeStart: (_) {
                  _sliderFocusNode.requestFocus();
                },
                onChanged: (value) {
                  _updateConfig(_config.copyWith(fontSize: value));
                },
              ),
            ),
            const SizedBox(height: 24),

            // Font Weight
            _buildSectionTitle('Font Weight', theme),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildWeightOption('Normal', false, theme),
                const SizedBox(width: 12),
                _buildWeightOption('Bold', true, theme),
              ],
            ),
            const SizedBox(height: 32),

            // Preview
            _buildSectionTitle('Preview', theme),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: Center(
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppTheme theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
