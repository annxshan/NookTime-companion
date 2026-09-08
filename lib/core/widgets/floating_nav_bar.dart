import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String? photoUrl;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.photoUrl,
  });

  static final List<NavItemData> _items = [
    NavItemData(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Routine',
    ),
    NavItemData(
      icon: Icons.alarm_outlined,
      activeIcon: Icons.alarm_on_rounded,
      label: 'Reminder',
    ),
    NavItemData(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.insert_chart_rounded,
      label: 'Analytics',
    ),
    NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2430).withValues(alpha: 0.20)
                        : const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ── Sliding Circle / Pill Active Indicator ─────────────
                      AnimatedAlign(
                        alignment: Alignment(
                          -1.0 + (currentIndex / (_items.length - 1)) * 2.0,
                          0.0,
                        ),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.fastOutSlowIn,
                        child: FractionallySizedBox(
                          widthFactor: 1.0 / _items.length,
                          heightFactor: 1.0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Navigation Buttons ──────────────────────────────
                      Row(
                        children: List.generate(_items.length, (index) {
                          final isSelected = currentIndex == index;
                          final item = _items[index];
                          final isProfileTab = index == 3;
                          final hasPhoto = isProfileTab &&
                              photoUrl != null &&
                              photoUrl!.trim().isNotEmpty;

                          final activeColor = isDark ? Colors.white : const Color(0xFF0F172A);
                          final inactiveColor = isDark ? Colors.white54 : const Color(0xFF64748B);

                          return Expanded(
                            child: RepaintBoundary(
                              key: ValueKey('nav_item_$index'),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onTap(index);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: AnimatedScale(
                                    scale: isSelected ? 1.01 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasPhoto)
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? activeColor
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                              image: DecorationImage(
                                                image: NetworkImage(photoUrl!),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        else
                                          Icon(
                                            isSelected ? item.activeIcon : item.icon,
                                            size: 24,
                                            color: isSelected ? activeColor : inactiveColor,
                                          ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected ? activeColor : inactiveColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
