import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_controller.dart';
import '../models/analytics_data.dart';
import 'analytics_controller.dart';

/// Screen presenting focus time analytics, productivity reports, category breakdown charts, and trends.
/// Styled to match the exact glassmorphic & dark gradient design system of the Routine Dashboard.
class AnalyticsScreen extends StatefulWidget {
  final AnalyticsController controller;

  const AnalyticsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _selectedPeriodIndex = 1; // 0: Today, 1: This Week, 2: This Month

  static const Map<String, Color> _categoryColors = {
    'Work': Color(0xFF6C5CE7), // Indigo
    'Health': Color(0xFF00D2D3), // Cyan
    'Study': Color(0xFFFD79A8), // Coral
    'Personal': Color(0xFFFFAA00), // Amber
    'Other': Color(0xFF6B7280), // Neutral Gray
  };

  @override
  void initState() {
    super.initState();
    _loadSelectedPeriod();
  }

  void _loadSelectedPeriod() {
    switch (_selectedPeriodIndex) {
      case 0:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        widget.controller.loadAnalytics(startDate: start, endDate: end);
        break;
      case 1:
        widget.controller.loadWeeklyAnalytics();
        break;
      case 2:
        widget.controller.loadMonthlyAnalytics();
        break;
    }
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
        final primaryColor = controller.seedColor;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: ValueListenableBuilder<AnalyticsState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(isDark, primaryColor),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPeriodSelectorRow(isDark, primaryColor),
                          const SizedBox(height: 18),

                          if (state is AnalyticsLoading)
                            SizedBox(
                              height: 280,
                              child: Center(
                                child: CircularProgressIndicator(color: primaryColor),
                              ),
                            )
                          else if (state is AnalyticsError)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                state.message,
                                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                              ),
                            )
                          else if (state is AnalyticsLoaded) ...[
                            RepaintBoundary(
                              child: _buildQuickStatsGrid(context, state.data, isDark),
                            ),
                            const SizedBox(height: 16),

                            RepaintBoundary(
                              child: _buildTaskStatusOverviewCard(context, state.data, isDark),
                            ),
                            const SizedBox(height: 16),

                            RepaintBoundary(
                              child: _buildCategoryPieChartCard(context, state.data, isDark),
                            ),
                            const SizedBox(height: 16),

                            RepaintBoundary(
                              child: _buildWeeklyBarChartCard(context, state.data, isDark),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Dashboard-Style Glassmorphic SliverAppBar Header
  Widget _buildSliverAppBar(bool isDark, Color primaryColor) {
    final List<Color> gradientColors = isDark
        ? [
            Color.alphaBlend(primaryColor.withValues(alpha: 0.45), const Color(0xFF0F141C)),
            const Color(0xFF151C28),
          ]
        : [
            primaryColor,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor),
          ];

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          margin: const EdgeInsets.fromLTRB(16, 44, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark ? primaryColor.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? primaryColor.withValues(alpha: 0.25) : primaryColor.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'PRODUCTIVITY & FOCUS',
                      style: TextStyle(
                        color: isDark ? primaryColor : Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Overview & Trends',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? primaryColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Insights & Time Metrics',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? primaryColor : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark ? primaryColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? primaryColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.analytics_rounded, color: isDark ? primaryColor : Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
      title: const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Text(
          'Time Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,color: Color(0xFFF8F0FA)),
        ),
      ),
    );
  }

  /// Custom Period Selector Row matching Dashboard Category Filter Pills
  Widget _buildPeriodSelectorRow(bool isDark, Color workColor) {
    final periods = ['Today', 'This Week', 'This Month'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Row(
        children: periods.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = _selectedPeriodIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPeriodIndex = index);
                _loadSelectedPeriod();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? workColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: workColor.withValues(alpha: 0.35),
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
                      fontSize: 12.5,
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

  /// 1. Quick Stats 2x2 Summary Grid
  Widget _buildQuickStatsGrid(BuildContext context, AnalyticsData data, bool isDark) {
    const workColor = Color(0xFF6C5CE7);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 400 ? 1.45 : 1.3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Card 1: Total Focus Hours & Tasks
            _buildMetricCard(
              context,
              isDark: isDark,
              icon: Icons.timer_rounded,
              iconColor: workColor,
              value: '${data.totalFocusHours.toStringAsFixed(1)} hrs',
              label: 'Total Focus',
              subtext: '${data.totalTasksCount} Total Tasks',
            ),

            // Card 2: Completion Rate with Progress Ring
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
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
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: data.completionRate,
                            strokeWidth: 4.5,
                            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              data.completionRate >= 0.75
                                  ? const Color(0xFF00D2D3)
                                  : (data.completionRate >= 0.4
                                      ? workColor
                                      : const Color(0xFFFFAA00)),
                            ),
                          ),
                        ),
                        Text(
                          '${(data.completionRate * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completion Rate',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Card 3: Tasks Completed
            _buildMetricCard(
              context,
              isDark: isDark,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF00D2D3),
              value: '${data.completedTasksCount}',
              label: 'Tasks Completed',
              subtext: 'Done',
            ),

            // Card 4: Tasks Pending
            _buildMetricCard(
              context,
              isDark: isDark,
              icon: Icons.pending_actions_rounded,
              iconColor: const Color(0xFFFFAA00),
              value: '${data.pendingTasksCount}',
              label: 'Tasks Pending',
              subtext: 'Pending / Scheduled',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String subtext,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtext,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Detailed Task Breakdown Section
  Widget _buildTaskStatusOverviewCard(
      BuildContext context, AnalyticsData data, bool isDark) {
    final total = data.totalTasksCount;
    final donePercent =
        total > 0 ? (data.completedTasksCount / total) * 100 : 0.0;
    final pendingPercent =
        total > 0 ? (data.pendingTasksCount / total) * 100 : 0.0;
    const workColor = Color(0xFF6C5CE7);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: workColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insert_chart_rounded,
                    color: workColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Task Status Overview',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Multi-color Progress Bar (Done vs. Pending)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: total == 0
                    ? Container(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                      )
                    : Row(
                        children: [
                          if (data.completedTasksCount > 0)
                            Expanded(
                              flex: data.completedTasksCount,
                              child: Container(color: const Color(0xFF00D2D3)),
                            ),
                          if (data.pendingTasksCount > 0)
                            Expanded(
                              flex: data.pendingTasksCount,
                              child: Container(color: const Color(0xFFFFAA00)),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Breakdown List
            _buildBreakdownRow(
              context,
              isDark: isDark,
              color: const Color(0xFF00D2D3),
              title: 'Completed Tasks',
              valueText:
                  '${data.completedTasksCount} tasks (${donePercent.toStringAsFixed(1)}%)',
            ),
            Divider(height: 16, thickness: 0.8, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
            _buildBreakdownRow(
              context,
              isDark: isDark,
              color: const Color(0xFFFFAA00),
              title: 'Pending / Scheduled Tasks',
              valueText:
                  '${data.pendingTasksCount} tasks (${pendingPercent.toStringAsFixed(1)}%)',
            ),
            Divider(height: 16, thickness: 0.8, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    size: 18,
                    color: workColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Most Productive Day',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: workColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: workColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      data.mostProductiveDay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: workColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context, {
    required bool isDark,
    required Color color,
    required String title,
    required String valueText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            valueText,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Category Distribution Pie/Donut Chart Card
  Widget _buildCategoryPieChartCard(BuildContext context, AnalyticsData data, bool isDark) {
    final sections = data.toPieChartSections(categoryColors: _categoryColors);
    const workColor = Color(0xFF6C5CE7);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: workColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: workColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Category Distribution',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sections.isEmpty || data.totalFocusHours == 0.0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28.0),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bubble_chart_outlined,
                      size: 44,
                      color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No focus data logged for this period.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log focus time on tasks to see breakdown.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 34,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.categoryDistribution.entries.map((entry) {
                        final color = _categoryColors[entry.key] ?? Colors.teal;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value.toStringAsFixed(1)}h',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 4. Focus Hours & Task Trend Bar Chart
  Widget _buildWeeklyBarChartCard(BuildContext context, AnalyticsData data, bool isDark) {
    const workColor = Color(0xFF6C5CE7);
    final groups = data.toBarChartGroups(barColor: workColor);
    final bool hasData = data.dailyTrends.any((p) => p.hoursSpent > 0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: workColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: workColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Focus Hours & Task Trend',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (groups.isEmpty || !hasData)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28.0),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 44,
                      color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trend data available.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 190,
                child: BarChart(
                  BarChartData(
                    barGroups: groups,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < data.dailyTrends.length) {
                              final date = data.dailyTrends[idx].date;
                              final label = _selectedPeriodIndex == 0
                                  ? DateFormat('ha').format(date)
                                  : (_selectedPeriodIndex == 1
                                      ? DateFormat('E').format(date)
                                      : DateFormat('d').format(date));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
