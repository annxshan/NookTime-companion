import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_controller.dart';

class ColorPreset {
  final String name;
  final Color primary;
  final Color complementary;

  const ColorPreset({
    required this.name,
    required this.primary,
    required this.complementary,
  });
}

class AppearanceThemeBottomSheet extends StatelessWidget {
  const AppearanceThemeBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const AppearanceThemeBottomSheet(),
    );
  }

  static const List<ColorPreset> presets = [
    ColorPreset(
      name: 'Violet Purple',
      primary: Color(0xFF6C5CE7),
      complementary: Color(0xFF4834D4),
    ),
    ColorPreset(
      name: 'Electric Cyan',
      primary: Color(0xFF00D2D3),
      complementary: Color(0xFF00838F),
    ),
    ColorPreset(
      name: 'Neon Red/Coral',
      primary: Color(0xFFFF6B6B),
      complementary: Color(0xFFC0392B),
    ),
    ColorPreset(
      name: 'Slate Blue',
      primary: Color(0xFF3B82F6),
      complementary: Color(0xFF1D4ED8),
    ),
    ColorPreset(
      name: 'Blush Pink',
      primary: Color(0xFFFD79A8),
      complementary: Color(0xFFE84393),
    ),
    ColorPreset(
      name: 'Amber Gold',
      primary: Color(0xFFFFAA00),
      complementary: Color(0xFFD35400),
    ),
    ColorPreset(
      name: 'Deep Navy',
      primary: Color(0xFF3A86FF),
      complementary: Color(0xFF1E3A8A),
    ),
    ColorPreset(
      name: 'Forest Green',
      primary: Color(0xFF10B981),
      complementary: Color(0xFF047857),
    ),
    ColorPreset(
      name: 'Charcoal',
      primary: Color(0xFF64748B),
      complementary: Color(0xFF334155),
    ),
    ColorPreset(
      name: 'Silver Gray',
      primary: Color(0xFF94A3B8),
      complementary: Color(0xFF475569),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        final currentMode = controller.themeMode;
        final activeColor = controller.seedColor;
        final isCustom = controller.isCustomColor;

        final isDark = currentMode == ThemeMode.dark
            ? true
            : currentMode == ThemeMode.light
                ? false
                : (MediaQuery.of(context).platformBrightness == Brightness.dark);

        final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;

        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Appearance & Theme',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                            ),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSegmentedModeSwitcher(context, currentMode, isDark),
                      const SizedBox(height: 24),
                      Text(
                        'Accent Color Palette',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an accent tone or choose a custom color.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildColorGrid(context, activeColor, isCustom, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentedModeSwitcher(
    BuildContext context,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final modes = [
      (ThemeMode.system, '🖥️ System'),
      (ThemeMode.light, '☀️ Light'),
      (ThemeMode.dark, '🌙 Dark'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: modes.map((item) {
          final mode = item.$1;
          final label = item.$2;
          final isSelected = currentMode == mode;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ThemeController.instance.setThemeMode(mode);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeController.instance.seedColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ThemeController.instance.seedColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColorGrid(
    BuildContext context,
    Color activeColor,
    bool isCustomActive,
    bool isDark,
  ) {
    final itemsCount = presets.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.0,
      ),
      itemCount: itemsCount,
      itemBuilder: (context, index) {
        if (index < presets.length) {
          final preset = presets[index];
          final isSelected = !isCustomActive &&
              activeColor.toARGB32() == preset.primary.toARGB32();

          return _buildSplitSwatchItem(context, preset, isSelected, isDark);
        } else {
          return _buildCustomColorButton(
            context,
            activeColor,
            isCustomActive,
            isDark,
          );
        }
      },
    );
  }

  Widget _buildSplitSwatchItem(
    BuildContext context,
    ColorPreset preset,
    bool isSelected,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ThemeController.instance.setSeedColor(preset.primary, isCustom: false);
      },
      child: Tooltip(
        message: preset.name,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: preset.primary, width: 2.5)
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: preset.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSelected ? 3.0 : 0.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [preset.primary, preset.complementary],
                  stops: const [0.5, 0.5],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomColorButton(
    BuildContext context,
    Color activeColor,
    bool isCustomActive,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showCustomColorPickerDialog(context, activeColor);
      },
      child: Tooltip(
        message: 'Custom Hex Color',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isCustomActive
                ? Border.all(color: activeColor, width: 2.5)
                : Border.all(color: Colors.transparent, width: 0),
            boxShadow: isCustomActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.all(isCustomActive ? 3.0 : 0.0),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFF7F00),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF0000FF),
                    Color(0xFF8B00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.colorize_rounded,
                      color: isCustomActive
                          ? activeColor
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomColorPickerDialog(BuildContext context, Color currentColor) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomColorPickerDialog(initialColor: currentColor),
    );
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _CustomColorPickerDialog({required this.initialColor});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late double _r;
  late double _g;
  late double _b;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _r = widget.initialColor.r * 255;
    _g = widget.initialColor.g * 255;
    _b = widget.initialColor.b * 255;
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => Color.fromRGBO(_r.round(), _g.round(), _b.round(), 1.0);

  String _colorToHex(Color color) {
    final rStr = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final gStr = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final bStr = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$rStr$gStr$bStr'.toUpperCase();
  }

  void _updateFromSliders() {
    setState(() {
      _hexController.text = _colorToHex(_currentColor);
    });
  }

  void _updateFromHex(String input) {
    final clean = input.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) {
        final col = Color(val);
        setState(() {
          _r = col.r * 255;
          _g = col.g * 255;
          _b = col.b * 255;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_rounded, color: Color(0xFF00D2D3)),
                const SizedBox(width: 8),
                Text(
                  'Custom Color Picker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentColor,
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    onChanged: _updateFromHex,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Hex Color',
                      isDense: true,
                      prefixText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildChannelSlider('Red', _r, Colors.red, (v) {
              setState(() {
                _r = v;
                _updateFromSliders();
              });
            }),
            _buildChannelSlider('Green', _g, Colors.green, (v) {
              setState(() {
                _g = v;
                _updateFromSliders();
              });
            }),
            _buildChannelSlider('Blue', _b, Colors.blue, (v) {
              setState(() {
                _b = v;
                _updateFromSliders();
              });
            }),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ThemeController.instance.setSeedColor(
                      _currentColor,
                      isCustom: true,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply Color',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSlider(
    String label,
    double value,
    Color activeColor,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 45,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
