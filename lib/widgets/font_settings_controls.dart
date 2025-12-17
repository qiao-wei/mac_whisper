import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/srt_font_config.dart';
import '../theme/app_theme.dart';

/// Themed font settings controls - shared by project and global font settings
class ThemedFontSettingsControls extends StatefulWidget {
  final SrtFontConfig config;
  final ValueChanged<SrtFontConfig> onConfigChanged;
  final AppTheme theme;
  final bool showPreview;
  final double spacing;

  const ThemedFontSettingsControls({
    super.key,
    required this.config,
    required this.onConfigChanged,
    required this.theme,
    this.showPreview = true,
    this.spacing = 20,
  });

  @override
  State<ThemedFontSettingsControls> createState() =>
      _ThemedFontSettingsControlsState();
}

class _ThemedFontSettingsControlsState
    extends State<ThemedFontSettingsControls> {
  final FocusNode _sliderFocusNode = FocusNode();

  @override
  void dispose() {
    _sliderFocusNode.dispose();
    super.dispose();
  }

  void _showColorPicker() {
    Color pickerColor = widget.config.fontColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.theme.settingsDialog,
        title: Text(
          'Pick a Color',
          style: TextStyle(color: widget.theme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: TextStyle(color: widget.theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onConfigChanged(
                  widget.config.copyWith(fontColor: pickerColor));
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: widget.theme.textPrimary,
      ),
    );
  }

  Widget _buildWeightOption(String label, bool isBold) {
    final isSelected = widget.config.isBold == isBold;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            widget.onConfigChanged(widget.config.copyWith(isBold: isBold)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : widget.theme.surface,
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : widget.theme.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : widget.theme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final spacing = widget.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font Family
        _buildLabel('Font Family'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.config.fontFamily,
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
                  widget.onConfigChanged(
                      widget.config.copyWith(fontFamily: value));
                }
              },
            ),
          ),
        ),
        SizedBox(height: spacing),

        // Font Size
        _buildLabel('Font Size: ${widget.config.fontSize.toInt()}px'),
        const SizedBox(height: 8),
        FocusScope(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: theme.border,
              thumbColor: const Color(0xFF2563EB),
              overlayColor: const Color(0xFF2563EB).withAlpha(51),
            ),
            child: Slider(
              value: widget.config.fontSize,
              min: 14,
              max: 48,
              divisions: 34,
              focusNode: _sliderFocusNode,
              onChangeStart: (_) {
                _sliderFocusNode.requestFocus();
              },
              onChanged: (value) {
                widget.onConfigChanged(widget.config.copyWith(fontSize: value));
              },
            ),
          ),
        ),
        SizedBox(height: spacing),

        // Font Weight
        _buildLabel('Font Weight'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildWeightOption('Normal', false),
            const SizedBox(width: 12),
            _buildWeightOption('Bold', true),
          ],
        ),
        SizedBox(height: spacing),

        // Font Color
        _buildLabel('Font Color'),
        const SizedBox(height: 8),
        Row(
          children: [
            // Current color display
            GestureDetector(
              onTap: _showColorPicker,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.config.fontColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border, width: 2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Pick color button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showColorPicker,
                icon: const Icon(Icons.palette, size: 18),
                label: const Text('Choose Color'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary,
                  side: BorderSide(color: theme.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),

        // Preview (optional)
        if (widget.showPreview) ...[
          SizedBox(height: spacing + 4),
          _buildLabel('Preview'),
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
                'Sample Subtitle Text\n示例字幕文本',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: widget.config.fontFamily == 'System Default'
                      ? null
                      : widget.config.fontFamily,
                  fontSize: widget.config.fontSize,
                  fontWeight: widget.config.isBold
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: widget.config.fontColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
