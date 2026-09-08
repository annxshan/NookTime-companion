import 'package:equatable/equatable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Represents a single data point in a daily or weekly productivity trend.
class DailyTrendPoint extends Equatable {
  final DateTime date;
  final double hoursSpent;

  const DailyTrendPoint({
    required this.date,
    required this.hoursSpent,
  });

  @override
  List<Object?> get props => [date, hoursSpent];
}

/// Immutable data class holding aggregated analytical metrics for Nooktime.
class AnalyticsData extends Equatable {
  /// Category name -> total focus hours spent in that category.
  final Map<String, double> categoryDistribution;

  /// Total focus time in hours across all categories.
  final double totalFocusHours;

  /// Task completion rate from 0.0 (0%) to 1.0 (100%).
  final double completionRate;

  /// List of daily trend data points for chart rendering.
  final List<DailyTrendPoint> dailyTrends;

  /// Count of completed tasks for the period.
  final int completedTasksCount;

  /// Count of pending or scheduled tasks for the period.
  final int pendingTasksCount;

  /// Total task count for the period.
  final int totalTasksCount;

  /// Name of the most productive day (e.g. "Wednesday").
  final String mostProductiveDay;

  const AnalyticsData({
    required this.categoryDistribution,
    required this.totalFocusHours,
    required this.completionRate,
    required this.dailyTrends,
    required this.completedTasksCount,
    required this.pendingTasksCount,
    required this.totalTasksCount,
    required this.mostProductiveDay,
  });

  /// Alias getter for [completedTasksCount] for flexibility.
  int get doneTasksCount => completedTasksCount;

  /// Initial empty analytics state.
  factory AnalyticsData.empty() {
    return const AnalyticsData(
      categoryDistribution: {},
      totalFocusHours: 0.0,
      completionRate: 0.0,
      dailyTrends: [],
      completedTasksCount: 0,
      pendingTasksCount: 0,
      totalTasksCount: 0,
      mostProductiveDay: 'N/A',
    );
  }

  /// Converts category distribution map into `fl_chart` [PieChartSectionData] list.
  List<PieChartSectionData> toPieChartSections({
    required Map<String, Color> categoryColors,
    double radius = 50.0,
  }) {
    if (totalFocusHours == 0.0) return [];

    return categoryDistribution.entries.map((entry) {
      final category = entry.key;
      final hours = entry.value;
      final percentage = (hours / totalFocusHours) * 100;
      final color = categoryColors[category] ?? Colors.teal;

      return PieChartSectionData(
        color: color,
        value: hours,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// Converts daily trends into `fl_chart` [BarChartGroupData] list.
  List<BarChartGroupData> toBarChartGroups({
    required Color barColor,
    double barWidth = 16.0,
  }) {
    return dailyTrends.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: point.hoursSpent,
            color: barColor,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  /// Returns a copy of [AnalyticsData] with updated fields.
  AnalyticsData copyWith({
    Map<String, double>? categoryDistribution,
    double? totalFocusHours,
    double? completionRate,
    List<DailyTrendPoint>? dailyTrends,
    int? completedTasksCount,
    int? pendingTasksCount,
    int? totalTasksCount,
    String? mostProductiveDay,
  }) {
    return AnalyticsData(
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
      totalFocusHours: totalFocusHours ?? this.totalFocusHours,
      completionRate: completionRate ?? this.completionRate,
      dailyTrends: dailyTrends ?? this.dailyTrends,
      completedTasksCount: completedTasksCount ?? this.completedTasksCount,
      pendingTasksCount: pendingTasksCount ?? this.pendingTasksCount,
      totalTasksCount: totalTasksCount ?? this.totalTasksCount,
      mostProductiveDay: mostProductiveDay ?? this.mostProductiveDay,
    );
  }

  @override
  List<Object?> get props => [
        categoryDistribution,
        totalFocusHours,
        completionRate,
        dailyTrends,
        completedTasksCount,
        pendingTasksCount,
        totalTasksCount,
        mostProductiveDay,
      ];
}

