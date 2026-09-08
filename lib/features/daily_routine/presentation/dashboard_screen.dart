import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../ai_assistant/presentation/ai_planner_bottom_sheet.dart';
import '../../ai_assistant/presentation/ai_routine_studio_screen.dart';
import '../../calendar_sync/repositories/sync_repository.dart';
import '../../calendar_sync/services/auth_service.dart';
import '../../gamification/services/streak_service.dart';
import '../../gamification/widgets/streak_celebration_dialog.dart';
import '../data/routine_repository.dart';
import '../domain/models/routine_task.dart';
import 'widgets/add_task_bottom_sheet.dart';
import 'widgets/routine_filter_bar.dart';
import 'widgets/routine_header_card.dart';
import '../../sync/services/cloud_sync_service.dart';

/// Primary dashboard screen listing local-only daily routine tasks with an
/// animated glassmorphic header, interactive task cards, category pills, and
/// haptic micro-interactions.
class DashboardScreen extends StatefulWidget {
  final RoutineRepository routineRepository;
  final AuthService authService;
  final SyncRepository syncRepository;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToReminders;

  const DashboardScreen({
    super.key,
    required this.routineRepository,
    required this.authService,
    required this.syncRepository,
    this.onNavigateToSettings,
    this.onNavigateToReminders,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static final DateFormat _timeFormatter = DateFormat.jm();

  @override
  bool get wantKeepAlive => true;
  List<RoutineTask> _routines = [];
  bool _isLoading = true;
  StreakService? _streakService;

  int _selectedWeekday = DateTime.now().weekday; // 1 = Mon, ..., 7 = Sun
  TaskStatusFilter _statusFilter = TaskStatusFilter.all;
  String _categoryFilter = 'All';

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
    final visibleIds = _filteredRoutines.map((t) => t.id).toSet();
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

  Future<void> _deleteSelectedTasks() async {
    if (_selectedTaskIds.isEmpty) return;
    HapticFeedback.mediumImpact();

    final tasksToDelete = _routines
        .where((t) => _selectedTaskIds.contains(t.id))
        .toList();

    // Classify: multi-day routines get day-scoped update; others get full delete.
    final fullDeleteTasks = <RoutineTask>[];
    final dayUpdatedTasks = <RoutineTask>[]; // trimmed versions
    final dayUpdatedOriginals = <RoutineTask>[]; // originals for undo

    for (final task in tasksToDelete) {
      if (task.isRoutine && task.daysOfWeek.length > 1) {
        final newDays = task.daysOfWeek.where((d) => d != _selectedWeekday).toList();
        dayUpdatedTasks.add(task.copyWith(daysOfWeek: newDays));
        dayUpdatedOriginals.add(task);
      } else {
        fullDeleteTasks.add(task);
      }
    }

    // ── Optimistic UI: remove/update in memory immediately ─────────────────────
    _exitSelectionMode();
    setState(() {
      // Remove fully-deleted tasks from the list
      _routines.removeWhere((t) => fullDeleteTasks.any((d) => d.id == t.id));
      // Apply day-scoped updates in memory
      for (var i = 0; i < _routines.length; i++) {
        final updated = dayUpdatedTasks.firstWhere(
          (u) => u.id == _routines[i].id,
          orElse: () => _routines[i],
        );
        _routines[i] = updated;
      }
    });

    // ── Show SnackBar immediately (no waiting for DB) ──────────────────────────
    if (mounted && tasksToDelete.isNotEmpty) {
      final count = tasksToDelete.length;
      final dayName = _fullDayNames[(_selectedWeekday - 1).clamp(0, 6)];
      final label = count == 1
          ? '1 task removed from $dayName'
          : '$count tasks removed from $dayName';

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
            textColor: const Color(0xFF00D2D3),
            onPressed: () async {
              HapticFeedback.lightImpact();
              // Restore optimistically in memory first
              setState(() {
                _routines.addAll(fullDeleteTasks);
                // Revert day-scoped updates
                for (var i = 0; i < _routines.length; i++) {
                  final original = dayUpdatedOriginals.firstWhere(
                    (o) => o.id == _routines[i].id,
                    orElse: () => _routines[i],
                  );
                  _routines[i] = original;
                }
                _routines.sort((a, b) {
                  final timeA = a.startTime.hour * 60 + a.startTime.minute;
                  final timeB = b.startTime.hour * 60 + b.startTime.minute;
                  return timeA.compareTo(timeB);
                });
              });
              // DB restore in background
              await Future.wait([
                widget.routineRepository.batchRestoreTasks(fullDeleteTasks),
                widget.routineRepository.batchUpdateTasks(dayUpdatedOriginals),
              ]);
              _silentReloadRoutines();
            },
          ),
        ),
      );
    }

    // ── Background DB ops (parallel) ───────────────────────────────────────────
    await Future.wait([
      widget.routineRepository.batchDeleteTasks(fullDeleteTasks),
      widget.routineRepository.batchUpdateTasks(dayUpdatedTasks),
    ]);
    _silentReloadRoutines();
  }

  /// Reloads routines without showing a loading spinner — avoids jarring UI
  /// collapses while keeping state consistent with the database.
  Future<void> _silentReloadRoutines() async {
    final routines = await widget.routineRepository.getRoutines();
    if (mounted) {
      routines.sort((a, b) {
        final timeA = a.startTime.hour * 60 + a.startTime.minute;
        final timeB = b.startTime.hour * 60 + b.startTime.minute;
        return timeA.compareTo(timeB);
      });
      setState(() => _routines = routines);
    }
  }

  /// True only when the selected weekday pill matches today's actual weekday.
  /// Completion state (check/uncheck) only applies when viewing today.
  bool get _isViewingToday => _selectedWeekday == DateTime.now().weekday;

  late final AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadRoutines();
    _initStreakService();
  }

  Future<void> _initStreakService() async {
    final service = await StreakService.create();
    if (mounted) setState(() => _streakService = service);
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutines() async {
    setState(() => _isLoading = true);
    final routines = await widget.routineRepository.getRoutines();
    if (mounted) {
      // Sort chronologically by start time so tasks always appear in order
      routines.sort((a, b) {
        final timeA = a.startTime.hour * 60 + a.startTime.minute;
        final timeB = b.startTime.hour * 60 + b.startTime.minute;
        return timeA.compareTo(timeB);
      });
      setState(() {
        _routines = routines;
        _isLoading = false;
      });
      _headerAnimController.forward(from: 0);
    }
  }

  /// Pull-to-refresh handler: imports remote data from Cloud Firestore,
  /// backs up local tasks to cloud, and reloads local SQLite routines.
  Future<void> _handlePullToRefresh() async {
    HapticFeedback.mediumImpact();
    if (widget.authService.isSignedIn) {
      try {
        final cloud = CloudSyncService();
        await cloud.restoreUserDataFromCloud();
        await cloud.backupToCloud();
      } catch (e) {
        debugPrint('Pull-to-refresh cloud sync notice: $e');
      }
    }

    await _loadRoutines();
  }

  void _toggleTaskCompletion(RoutineTask task) {
    HapticFeedback.lightImpact();
    final wasCompletedBefore = task.isCompletedToday;
    final today = RoutineTask.todayDateString;

    // Build the optimistic updated task
    final updatedTask = task.copyWith(
      isCompleted: !wasCompletedBefore,
      lastCompletedDate: () => !wasCompletedBefore
          ? (task.isRoutine ? today : task.lastCompletedDate)
          : task.lastCompletedDate,
      updatedAt: DateTime.now().toUtc(),
    );

    // 1. Instant UI update — synchronous, no await, zero lag
    setState(() {
      final index = _routines.indexWhere((t) => t.id == task.id);
      if (index != -1) _routines[index] = updatedTask;
    });

    // 2. Fire-and-forget: DB + streak in background (never blocks the UI)
    _persistToggleAndEvaluateStreak(task, wasCompletedBefore);
  }

  Future<void> _persistToggleAndEvaluateStreak(
      RoutineTask task, bool wasCompletedBefore) async {
    // DB persistence & Cloud sync
    await widget.routineRepository.toggleTaskCompletion(task);

    // Streak evaluation only when completing a task
    if (!wasCompletedBefore && mounted) {
      final todayWeekday = DateTime.now().weekday;
      final activeRoutinesToday = _routines
          .where((t) => t.isRoutine && t.isScheduledForDay(todayWeekday))
          .toList();
      final total = activeRoutinesToday.length;
      final completed =
          activeRoutinesToday.where((t) => t.isCompletedToday).length;

      final service = _streakService;
      if (service != null) {
        final earned = await service.checkAndIncrementStreak(
          totalTasks: total,
          completedTasks: completed,
        );
        if (earned && mounted) {
          final streak = await service.getCurrentStreak();
          if (mounted) {
            await StreakCelebrationDialog.show(context, streakCount: streak);
          }
        }
        if (mounted) setState(() {}); // Refresh header streak badge
      }
    }
  }

  Future<void> _deleteTask(RoutineTask task) async {
    HapticFeedback.mediumImpact();
    final dayName = _fullDayNames[(_selectedWeekday - 1).clamp(0, 6)];

    if (task.isRoutine && task.daysOfWeek.length > 1) {
      final newDays = task.daysOfWeek.where((d) => d != _selectedWeekday).toList();
      final updatedTask = task.copyWith(daysOfWeek: newDays);

      // Optimistic UI: update in memory immediately
      setState(() {
        final idx = _routines.indexWhere((t) => t.id == task.id);
        if (idx != -1) _routines[idx] = updatedTask;
      });

      // DB op in background
      widget.routineRepository.updateTask(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('"${task.title}" removed from $dayName')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            persist: false,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF00D2D3),
              onPressed: () async {
                HapticFeedback.lightImpact();
                // Restore in memory first
                setState(() {
                  final idx = _routines.indexWhere((t) => t.id == task.id);
                  if (idx != -1) _routines[idx] = task;
                });
                widget.routineRepository.updateTask(task);
              },
            ),
          ),
        );
      }
    } else {
      // Optimistic UI: remove from list immediately
      setState(() => _routines.removeWhere((t) => t.id == task.id));

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
              textColor: const Color(0xFF00D2D3),
              onPressed: () async {
                HapticFeedback.lightImpact();
                // Restore in memory first
                setState(() {
                  if (!_routines.any((t) => t.id == task.id)) {
                    _routines.add(task);
                    _routines.sort((a, b) {
                      final timeA = a.startTime.hour * 60 + a.startTime.minute;
                      final timeB = b.startTime.hour * 60 + b.startTime.minute;
                      return timeA.compareTo(timeB);
                    });
                  }
                });
                widget.routineRepository.restoreTask(task);
              },
            ),
          ),
        );
      }
    }
  }


  void _showAddTaskBottomSheet() {
    HapticFeedback.lightImpact();
    AddTaskBottomSheet.show(
      context,
      routineRepository: widget.routineRepository,
      onTaskAdded: _loadRoutines,
      initialWeekday: _selectedWeekday,
      onOpenAiStudio: _showAiPlannerBottomSheet,
      onNavigateToReminders: widget.onNavigateToReminders,
    );
  }

  void _openAiRoutineStudio() async {
    HapticFeedback.lightImpact();
    final bool? scheduleApplied = await AiRoutineStudioScreen.open(
      context,
      routineRepository: widget.routineRepository,
    );

    if (scheduleApplied == true && mounted) {
      // Instantly refresh today's timeline with the new local schedule
      _loadRoutines();
    }
  }

  void _showAiPlannerBottomSheet() async {
    HapticFeedback.lightImpact();
    final bool? scheduleApplied = await AiPlannerBottomSheet.show(
      context,
      routineRepository: widget.routineRepository,
      onScheduleApplied: _loadRoutines,
    );

    if (scheduleApplied == true && mounted) {
      // Instantly refresh today's timeline with the new local schedule
      _loadRoutines();
    }
  }

  void _showEditRoutineDialog(RoutineTask task) {
    final titleController = TextEditingController(text: task.title);
    String selectedCategory = task.category;
    int durationMinutes = task.durationMinutes;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(task.startTime);
    List<int> selectedDays = List.from(task.daysOfWeek);

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
                              Icons.edit_calendar_rounded,
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
                                  'Edit Routine Task',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update task details and timing',
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

                      // ── Start Time Button ───────────────────────────────
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.access_time_filled_rounded, color: primaryColor, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedTime.format(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
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
                      // Duration Quick Preset Pills
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

                      if (task.isRoutine) ...[
                        const SizedBox(height: 12),
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
                            final day = index + 1;
                            final isSelected = selectedDays.contains(day);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setDialogState(() {
                                      if (isSelected) {
                                        if (selectedDays.length > 1) selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
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
                      ],
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

                                final now = DateTime.now();
                                final newStartTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );

                                final updatedTask = task.copyWith(
                                  title: title,
                                  category: selectedCategory,
                                  startTime: newStartTime,
                                  durationMinutes: durationMinutes,
                                  daysOfWeek: selectedDays.isNotEmpty ? selectedDays : task.daysOfWeek,
                                );

                                await widget.routineRepository.updateTask(updatedTask);
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                _loadRoutines();
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

  List<RoutineTask> get _filteredRoutines {
    return _routines.where((task) {
      // 1. Filter by 7-day weekday schedule
      if (!task.isScheduledForDay(_selectedWeekday)) {
        return false;
      }

      // 2. Completion is ONLY meaningful for today's actual weekday.
      //    When viewing another day (e.g. Mon while it's Tue), all tasks
      //    are treated as unchecked — it's a schedule template, not a
      //    live checklist. This prevents cross-day completion bleed.
      final effectivelyCompleted = _isViewingToday && task.isCompletedToday;

      // 3. Filter by status (Upcoming vs Completed vs Expired)
      if (_statusFilter == TaskStatusFilter.upcoming) {
        if (effectivelyCompleted) return false;
        if (_isViewingToday) {
          final timeStatus = getTaskStatus(
            task.startTime.hour,
            task.startTime.minute,
            task.durationMinutes,
          );
          if (timeStatus == TaskTimeStatus.expired) return false;
        }
      } else if (_statusFilter == TaskStatusFilter.completed) {
        // Completed filter only has results when viewing today
        if (!effectivelyCompleted) return false;
      } else if (_statusFilter == TaskStatusFilter.expired) {
        if (effectivelyCompleted) return false;
        // Expired only makes sense for today's actual time
        if (!_isViewingToday) return false;
        final timeStatus = getTaskStatus(
          task.startTime.hour,
          task.startTime.minute,
          task.durationMinutes,
        );
        if (timeStatus != TaskTimeStatus.expired) return false;
      }

      // 4. Filter by category (Work, Study, Health, Personal)
      if (_categoryFilter != 'All' &&
          task.category.toLowerCase() != _categoryFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final activeRoutinesForDay = _routines.where((t) => t.isScheduledForDay(_selectedWeekday)).toList();
    // Progress only counts completions when viewing today — other days show 0/N (scheduled)
    final completedCount = _isViewingToday
        ? activeRoutinesForDay.where((t) => t.isCompletedToday).length
        : 0;
    final totalCount = activeRoutinesForDay.length;

    final filtered = _filteredRoutines;

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = ThemeController.instance.seedColor;

        return Scaffold(
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _handlePullToRefresh,
                color: primaryColor,
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverSafeArea(
                      bottom: false,
                      sliver: SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: RoutineHeaderCard(
                            key: const ValueKey('routine-header-card'),
                            completed: completedCount,
                            total: totalCount,
                            streakService: _streakService,
                            onAiPlannerPressed: _openAiRoutineStudio,
                            isSelectionMode: _isSelectionMode,
                            selectedCount: _selectedTaskIds.length,
                            totalVisibleCount: filtered.length,
                            onSelectAll: _selectAllVisibleTasks,
                            onCancelSelection: _exitSelectionMode,
                            onDeleteSelected: _deleteSelectedTasks,
                            onEditSelected: _editSingleSelectedTask,
                            onTaskDroppedToDelete: _deleteTask,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: Column(
                          children: [
                            WeekdaySelector(
                              selectedWeekday: _selectedWeekday,
                              onWeekdaySelected: (day) {
                                setState(() => _selectedWeekday = day);
                                _loadRoutines();
                              },
                            ),
                            RoutineFilterBar(
                              selectedStatus: _statusFilter,
                              onStatusChanged: (status) {
                                setState(() => _statusFilter = status);
                              },
                              selectedCategory: _categoryFilter,
                              onCategoryChanged: (cat) {
                                setState(() => _categoryFilter = cat);
                              },
                            ),
                            if (!_isViewingToday)
                              _buildScheduleViewBanner(),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      sliver: _isLoading
                          ? SliverFillRemaining(
                              child: _buildLoadingState(),
                            )
                          : filtered.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyState())
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final task = filtered[index];
                                      return RepaintBoundary(
                                        key: ValueKey(task.id),
                                        child: _buildTaskCard(task),
                                      );
                                    },
                                    childCount: filtered.length,
                                    findChildIndexCallback: (key) {
                                      final ValueKey<String> valueKey = key as ValueKey<String>;
                                      final idx = filtered.indexWhere((t) => t.id == valueKey.value);
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
          floatingActionButton: _isSelectionMode ? null : _buildFab(),
        );
      },
    );
  }



  Widget _buildFab() {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FloatingActionButton.extended(
            heroTag: 'dashboard-fab',
            onPressed: _showAddTaskBottomSheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task'),
            elevation: 6,
          ),
        );
      },
    );
  }

  Widget _buildScheduleViewBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dayName = _fullDayNames[(_selectedWeekday - 1).clamp(0, 6)];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_selectedWeekday),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_view_week_rounded,
              size: 14,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Text(
              'Viewing $dayName schedule —',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  static const List<String> _fullDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Widget _buildEmptyState() {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final primaryColor = ThemeController.instance.seedColor;
        final dayName = _fullDayNames[(_selectedWeekday - 1).clamp(0, 6)];

        String title = 'No tasks scheduled for $dayName';
        String subtitle = 'Tap + New Task or use AI Planner to add tasks for $dayName.';
        IconData icon = Icons.calendar_today_rounded;

        if (_statusFilter == TaskStatusFilter.upcoming) {
          title = 'No Upcoming Tasks';
          subtitle = 'You have no upcoming routine tasks for $dayName.';
          icon = Icons.schedule_rounded;
        } else if (_statusFilter == TaskStatusFilter.completed) {
          title = 'Nothing Completed';
          subtitle = 'No completed routine tasks for $dayName yet.';
          icon = Icons.task_alt_rounded;
        } else if (_statusFilter == TaskStatusFilter.expired) {
          title = 'Nothing Expired';
          subtitle = 'You have no expired or past due tasks for $dayName.';
          icon = Icons.history_toggle_off_rounded;
        } else if (_categoryFilter != 'All') {
          title = 'No Matching Tasks';
          subtitle = 'No routine tasks match category "$_categoryFilter".';
          icon = Icons.filter_alt_off_rounded;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(100),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _showAiPlannerBottomSheet,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Plan Routine with AI'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(RoutineTask task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = AppTheme.categoryColor(task.category);
    final isNonTodayDay = !_isViewingToday;

    // Completion only applies when viewing today. Viewing Mon while it's Tue
    // must NOT show Monday's task as checked even if it was checked today.
    final isCompletedToday = _isViewingToday && task.isCompletedToday;
    final isSelected = _selectedTaskIds.contains(task.id);

    final timeStatus = task.isReminder
        ? TaskTimeStatus.active
        : _isViewingToday
            ? getTaskStatus(
                task.startTime.toLocal().hour,
                task.startTime.toLocal().minute,
                task.durationMinutes,
              )
            : TaskTimeStatus.upcoming; // Non-today days always show as scheduled

    // Lock checkbox when: not viewing today, OR outside active time window
    final isLocked = isNonTodayDay ||
        (!isCompletedToday && timeStatus != TaskTimeStatus.active);

    final dayName = _fullDayNames[(_selectedWeekday - 1).clamp(0, 6)];
    final taskTimeStr = _timeFormatter.format(task.startTime.toLocal());

    return _StartToEndDismissible(
      key: Key(task.id),
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
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: () => _deleteTask(task),
      child: _isSelectionMode
          ? LongPressDraggable<RoutineTask>(
              data: task,
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
                              task.title,
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
                child: _buildTaskCardContent(
                  task: task,
                  theme: theme,
                  isDark: isDark,
                  categoryColor: categoryColor,
                  isNonTodayDay: isNonTodayDay,
                  isCompletedToday: isCompletedToday,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  dayName: dayName,
                  taskTimeStr: taskTimeStr,
                  timeStatus: timeStatus,
                ),
              ),
              child: GestureDetector(
                onTap: () => _toggleTaskSelection(task.id),
                child: _buildTaskCardContent(
                  task: task,
                  theme: theme,
                  isDark: isDark,
                  categoryColor: categoryColor,
                  isNonTodayDay: isNonTodayDay,
                  isCompletedToday: isCompletedToday,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  dayName: dayName,
                  taskTimeStr: taskTimeStr,
                  timeStatus: timeStatus,
                ),
              ),
            )
          : GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _enterSelectionMode(task.id);
              },
              child: _buildTaskCardContent(
                task: task,
                theme: theme,
                isDark: isDark,
                categoryColor: categoryColor,
                isNonTodayDay: isNonTodayDay,
                isCompletedToday: isCompletedToday,
                isSelected: isSelected,
                isLocked: isLocked,
                dayName: dayName,
                taskTimeStr: taskTimeStr,
                timeStatus: timeStatus,
              ),
            ),
    );
  }

  Widget _buildTaskCardContent({
    required RoutineTask task,
    required ThemeData theme,
    required bool isDark,
    required Color categoryColor,
    required bool isNonTodayDay,
    required bool isCompletedToday,
    required bool isSelected,
    required bool isLocked,
    required String dayName,
    required String taskTimeStr,
    required TaskTimeStatus timeStatus,
  }) {
    return Opacity(
      opacity: isNonTodayDay ? 0.78 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? categoryColor.withAlpha(isDark ? 50 : 35)
              : isCompletedToday
                  ? theme.colorScheme.surfaceContainerHighest.withAlpha(150)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? categoryColor
                : isNonTodayDay
                    ? theme.colorScheme.outline.withAlpha(120)
                    : isCompletedToday
                        ? categoryColor.withAlpha(80)
                        : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (_isSelectionMode)
                GestureDetector(
                  onTap: () => _toggleTaskSelection(task.id),
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
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: categoryColor.withAlpha(90),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
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
                _AnimatedCheckbox(
                  value: isCompletedToday,
                  color: categoryColor,
                  isLocked: isLocked,
                  onChanged: isLocked
                      ? isNonTodayDay
                          ? () => _showFutureDaySnackbar(dayName, taskTimeStr)
                          : () => _showTimeWindowSnackbar(timeStatus)
                      : () => _toggleTaskCompletion(task),
                ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompletedToday
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: categoryColor.withAlpha(180),
                        decorationThickness: 2,
                        color: isCompletedToday
                            ? theme.colorScheme.onSurfaceVariant
                            : isLocked
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                      ),
                      child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$taskTimeStr · ${task.durationMinutes}m',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (!task.isReminder && !isCompletedToday)
                          isNonTodayDay
                              ? _FutureDayBadge(dayName: dayName, time: taskTimeStr)
                              : _TimeStatusBadge(status: timeStatus),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              _CategoryPill(
                category: task.category,
                color: categoryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimeWindowSnackbar(TaskTimeStatus status) {
    HapticFeedback.heavyImpact();
    final message = status == TaskTimeStatus.upcoming
        ? '⏳ Task hasn\'t started yet. Check in when it\'s time!'
        : '⏰ Time window expired. This task can no longer be completed.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
    );
  }

  /// Shown when tapping a locked checkbox on a non-today weekday.
  void _showFutureDaySnackbar(String dayName, String timeStr) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Unlocks on $dayName at $timeStr',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  /// Triggered when tapping the Edit button in the top selection header bar (when exactly 1 task is selected).
  void _editSingleSelectedTask() {
    if (_selectedTaskIds.length == 1) {
      final selectedId = _selectedTaskIds.first;
      final task = _routines.firstWhere((t) => t.id == selectedId);
      _showEditRoutineDialog(task);
    }
  }
}

// ── Animated Checkbox ─────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatefulWidget {
  final bool value;
  final Color color;
  final VoidCallback onChanged;
  final bool isLocked;

  const _AnimatedCheckbox({
    required this.value,
    required this.color,
    required this.onChanged,
    this.isLocked = false,
  });

  @override
  State<_AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<_AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.isLocked ? Colors.grey.withAlpha(100) : widget.color;
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: widget.value ? effectiveColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isLocked
                  ? Colors.grey.withAlpha(80)
                  : (widget.value ? widget.color : widget.color.withAlpha(120)),
              width: 2,
            ),
            boxShadow: widget.value && !widget.isLocked
                ? [
                    BoxShadow(
                      color: widget.color.withAlpha(80),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: widget.isLocked
              ? Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.grey.withAlpha(160))
              : widget.value
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}

// ── Time Status Badge ──────────────────────────────────────────────────────────

class _TimeStatusBadge extends StatelessWidget {
  final TaskTimeStatus status;

  const _TimeStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      TaskTimeStatus.upcoming => (
          'Upcoming',
          Icons.schedule_outlined,
          const Color(0xFF64748B),
        ),
      TaskTimeStatus.active => (
          'Active',
          Icons.radio_button_on_rounded,
          const Color(0xFF10B981),
        ),
      TaskTimeStatus.expired => (
          'Expired',
          Icons.block_rounded,
          const Color(0xFFEF4444),
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Category Pill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final String category;
  final Color color;

  const _CategoryPill({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Task Time Status ───────────────────────────────────────────────────────────

enum TaskTimeStatus { upcoming, active, expired }

TaskTimeStatus getTaskStatus(
  int startHour,
  int startMinute,
  int durationMinutes,
) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, startHour, startMinute);
  final end = start.add(Duration(minutes: durationMinutes));

  // 5-minute pre-buffer, 15-minute post-grace period
  final windowStart = start.subtract(const Duration(minutes: 5));
  final windowEnd = end.add(const Duration(minutes: 15));

  if (now.isBefore(windowStart)) return TaskTimeStatus.upcoming;
  if (now.isAfter(windowEnd)) return TaskTimeStatus.expired;
  return TaskTimeStatus.active;
}

// ── Future Day Lock Badge ──────────────────────────────────────────────────────

/// Badge shown on task cards when viewing a non-today weekday.
/// Communicates that the task will unlock on [dayName] at [time].
class _FutureDayBadge extends StatelessWidget {
  final String dayName;
  final String time;

  const _FutureDayBadge({required this.dayName, required this.time});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF64748B); // Slate-500 — neutral lock colour
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 10, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            'Unlocks $dayName $time',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
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
    final width = MediaQuery.sizeOf(context).width;
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

    final width = MediaQuery.sizeOf(context).width;
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
  }
}


