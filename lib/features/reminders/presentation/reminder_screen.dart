import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../calendar_sync/repositories/sync_repository.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import 'widgets/add_reminder_bottom_sheet.dart';
import 'widgets/reminder_header_card.dart';

/// Dedicated screen for displaying and managing scheduled Reminders with
/// status & category filter pills, Google Calendar dropdown view, haptic micro-interactions, and glowing FAB.
/// Styled to match the exact glassmorphic & dark gradient design system of the Routine Dashboard.
class ReminderScreen extends StatefulWidget {
  final RoutineRepository routineRepository;
  final AuthService? authService;
  final SyncRepository? syncRepository;
  final VoidCallback? onNavigateToSettings;

  const ReminderScreen({
    super.key,
    required this.routineRepository,
    this.authService,
    this.syncRepository,
    this.onNavigateToSettings,
  });

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

enum ReminderStatusFilter { upcoming, completed, all }

class _ReminderScreenState extends State<ReminderScreen>
    with AutomaticKeepAliveClientMixin {
  static final DateFormat _reminderDateFormat = DateFormat('EEE, MMM d, yyyy • ').add_jm();

  @override
  bool get wantKeepAlive => true;
  List<RoutineTask> _allReminders = [];
  bool _isLoading = true;

  ReminderStatusFilter _statusFilter = ReminderStatusFilter.upcoming;
  String? _selectedCategory; // null = all categories

  // Calendar Dropdown Feature States
  bool _isCalendarExpanded = false;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedCalendarDate;

  /// Selection mode state for multi-select batch deletion
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  void _enterSelectionMode(String initialTaskId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(initialTaskId);
    });
  }

  void _toggleTaskSelection(String taskId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _selectAllVisibleTasks() {
    HapticFeedback.lightImpact();
    final visibleIds = _filteredReminders.map((t) => t.id).toSet();
    setState(() {
      if (_selectedTaskIds.length == visibleIds.length) {
        _selectedTaskIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedTaskIds.addAll(visibleIds);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  Future<void> _deleteSelectedReminders() async {
    if (_selectedTaskIds.isEmpty) return;
    HapticFeedback.mediumImpact();

    final remindersToDelete = _allReminders
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();

    // ── Optimistic UI: remove from memory immediately ───────────────────────
    _exitSelectionMode();
    setState(() {
      _allReminders.removeWhere(
          (t) => remindersToDelete.any((d) => d.id == t.id));
    });

    // ── Show SnackBar immediately (no waiting for DB) ──────────────────────────
    if (mounted && remindersToDelete.isNotEmpty) {
      final count = remindersToDelete.length;
      final label = count == 1 ? '1 reminder deleted' : '$count reminders deleted';

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          persist: false,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: ThemeController.instance.seedColor,
            onPressed: () async {
              HapticFeedback.lightImpact();
              // Restore optimistically in memory first
              setState(() {
                for (final task in remindersToDelete) {
                  if (!_allReminders.any((t) => t.id == task.id)) {
                    _allReminders.add(task);
                  }
                }
                _allReminders.sort((a, b) => a.startTime.compareTo(b.startTime));
              });
              // DB restore in background (batch)
              await widget.routineRepository.batchRestoreTasks(remindersToDelete);
              _silentReloadReminders();
            },
          ),
        ),
      );
    }

    // ── Background DB ops (parallel batch) ────────────────────────────────
    await widget.routineRepository.batchDeleteTasks(remindersToDelete);
    _silentReloadReminders();
  }

  /// Reloads reminders without showing a loading spinner — avoids jarring UI
  /// collapses while keeping state consistent with the database.
  Future<void> _silentReloadReminders() async {
    final reminders = await widget.routineRepository.getReminders();
    if (mounted) {
      reminders.sort((a, b) => a.startTime.compareTo(b.startTime));
      setState(() => _allReminders = reminders);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final reminders = await widget.routineRepository.getReminders();
    if (mounted) {
      reminders.sort((a, b) => a.startTime.compareTo(b.startTime));
      setState(() {
        _allReminders = reminders;
        _isLoading = false;
      });
    }
  }

  int get _upcomingCount => _allReminders.where((t) => !t.isCompleted).length;
  int get _completedCount => _allReminders.where((t) => t.isCompleted).length;
  double get _completionProgress => _allReminders.isEmpty ? 0.0 : _completedCount / _allReminders.length;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<RoutineTask> _getRemindersForDate(DateTime date) {
    return _allReminders.where((t) => _isSameDay(t.startTime.toLocal(), date)).toList();
  }

  List<DateTime> _buildCalendarDaysGrid(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysBefore = firstDayOfMonth.weekday % 7; // Sunday = 0, Mon = 1 ... Sat = 6
    final startGridDate = firstDayOfMonth.subtract(Duration(days: daysBefore));

    return List.generate(35, (index) => startGridDate.add(Duration(days: index)));
  }

  Future<void> _handleSyncAction() async {
    final syncRepository = widget.syncRepository;
    if (syncRepository != null && (widget.authService?.isSignedIn ?? false)) {
      try {
        final now = DateTime.now();
        await syncRepository.synchronize(
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now.add(const Duration(days: 7)),
        );
      } catch (_) {}
    }
    await _loadReminders();
  }

  Future<void> _deleteReminder(RoutineTask task) async {
    HapticFeedback.mediumImpact();

    // Optimistic UI: remove from list immediately
    setState(() => _allReminders.removeWhere((t) => t.id == task.id));

    // DB op in background
    widget.routineRepository.deleteTask(task);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('"${task.title}" deleted')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          persist: false,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: ThemeController.instance.seedColor,
            onPressed: () async {
              HapticFeedback.lightImpact();
              // Restore in memory first
              setState(() {
                if (!_allReminders.any((t) => t.id == task.id)) {
                  _allReminders.add(task);
                  _allReminders.sort((a, b) => a.startTime.compareTo(b.startTime));
                }
              });
              widget.routineRepository.restoreTask(task);
            },
          ),
        ),
      );
    }
  }

  Future<void> _toggleCompletion(RoutineTask task) async {
    HapticFeedback.lightImpact();
    await widget.routineRepository.toggleTaskCompletion(task);
    _loadReminders();
  }

  List<RoutineTask> get _filteredReminders {
    return _allReminders.where((task) {
      // Status filter
      if (_statusFilter == ReminderStatusFilter.upcoming && task.isCompleted) {
        return false;
      }
      if (_statusFilter == ReminderStatusFilter.completed && !task.isCompleted) {
        return false;
      }
      // Category filter
      if (_selectedCategory != null &&
          task.category.toLowerCase() != _selectedCategory!.toLowerCase()) {
        return false;
      }
      // Calendar date filter
      if (_selectedCalendarDate != null) {
        if (!_isSameDay(task.startTime.toLocal(), _selectedCalendarDate!)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showEditReminderDialog(RoutineTask task) {
    final titleController = TextEditingController(text: task.title);
    String selectedCategory = task.category;
    int durationMinutes = task.durationMinutes;
    DateTime selectedDate = task.startTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(task.startTime);

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
                      // ── Header ──────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Reminder',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Modify reminder details and date',
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

                      // ── Title Input ─────────────────────────────────────
                      Text(
                        'REMINDER TITLE',
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter reminder title...',
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

                      // ── Category Selection ──────────────────────────────
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

                      // ── Date & Time Pickers ─────────────────────────────
                      Text(
                        'DATE & TIME',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setDialogState(() => selectedDate = date);
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
                                    Icon(Icons.calendar_month_rounded, color: primaryColor, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM d, yyyy').format(selectedDate),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (time != null) {
                                  setDialogState(() => selectedTime = time);
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
                                    Expanded(
                                      child: Text(
                                        selectedTime.format(context),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── Duration Selection ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DURATION',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$durationMinutes mins',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quick Presets
                      Row(
                        children: [15, 30, 45, 60, 90, 120].map((mins) {
                          final isSel = durationMinutes == mins;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setDialogState(() => durationMinutes = mins);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? primaryColor
                                        : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel
                                          ? primaryColor
                                          : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${mins}m',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                          thumbColor: primaryColor,
                          overlayColor: primaryColor.withValues(alpha: 0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: durationMinutes.toDouble().clamp(15.0, 180.0),
                          min: 15,
                          max: 180,
                          divisions: 11,
                          onChanged: (val) {
                            setDialogState(() => durationMinutes = val.toInt());
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Actions ─────────────────────────────────────────
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
                              onPressed: () => Navigator.pop(dialogContext),
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
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;

                                final newStartTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final updatedTask = task.copyWith(
                                  title: title,
                                  category: selectedCategory,
                                  startTime: newStartTime,
                                  durationMinutes: durationMinutes,
                                );

                                await widget.routineRepository.updateTask(updatedTask);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                _loadReminders();
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
    super.build(context);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        final currentMode = controller.themeMode;
        final isDark = currentMode == ThemeMode.dark
            ? true
            : currentMode == ThemeMode.light
                ? false
                : (MediaQuery.of(context).platformBrightness == Brightness.dark);
        final displayedReminders = _filteredReminders;
        final primaryColor = controller.seedColor;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          floatingActionButton: _isSelectionMode
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: FloatingActionButton.extended(
                    heroTag: 'reminders-fab',
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AddReminderBottomSheet.show(
                        context,
                        routineRepository: widget.routineRepository,
                        onReminderAdded: _loadReminders,
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _handleSyncAction,
                color: primaryColor,
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: ReminderHeaderCard(
                            key: const ValueKey('reminder-header-card'),
                            total: _allReminders.length,
                            upcomingCount: _upcomingCount,
                            completedCount: _completedCount,
                            completionProgress: _completionProgress,
                            isSelectionMode: _isSelectionMode,
                            selectedCount: _selectedTaskIds.length,
                            totalVisibleCount: displayedReminders.length,
                            onSelectAll: _selectAllVisibleTasks,
                            onCancelSelection: _exitSelectionMode,
                            onDeleteSelected: _deleteSelectedReminders,
                            onEditSelected: _editSingleSelectedReminder,
                            onTaskDroppedToDelete: _deleteReminder,
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCalendarDropdownCard(theme, isDark),
                              const SizedBox(height: 12),

                              if (_selectedCalendarDate != null) ...[
                                _buildActiveDateFilterBadge(isDark),
                                const SizedBox(height: 10),
                              ],

                              _buildFilterRow(),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      sliver: _isLoading
                          ? SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator(color: primaryColor)),
                            )
                          : displayedReminders.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyState())
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final reminder = displayedReminders[index];
                                      return RepaintBoundary(
                                        key: ValueKey(reminder.id),
                                        child: _buildReminderCard(reminder),
                                      );
                                    },
                                    childCount: displayedReminders.length,
                                    findChildIndexCallback: (key) {
                                      final ValueKey<String> valueKey = key as ValueKey<String>;
                                      final idx = displayedReminders.indexWhere((r) => r.id == valueKey.value);
                                      return idx >= 0 ? idx : null;
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Google Calendar-Style Dropdown & Monthly Interactive Grid Card
  Widget _buildCalendarDropdownCard(ThemeData theme, bool isDark) {
    final primaryColor = ThemeController.instance.seedColor;
    final isSelectedDateActive = _selectedCalendarDate != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? (isSelectedDateActive ? primaryColor : const Color(0xFF334155))
              : (isSelectedDateActive ? primaryColor.withValues(alpha: 0.5) : Colors.grey.shade200),
          width: isSelectedDateActive ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dropdown Header Row
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isCalendarExpanded = !_isCalendarExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Calendar',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedCalendarDate != null
                              ? 'Filtered: ${DateFormat("MMM d, yyyy").format(_selectedCalendarDate!)} (${_getRemindersForDate(_selectedCalendarDate!).length} reminder${_getRemindersForDate(_selectedCalendarDate!).length == 1 ? '' : 's'})'
                              : 'Tap to ${_isCalendarExpanded ? "collapse" : "expand"} calendar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCalendarExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Month Grid
          if (_isCalendarExpanded) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  // Month Navigator Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_focusedMonth),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _focusedMonth = DateTime.now();
                                _selectedCalendarDate = DateTime.now();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Today',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 22),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Day of week headers (Sun ... Sat)
                  Row(
                    children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // 35-Day Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 35,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.05,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final daysGrid = _buildCalendarDaysGrid(_focusedMonth);
                      final dayDate = daysGrid[index];
                      final isCurrentMonth = dayDate.month == _focusedMonth.month;
                      final isToday = _isSameDay(dayDate, DateTime.now());
                      final isSelected = _selectedCalendarDate != null && _isSameDay(dayDate, _selectedCalendarDate!);

                      final dateReminders = _getRemindersForDate(dayDate);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedCalendarDate = null;
                            } else {
                              _selectedCalendarDate = dayDate;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : (isToday
                                      ? const Color(0xFF00D2D3)
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                              width: isToday ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isCurrentMonth
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? const Color(0xFF475569) : Colors.grey.shade400)),
                                ),
                              ),
                              if (dateReminders.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dateReminders.take(3).map((r) {
                                    final dotColor = AppTheme.categoryColor(r.category);
                                    return Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? Colors.white : dotColor,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Active Date Filter Banner Pill
  Widget _buildActiveDateFilterBadge(bool isDark) {
    final primaryColor = ThemeController.instance.seedColor;
    final count = _getRemindersForDate(_selectedCalendarDate!).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 15, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered Date: ${DateFormat("E, MMM d, yyyy").format(_selectedCalendarDate!)} ($count reminder${count == 1 ? '' : 's'})',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCalendarDate = null);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontally scrollable list of circular filter icon buttons.
  Widget _buildFilterRow() {
    final primaryColor = ThemeController.instance.seedColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Status Filters
          _FilterChip(
            label: 'Upcoming',
            icon: Icons.schedule_rounded,
            isSelected: _statusFilter == ReminderStatusFilter.upcoming &&
                _selectedCategory == null,
            color: primaryColor,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_statusFilter == ReminderStatusFilter.upcoming &&
                    _selectedCategory == null) {
                  _statusFilter = ReminderStatusFilter.all;
                } else {
                  _statusFilter = ReminderStatusFilter.upcoming;
                  _selectedCategory = null;
                }
              });
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed',
            icon: Icons.task_alt_rounded,
            isSelected: _statusFilter == ReminderStatusFilter.completed &&
                _selectedCategory == null,
            color: const Color(0xFF00D2D3),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_statusFilter == ReminderStatusFilter.completed &&
                    _selectedCategory == null) {
                  _statusFilter = ReminderStatusFilter.all;
                } else {
                  _statusFilter = ReminderStatusFilter.completed;
                  _selectedCategory = null;
                }
              });
            },
          ),
          const SizedBox(width: 12),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).colorScheme.outline.withAlpha(80),
          ),
          const SizedBox(width: 12),
          // Category Filters
          _FilterChip(
            label: 'Work',
            icon: Icons.work_outline_rounded,
            isSelected: _selectedCategory == 'Work',
            color: AppTheme.categoryColor('work'),
            onTap: () => _toggleCategoryFilter('Work'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Personal',
            icon: Icons.person_outline_rounded,
            isSelected: _selectedCategory == 'Personal',
            color: AppTheme.categoryColor('personal'),
            onTap: () => _toggleCategoryFilter('Personal'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Study',
            icon: Icons.school_outlined,
            isSelected: _selectedCategory == 'Study',
            color: AppTheme.categoryColor('study'),
            onTap: () => _toggleCategoryFilter('Study'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Health',
            icon: Icons.favorite_border_rounded,
            isSelected: _selectedCategory == 'Health',
            color: AppTheme.categoryColor('health'),
            onTap: () => _toggleCategoryFilter('Health'),
          ),
        ],
      ),
    );
  }

  void _toggleCategoryFilter(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
    });
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = ThemeController.instance.seedColor;

    String emptyTitle = 'No Scheduled Reminders';
    String emptySubtitle = 'Tap "+ New Reminder" to schedule upcoming alerts.';
    IconData emptyIcon = Icons.event_note_rounded;

    if (_statusFilter == ReminderStatusFilter.upcoming && _selectedCategory == null && _selectedCalendarDate == null) {
      emptyTitle = 'No Upcoming Reminders';
      emptySubtitle = 'You have no upcoming reminders scheduled right now.';
      emptyIcon = Icons.event_available_rounded;
    } else if (_statusFilter == ReminderStatusFilter.completed && _selectedCategory == null && _selectedCalendarDate == null) {
      emptyTitle = 'Nothing Completed';
      emptySubtitle = 'Completed reminders will show up here once checked off.';
      emptyIcon = Icons.task_alt_rounded;
    } else if (_selectedCategory != null || _selectedCalendarDate != null) {
      emptyTitle = 'No Matching Reminders';
      emptySubtitle = 'No reminders match your active filters.';
      emptyIcon = Icons.filter_alt_off_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                emptyIcon,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(RoutineTask reminder) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = AppTheme.categoryColor(reminder.category);
    final isSelected = _selectedTaskIds.contains(reminder.id);

    return _StartToEndDismissible(
      key: Key(reminder.id),
      enabled: !_isSelectionMode,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: () => _deleteReminder(reminder),
      child: _isSelectionMode
          ? LongPressDraggable<RoutineTask>(
              data: reminder,
              delay: const Duration(milliseconds: 180),
              onDragStarted: () {
                HapticFeedback.mediumImpact();
              },
              feedback: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                  ),
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    color: categoryColor.withAlpha(isDark ? 230 : 250),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              reminder.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.north_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Text(
                                  'Drag to delete',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _buildReminderCardContent(
                  reminder: reminder,
                  theme: theme,
                  isDark: isDark,
                  categoryColor: categoryColor,
                  isSelected: isSelected,
                ),
              ),
              child: GestureDetector(
                onTap: () => _toggleTaskSelection(reminder.id),
                child: _buildReminderCardContent(
                  reminder: reminder,
                  theme: theme,
                  isDark: isDark,
                  categoryColor: categoryColor,
                  isSelected: isSelected,
                ),
              ),
            )
          : GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _enterSelectionMode(reminder.id);
              },
              child: _buildReminderCardContent(
                reminder: reminder,
                theme: theme,
                isDark: isDark,
                categoryColor: categoryColor,
                isSelected: isSelected,
              ),
            ),
    );
  }

  Widget _buildReminderCardContent({
    required RoutineTask reminder,
    required ThemeData theme,
    required bool isDark,
    required Color categoryColor,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? categoryColor.withAlpha(isDark ? 50 : 35)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? categoryColor
              : reminder.isCompleted
                  ? categoryColor.withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          width: isSelected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (_isSelectionMode)
              GestureDetector(
                onTap: () => _toggleTaskSelection(reminder.id),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? categoryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? categoryColor : theme.colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: AnimatedScale(
                      scale: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _toggleCompletion(reminder),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: reminder.isCompleted ? categoryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: reminder.isCompleted ? categoryColor : categoryColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: reminder.isCompleted
                        ? [
                            BoxShadow(
                              color: categoryColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: reminder.isCompleted
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      decoration: reminder.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                      color: reminder.isCompleted
                          ? (isDark ? const Color(0xFF64748B) : Colors.grey.shade500)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_reminderDateFormat.format(reminder.startTime.toLocal())} (${reminder.durationMinutes}m)',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: categoryColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                reminder.category,
                style: TextStyle(
                  color: categoryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Triggered when tapping the Edit button in the top selection header bar (when exactly 1 reminder is selected).
  void _editSingleSelectedReminder() {
    if (_selectedTaskIds.length == 1) {
      final selectedId = _selectedTaskIds.first;
      final reminder = _allReminders.firstWhere((r) => r.id == selectedId);
      _showEditReminderDialog(reminder);
    }
  }
}

/// Filter chip button widget.
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFE2E8F0) : Colors.black87),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom Start-To-End Dismissible Widget ─────────────────────────────────────

/// Gesture recognizer that only handles rightward drags.
/// If the user starts dragging left (`delta.dx < 0`), it immediately stops tracking
/// so parent scrollables (e.g. PageView) can handle the left swipe to switch screens.
class _RightSwipeOnlyRecognizer extends HorizontalDragGestureRecognizer {
  _RightSwipeOnlyRecognizer({super.debugOwner});

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (event.delta.dx < 0) {
        stopTrackingPointer(event.pointer);
        return;
      }
    }
    super.handleEvent(event);
  }
}

class _StartToEndDismissible extends StatefulWidget {
  final Widget child;
  final Widget background;
  final VoidCallback onDismissed;
  final bool enabled;

  const _StartToEndDismissible({
    super.key,
    required this.child,
    required this.background,
    required this.onDismissed,
    this.enabled = true,
  });

  @override
  State<_StartToEndDismissible> createState() => _StartToEndDismissibleState();
}

class _StartToEndDismissibleState extends State<_StartToEndDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0.0;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragExtent = 0.0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _isDismissed) return;
    _dragExtent += details.delta.dx;
    if (_dragExtent < 0) _dragExtent = 0;
    final width = MediaQuery.of(context).size.width;
    _controller.value = (_dragExtent / width).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled || _isDismissed) return;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_controller.value > 0.35 || velocity > 350) {
      _isDismissed = true;
      _controller
          .animateTo(1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic)
          .then((_) {
        if (mounted) {
          widget.onDismissed();
        }
      });
    } else {
      _controller.animateTo(0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final gestures = <Type, GestureRecognizerFactory>{
      _RightSwipeOnlyRecognizer:
          GestureRecognizerFactoryWithHandlers<_RightSwipeOnlyRecognizer>(
        () => _RightSwipeOnlyRecognizer(debugOwner: this),
        (_RightSwipeOnlyRecognizer instance) {
          instance.onStart = _handleDragStart;
          instance.onUpdate = _handleDragUpdate;
          instance.onEnd = _handleDragEnd;
        },
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: _controller.value.clamp(0.0, 1.0),
                    child: widget.background,
                  );
                },
              ),
            ),
            RawGestureDetector(
              gestures: gestures,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_controller.value * width, 0),
                    child: child,
                  );
                },
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

