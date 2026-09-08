import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_controller.dart';

enum TaskStatusFilter { all, upcoming, completed, expired }

/// Horizontal 7-Day Weekday Selector strip (Mon..Sun).
class WeekdaySelector extends StatelessWidget {
  final int selectedWeekday; // 1 = Mon, ..., 7 = Sun
  final ValueChanged<int> onWeekdaySelected;

  const WeekdaySelector({
    super.key,
    required this.selectedWeekday,
    required this.onWeekdaySelected,
  });

  static const List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = ThemeController.instance.seedColor;

        return Container(
          height: 54,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final weekday = index + 1; // 1..7
              final isSelected = weekday == selectedWeekday;
              final todayWeekday = DateTime.now().weekday;
              final isToday = weekday == todayWeekday;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onWeekdaySelected(weekday);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? primaryColor
                            : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayNames[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? (isSelected ? const Color(0xFF00D2D3) : Colors.orangeAccent)
                                : (isSelected ? Colors.white.withValues(alpha: 0.7) : Colors.transparent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Horizontal scrollable filter bar with Status filters (Upcoming | Completed),
/// vertical divider, and Category filters (Work, Study, Health, Personal).
class RoutineFilterBar extends StatelessWidget {
  final TaskStatusFilter selectedStatus;
  final ValueChanged<TaskStatusFilter> onStatusChanged;
  final String selectedCategory; // 'All', 'Work', 'Study', 'Health', 'Personal'
  final ValueChanged<String> onCategoryChanged;

  const RoutineFilterBar({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // ── Status Filters Group ──────────────────────────────────────────
          _buildFilterPill(
            context: context,
            label: 'Upcoming',
            icon: Icons.access_time_rounded,
            isSelected: selectedStatus == TaskStatusFilter.upcoming,
            onTap: () => onStatusChanged(
              selectedStatus == TaskStatusFilter.upcoming
                  ? TaskStatusFilter.all
                  : TaskStatusFilter.upcoming,
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Completed',
            icon: Icons.check_circle_outline_rounded,
            isSelected: selectedStatus == TaskStatusFilter.completed,
            onTap: () => onStatusChanged(
              selectedStatus == TaskStatusFilter.completed
                  ? TaskStatusFilter.all
                  : TaskStatusFilter.completed,
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterPill(
            context: context,
            label: 'Expired',
            icon: Icons.block_rounded,
            isSelected: selectedStatus == TaskStatusFilter.expired,
            customAccentColor: const Color(0xFFEF4444),
            onTap: () => onStatusChanged(
              selectedStatus == TaskStatusFilter.expired
                  ? TaskStatusFilter.all
                  : TaskStatusFilter.expired,
            ),
          ),

          // ── Sleek Vertical Divider ────────────────────────────────────────
          Container(
            height: 24,
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
          ),

          // ── Category Filters Group ────────────────────────────────────────
          _buildCategoryPill(
            context: context,
            label: 'All',
            icon: Icons.grid_view_rounded,
            categoryKey: 'All',
          ),
          const SizedBox(width: 8),
          _buildCategoryPill(
            context: context,
            label: 'Work',
            icon: Icons.work_outline_rounded,
            categoryKey: 'Work',
          ),
          const SizedBox(width: 8),
          _buildCategoryPill(
            context: context,
            label: 'Study',
            icon: Icons.menu_book_rounded,
            categoryKey: 'Study',
          ),
          const SizedBox(width: 8),
          _buildCategoryPill(
            context: context,
            label: 'Health',
            icon: Icons.favorite_border_rounded,
            categoryKey: 'Health',
          ),
          const SizedBox(width: 8),
          _buildCategoryPill(
            context: context,
            label: 'Personal',
            icon: Icons.person_outline_rounded,
            categoryKey: 'Personal',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? customAccentColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = customAccentColor ?? ThemeController.instance.seedColor;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withAlpha(40)
              : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade300),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withAlpha(60),
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
              color: isSelected
                  ? accentColor
                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? const Color(0xFFE2E8F0) : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String categoryKey,
  }) {
    final isSelected = selectedCategory.toLowerCase() == categoryKey.toLowerCase();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = ThemeController.instance.seedColor;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onCategoryChanged(categoryKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withAlpha(40)
              : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade300),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? accentColor
                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? const Color(0xFFE2E8F0) : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
