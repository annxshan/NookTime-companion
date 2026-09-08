import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/database_service.dart';
import '../models/analytics_data.dart';
import '../services/analytics_engine.dart';

/// Sealed hierarchy representing state of time analytics.
sealed class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final AnalyticsData data;
  final DateTime startDate;
  final DateTime endDate;

  const AnalyticsLoaded({
    required this.data,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [data, startDate, endDate];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Controller managing time analytics state and orchestrating background isolate computations.
class AnalyticsController extends ValueNotifier<AnalyticsState> {
  final DatabaseService _databaseService;

  AnalyticsController({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService(),
        super(AnalyticsInitial());

  /// Loads time analytics metrics for the requested [startDate] and [endDate] range.
  Future<void> loadAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    value = AnalyticsLoading();

    try {
      final tasks = await _databaseService.getAllTasks();
      final logs = await _databaseService.getTimeLogsByDateRange(
        startDate,
        endDate,
      );

      // Offload heavy calculation to background isolate
      final analyticsData = await AnalyticsEngine.processInIsolate(
        tasks: tasks,
        logs: logs,
        startDate: startDate,
        endDate: endDate,
      );

      value = AnalyticsLoaded(
        data: analyticsData,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading analytics: $e\n$stackTrace');
      value = AnalyticsError('Failed to compute analytics: ${e.toString()}');
    }
  }

  /// Helper to load analytics for the current week.
  Future<void> loadWeeklyAnalytics() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);

    await loadAnalytics(startDate: start, endDate: end);
  }

  /// Helper to load analytics for the current month.
  Future<void> loadMonthlyAnalytics() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    await loadAnalytics(startDate: start, endDate: end);
  }
}
