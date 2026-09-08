import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../daily_routine/data/routine_repository.dart';

/// Dedicated bottom sheet for creating scheduled Reminders.
class AddReminderBottomSheet extends StatefulWidget {
  final RoutineRepository routineRepository;
  final VoidCallback onReminderAdded;

  const AddReminderBottomSheet({
    super.key,
    required this.routineRepository,
    required this.onReminderAdded,
  });

  static void show(
    BuildContext context, {
    required RoutineRepository routineRepository,
    required VoidCallback onReminderAdded,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReminderBottomSheet(
        routineRepository: routineRepository,
        onReminderAdded: onReminderAdded,
      ),
    );
  }

  @override
  State<AddReminderBottomSheet> createState() => _AddReminderBottomSheetState();
}

class _AddReminderBottomSheetState extends State<AddReminderBottomSheet> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'Personal';
  int _durationMinutes = 30;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSubmitting = false;

  static const List<String> _categories = ['Work', 'Health', 'Personal', 'Study', 'Other'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
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
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await widget.routineRepository.createReminder(
        title: title,
        category: _selectedCategory,
        dateTime: scheduledDateTime,
        durationMinutes: _durationMinutes,
      );

      widget.onReminderAdded();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reminder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.alarm_on_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'New Reminder',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
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
                    labelText: 'Reminder Title',
                    hintText: 'e.g. Call Client, Team Sync, Take Medication',
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

                // Date & Time Selectors Row
                Row(
                  children: [
                    // Date Selector
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
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
                                'DATE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 16, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat('MMM d, yyyy').format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Time Selector
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
                                'TIME',
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

                // Save Reminder Button
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
                      'Save Reminder',
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
