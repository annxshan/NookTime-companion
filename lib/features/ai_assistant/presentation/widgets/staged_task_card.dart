import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../daily_routine/domain/models/routine_task.dart';

/// Interactive preview card for staged tasks in the AI Routine Studio.
/// Allows inline editing (time, duration, title) or quick deletion.
class StagedTaskCard extends StatelessWidget {
  final RoutineTask task;
  final VoidCallback onDelete;
  final ValueChanged<RoutineTask> onUpdate;

  const StagedTaskCard({
    super.key,
    required this.task,
    required this.onDelete,
    required this.onUpdate,
  });

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'study':
        return const Color(0xFFFF4757); // Pink / Red
      case 'health':
        return const Color(0xFF00D2D3); // Cyan
      case 'work':
        return const Color(0xFF6C5CE7); // Indigo
      case 'personal':
        return const Color(0xFFFFA502); // Amber
      default:
        return AppTheme.categoryColor(category);
    }
  }

  Color _getCategoryColor(String category) => getCategoryColor(category);

  String _formatDaysOfWeek(List<int> days) {
    if (days.isEmpty || days.length == 7) return 'Daily';
    if (days.length == 5 && days.contains(1) && days.contains(5) && !days.contains(6)) {
      return 'Mon-Fri';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }

    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return days.map((d) => dayNames[d] ?? '$d').join(', ');
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  static void showEditTaskDialog(
    BuildContext context, {
    required RoutineTask task,
    required ValueChanged<RoutineTask> onSave,
    String dialogTitle = 'Edit Staged Task',
    String confirmButtonText = 'Save Changes',
    bool autoFocus = false,
  }) {
    final titleController = TextEditingController(text: task.title);
    final durationController = TextEditingController(text: task.durationMinutes.toString());
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(task.startTime);
    String selectedCategory = task.category;
    List<int> selectedDays = List.from(task.daysOfWeek);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final primaryColor = ThemeController.instance.seedColor;

            final categories = [
              {'name': 'Work', 'icon': Icons.work_rounded},
              {'name': 'Health', 'icon': Icons.favorite_rounded},
              {'name': 'Personal', 'icon': Icons.person_rounded},
              {'name': 'Study', 'icon': Icons.school_rounded},
            ];

            const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 8,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Adjust AI staged task details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(dialogContext);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Title Field
                      Text(
                        'TASK TITLE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        autofocus: autoFocus,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter task title...',
                          prefixIcon: Icon(Icons.edit_note_rounded, color: primaryColor),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Category Selector
                      Text(
                        'CATEGORY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          final catName = cat['name'] as String;
                          final catIcon = cat['icon'] as IconData;
                          final isSel = selectedCategory.toLowerCase() == catName.toLowerCase();
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setDialogState(() => selectedCategory = catName);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? primaryColor
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSel
                                      ? primaryColor
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    catIcon,
                                    size: 16,
                                    color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    catName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Time & Duration Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'START TIME',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() => selectedTime = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_filled_rounded, color: primaryColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedTime.format(context),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MINUTES',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: durationController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '30',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: primaryColor, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Days Active
                      Text(
                        'REPEAT DAYS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(7, (index) {
                          final dayNum = index + 1;
                          final isSelected = selectedDays.contains(dayNum);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setDialogState(() {
                                    if (isSelected) {
                                      if (selectedDays.length > 1) selectedDays.remove(dayNum);
                                    } else {
                                      selectedDays.add(dayNum);
                                      selectedDays.sort();
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      dayLabels[index],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                                ),
                              ),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Navigator.of(dialogContext).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                final newTitle = titleController.text.trim();
                                if (newTitle.isEmpty) return;

                                final dur = int.tryParse(durationController.text) ?? task.durationMinutes;
                                final now = task.startTime;
                                final updatedStartTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final updatedTask = task.copyWith(
                                  title: newTitle,
                                  category: selectedCategory,
                                  startTime: updatedStartTime,
                                  durationMinutes: dur,
                                  daysOfWeek: selectedDays,
                                );

                                onSave(updatedTask);
                                Navigator.of(dialogContext).pop();
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: Text(
                                confirmButtonText,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(task.category);

    final startHour = task.startTime.hour;
    final startMinute = task.startTime.minute;
    final duration = task.durationMinutes;

    final startTotal = startHour * 60 + startMinute;
    final endTotal = startTotal + duration;
    final endHour = (endTotal ~/ 60) % 24;
    final endMinute = endTotal % 60;

    final startTimeStr = TimeOfDay(hour: startHour, minute: startMinute).format(context);
    final endTimeStr = TimeOfDay(hour: endHour, minute: endMinute).format(context);
    final timeRangeStr = '$startTimeStr - $endTimeStr';

    return RepaintBoundary(
      child: Dismissible(
        key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(180),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: InkWell(
        onTap: () => showEditTaskDialog(
          context,
          task: task,
          onSave: onUpdate,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: categoryColor.withAlpha(100),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Vertical category accent bar
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Title, category pill, time details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.category,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        // Days of week pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatDaysOfWeek(task.daysOfWeek),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // Time range
                        Text(
                          timeRangeStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Duration badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatDuration(duration),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Quick Delete Action Button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'Delete Task',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
