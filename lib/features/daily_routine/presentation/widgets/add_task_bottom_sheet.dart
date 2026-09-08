import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../ai_assistant/presentation/ai_planner_bottom_sheet.dart';
import '../../data/routine_repository.dart';

/// Modal bottom sheet for creating a daily recurring Routine Task or launching AI Planner.
class AddTaskBottomSheet extends StatefulWidget {
  final RoutineRepository routineRepository;
  final VoidCallback onTaskAdded;
  final int? initialWeekday;
  final VoidCallback? onOpenAiStudio;
  final VoidCallback? onNavigateToReminders;

  const AddTaskBottomSheet({
    super.key,
    required this.routineRepository,
    required this.onTaskAdded,
    this.initialWeekday,
    this.onOpenAiStudio,
    this.onNavigateToReminders,
  });

  static void show(
    BuildContext context, {
    required RoutineRepository routineRepository,
    required VoidCallback onTaskAdded,
    int? initialWeekday,
    VoidCallback? onOpenAiStudio,
    VoidCallback? onNavigateToReminders,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskBottomSheet(
        routineRepository: routineRepository,
        onTaskAdded: onTaskAdded,
        initialWeekday: initialWeekday,
        onOpenAiStudio: onOpenAiStudio,
        onNavigateToReminders: onNavigateToReminders,
      ),
    );
  }

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'Work';
  int _durationMinutes = 30;
  TimeOfDay _selectedTime = TimeOfDay.now();
  late List<int> _selectedDaysOfWeek;
  bool _isSubmitting = false;

  static const List<String> _categories = ['Work', 'Health', 'Personal', 'Study', 'Other'];
  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDaysOfWeek = widget.initialWeekday != null
        ? [widget.initialWeekday!]
        : [DateTime.now().weekday];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final now = DateTime.now();
      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await widget.routineRepository.createRoutine(
        title: title,
        category: _selectedCategory,
        startTime: scheduledDateTime,
        durationMinutes: _durationMinutes,
        daysOfWeek: _selectedDaysOfWeek.isEmpty
            ? [1, 2, 3, 4, 5, 6, 7]
            : _selectedDaysOfWeek,
      );

      widget.onTaskAdded();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openAiPlanner() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    if (widget.onOpenAiStudio != null) {
      widget.onOpenAiStudio!();
    } else {
      AiPlannerBottomSheet.show(
        context,
        routineRepository: widget.routineRepository,
        onScheduleApplied: widget.onTaskAdded,
      );
    }
  }

  Widget _buildPresetChip(String label, List<int> days) {
    final isSelected = _selectedDaysOfWeek.length == days.length &&
        _selectedDaysOfWeek.every((d) => days.contains(d));
    final controller = ThemeController.instance;
    final primaryColor = controller.seedColor;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : null,
        ),
      ),
      backgroundColor: isSelected ? primaryColor.withValues(alpha: 0.15) : null,
      side: isSelected ? BorderSide(color: primaryColor, width: 1.5) : null,
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedDaysOfWeek = List.from(days);
        });
      },
    );
  }

  Future<void> _showCustomDurationDialog() async {
    HapticFeedback.lightImpact();
    final customController = TextEditingController(text: '$_durationMinutes');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.timer_outlined, size: 22),
              SizedBox(width: 8),
              Text('Custom Duration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: customController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Duration in minutes',
              hintText: 'e.g. 20, 120, 180',
              suffixText: 'mins',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ThemeController.instance.seedColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final mins = int.tryParse(customController.text.trim());
                if (mins != null && mins > 0) {
                  Navigator.pop(dialogContext, mins);
                }
              },
              child: const Text('Set Duration'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _durationMinutes = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeController.instance;
    final currentMode = controller.themeMode;
    final isDark = currentMode == ThemeMode.dark
        ? true
        : currentMode == ThemeMode.light
            ? false
            : (MediaQuery.of(context).platformBrightness == Brightness.dark);
    final primaryColor = controller.seedColor;

    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.repeat_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'New Routine Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    // Plan with AI Action Button
                    InkWell(
                      onTap: _openAiPlanner,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Plan with AI',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title Input Field
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Routine Task Title',
                    hintText: 'e.g. Morning Workout, Deep Work, Reading',
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Selection
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? primaryColor : borderColor,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Repeats On Weekdays Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REPEATS ON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: [
                        _buildPresetChip('Weekdays', [1, 2, 3, 4, 5]),
                        const SizedBox(width: 6),
                        _buildPresetChip('Everyday', [1, 2, 3, 4, 5, 6, 7]),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (index) {
                    final dayNum = index + 1;
                    final isSelected = _selectedDaysOfWeek.contains(dayNum);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (isSelected) {
                                if (_selectedDaysOfWeek.length > 1) {
                                  _selectedDaysOfWeek.remove(dayNum);
                                }
                              } else {
                                _selectedDaysOfWeek.add(dayNum);
                                _selectedDaysOfWeek.sort();
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : cardBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? primaryColor : borderColor),
                            ),
                            child: Center(
                              child: Text(
                                _dayLabels[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Time & Duration Row
                Row(
                  children: [
                    // Start Time Picker Card
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'START TIME',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Duration Selector Chips
                Text(
                  'DURATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[15, 30, 45, 60, 90].map((mins) {
                        final isSelected = _durationMinutes == mins;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${mins}m'),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor: cardBg,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected ? primaryColor : borderColor,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                HapticFeedback.lightImpact();
                                setState(() => _durationMinutes = mins);
                              }
                            },
                          ),
                        );
                      }),
                      Builder(builder: (context) {
                        final isCustomSelected = ![15, 30, 45, 60, 90].contains(_durationMinutes);
                        return ChoiceChip(
                          avatar: Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: isCustomSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                          ),
                          label: Text(
                            isCustomSelected ? '${_durationMinutes}m (Custom)' : 'Custom...',
                          ),
                          selected: isCustomSelected,
                          selectedColor: primaryColor,
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isCustomSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isCustomSelected ? primaryColor : borderColor,
                            ),
                          ),
                          onSelected: (_) {
                            _showCustomDurationDialog();
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Routine Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _isSubmitting ? null : _handleSave,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      'Save Routine Task',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
