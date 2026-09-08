import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../daily_routine/domain/models/routine_task.dart';
import '../../daily_routine/domain/models/time_log.dart';
import '../models/analytics_data.dart';

/// Data payload passed into background isolate for computation.
class AnalyticsCalculationParams {
  final List<Map<String, dynamic>> rawTasks;
  final List<Map<String, dynamic>> rawLogs;
  final String startDateIso;
  final String endDateIso;

  const AnalyticsCalculationParams({
    required this.rawTasks,
    required this.rawLogs,
    required this.startDateIso,
    required this.endDateIso,
  });
}

/// Pure Dart time-series computation engine for Nooktime.
class AnalyticsEngine {
  /// Offloads heavy time-series aggregations to a background isolate via [compute].
  static Future<AnalyticsData> processInIsolate({
    required List<RoutineTask> tasks,
    required List<TimeLog> logs,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final params = AnalyticsCalculationParams(
      rawTasks: tasks.map((t) => t.toMap()).toList(),
      rawLogs: logs.map((l) => l.toMap()).toList(),
      startDateIso: startDate.toUtc().toIso8601String(),
      endDateIso: endDate.toUtc().toIso8601String(),
    );

    return await compute(_calculateAnalyticsIsolate, params);
  }

  /// Top-level static isolate entry point.
  static AnalyticsData _calculateAnalyticsIsolate(
      AnalyticsCalculationParams params) {
    final tasks =
        params.rawTasks.map((map) => RoutineTask.fromMap(map)).toList();
    final logs = params.rawLogs.map((map) => TimeLog.fromMap(map)).toList();
    final start = DateTime.parse(params.startDateIso).toLocal();
    final end = DateTime.parse(params.endDateIso).toLocal();

    // Filter tasks for selected timeframe if startTime falls in range,
    // otherwise fallback to tasks provided.
    final periodTasks = tasks.where((t) {
      final taskDate = t.startTime.toLocal();
      return !taskDate.isBefore(start) && !taskDate.isAfter(end);
    }).toList();

    final activeTasks = periodTasks.isNotEmpty ? periodTasks : tasks;

    // 1. Calculate completion rate and task counts.
    // Use isCompletedToday for routines (respects midnight reset via lastCompletedDate)
    // and raw isCompleted for reminders (one-time events don't reset).
    final int totalTasksCount = activeTasks.length;
    final int completedTasksCount =
        activeTasks.where((t) => t.isCompletedToday).length;
    final int pendingTasksCount = totalTasksCount - completedTasksCount;
    final double completionRate = totalTasksCount == 0
        ? 0.0
        : (completedTasksCount / totalTasksCount).clamp(0.0, 1.0);

    // 2. Map task categories
    final Map<String, String> taskIdToCategory = {
      for (var task in tasks) task.id: task.category,
    };

    // 3. Calculate category distribution & total focus hours from time logs
    final Map<String, double> categoryHours = {};
    double totalMinutes = 0.0;

    for (final log in logs) {
      final category = taskIdToCategory[log.taskId] ?? 'Other';
      final hours = log.durationSpentMinutes / 60.0;

      categoryHours[category] = (categoryHours[category] ?? 0.0) + hours;
      totalMinutes += log.durationSpentMinutes;
    }

    final double totalFocusHours = totalMinutes / 60.0;

    // 4. Calculate daily trend points & track most productive day
    final List<DailyTrendPoint> dailyTrends = [];
    final int numDays = end.difference(start).inDays + 1;

    DateTime? maxDayDate;
    double maxDayHours = -1.0;
    int maxDayCompletedTasks = -1;

    for (int i = 0; i < numDays; i++) {
      final currentDay = start.add(Duration(days: i));
      final dayLogs = logs.where((l) {
        final logDate = l.timestamp.toLocal();
        return logDate.year == currentDay.year &&
            logDate.month == currentDay.month &&
            logDate.day == currentDay.day;
      });

      final dayTotalMinutes = dayLogs.fold<int>(
        0,
        (sum, log) => sum + log.durationSpentMinutes,
      );
      final double dayHours = dayTotalMinutes / 60.0;

      dailyTrends.add(
        DailyTrendPoint(
          date: currentDay,
          hoursSpent: dayHours,
        ),
      );

      final dayCompletedCount = activeTasks.where((t) {
        final taskDate = t.startTime.toLocal();
        return t.isCompletedToday &&
            taskDate.year == currentDay.year &&
            taskDate.month == currentDay.month &&
            taskDate.day == currentDay.day;
      }).length;

      // Track day with highest productivity (hours spent or completed tasks)
      if (dayHours > maxDayHours ||
          (dayHours == maxDayHours && dayCompletedCount > maxDayCompletedTasks)) {
        if (dayHours > 0 || dayCompletedCount > 0) {
          maxDayHours = dayHours;
          maxDayCompletedTasks = dayCompletedCount;
          maxDayDate = currentDay;
        }
      }
    }

    final String mostProductiveDay = maxDayDate != null
        ? DateFormat('EEEE').format(maxDayDate)
        : 'N/A';

    return AnalyticsData(
      categoryDistribution: categoryHours,
      totalFocusHours: totalFocusHours,
      completionRate: completionRate,
      dailyTrends: dailyTrends,
      completedTasksCount: completedTasksCount,
      pendingTasksCount: pendingTasksCount,
      totalTasksCount: totalTasksCount,
      mostProductiveDay: mostProductiveDay,
    );
  }
}

