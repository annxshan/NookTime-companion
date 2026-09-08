import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../daily_routine/domain/models/routine_task.dart';

/// Header card for the Reminders screen that physically morphs into a compact deletion bar when
/// selection mode activates — driven by an [AnimationController] that
/// collapses height, cross-fades content, animates gradient colours, and interpolates padding.
class ReminderHeaderCard extends StatefulWidget {
  static final DateFormat _dayOfWeekFormatter = DateFormat('EEEE');
  static final DateFormat _monthDayFormatter = DateFormat('MMMM d');

  final int total;
  final int upcomingCount;
  final int completedCount;
  final double completionProgress;
  final bool isSelectionMode;
  final int selectedCount;
  final int totalVisibleCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onCancelSelection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onEditSelected;
  final ValueChanged<RoutineTask>? onTaskDroppedToDelete;

  const ReminderHeaderCard({
    super.key,
    required this.total,
    required this.upcomingCount,
    required this.completedCount,
    required this.completionProgress,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalVisibleCount = 0,
    this.onSelectAll,
    this.onCancelSelection,
    this.onDeleteSelected,
    this.onEditSelected,
    this.onTaskDroppedToDelete,
  });

  @override
  State<ReminderHeaderCard> createState() => _ReminderHeaderCardState();
}

class _ReminderHeaderCardState extends State<ReminderHeaderCard>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  late Animation<double> _headerSize;
  late Animation<double> _headerFade;
  late Animation<double> _headerScale;

  late Animation<double> _barSize;
  late Animation<double> _barFade;
  late Animation<double> _barScale;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _setupTweens();
  }

  void _setupTweens() {
    const headerOut = Interval(0.0, 0.55, curve: Curves.easeInCubic);
    _headerSize = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: headerOut));
    _headerFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: headerOut));
    _headerScale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: headerOut));

    const barIn = Interval(0.45, 1.0, curve: Curves.easeOutCubic);
    const barInBack = Interval(0.45, 1.0, curve: Curves.easeOutBack);
    _barSize = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: barIn));
    _barFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: barIn));
    _barScale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: barInBack));

    _ctrl.value = widget.isSelectionMode ? 1.0 : 0.0;
    _initialized = true;
  }

  @override
  void didUpdateWidget(ReminderHeaderCard old) {
    super.didUpdateWidget(old);
    if (!_initialized) return;
    if (widget.isSelectionMode == old.isSelectionMode) return;
    if (widget.isSelectionMode) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_initialized) {
      _setupTweens();
    } else {
      _initAnimations();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primary = ThemeController.instance.seedColor;
        final now = DateTime.now();

        return DragTarget<RoutineTask>(
          onWillAcceptWithDetails: (_) {
            HapticFeedback.selectionClick();
            return true;
          },
          onAcceptWithDetails: (details) {
            HapticFeedback.mediumImpact();
            widget.onTaskDroppedToDelete?.call(details.data);
          },
          builder: (ctx, candidateData, _) {
            final isHovering = candidateData.isNotEmpty;

            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context2, child) {
                final t = _ctrl.value;

                final Color cardTop = isDark
                    ? Color.alphaBlend(
                        primary.withValues(alpha: 0.45),
                        const Color(0xFF0F141C))
                    : primary;
                final Color cardBot = isDark
                    ? const Color(0xFF151C28)
                    : Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.22), primary);

                final Color barTop =
                    isDark ? const Color(0xFF1C2333) : Colors.white;
                final Color barBot = isDark
                    ? const Color(0xFF151C28)
                    : const Color(0xFFF8F9FA);

                final gradientColors = isHovering
                    ? <Color>[const Color(0xFFFF2A3B), const Color(0xFFD63031)]
                    : <Color>[
                        Color.lerp(cardTop, barTop, t)!,
                        Color.lerp(cardBot, barBot, t)!,
                      ];

                final borderColor = isHovering
                    ? const Color(0xFFFF4757)
                    : Color.lerp(
                        isDark
                            ? primary.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.35),
                        isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.black.withValues(alpha: 0.12),
                        t,
                      )!;

                final shadowColor = isHovering
                    ? const Color(0xFFFF4757).withValues(alpha: 0.55)
                    : Color.lerp(
                        isDark
                            ? primary.withValues(alpha: 0.28)
                            : primary.withValues(alpha: 0.38),
                        Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                        t,
                      )!;

                final currentPadding = EdgeInsets.lerp(
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  t,
                )!;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: currentPadding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: borderColor,
                      width: isHovering ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: isHovering ? 24 : 18,
                        spreadRadius: isHovering ? 1 : -1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: isHovering
                      ? _buildDragHoverContent(candidateData.first)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (t < 0.98)
                              ClipRect(
                                child: SizeTransition(
                                  sizeFactor: _headerSize,
                                  axisAlignment: -1.0,
                                  child: FadeTransition(
                                    opacity: _headerFade,
                                    child: ScaleTransition(
                                      scale: _headerScale,
                                      alignment: Alignment.topCenter,
                                      child: _buildCardContent(
                                        context, isDark, primary, now, theme,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (t > 0.02)
                              ClipRect(
                                child: SizeTransition(
                                  sizeFactor: _barSize,
                                  axisAlignment: -1.0,
                                  child: FadeTransition(
                                    opacity: _barFade,
                                    child: ScaleTransition(
                                      scale: _barScale,
                                      alignment: Alignment.center,
                                      child: _buildDeletionBar(
                                        context, isDark, primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    bool isDark,
    Color primary,
    DateTime now,
    ThemeData theme,
  ) {
    final progress = widget.completionProgress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ReminderHeaderCard._dayOfWeekFormatter.format(now).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark
                          ? primary
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Scheduled Reminders",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ReminderHeaderCard._monthDayFormatter.format(now),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? primary.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.total} Scheduled • ${widget.upcomingCount} Upcoming',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? primary : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressRing(context, progress, primary),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context3, v, child2) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(Colors.white, primary, v)!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeletionBar(
    BuildContext context,
    bool isDark,
    Color primary,
  ) {
    final count = widget.selectedCount;
    final total = widget.totalVisibleCount;
    final allSelected = total > 0 && count >= total;
    final hasAny = count > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Group: Cancel and Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cancel
                      _BarButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onCancelSelection?.call();
                        },
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        color: isDark ? Colors.white70 : Colors.black54,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),

                      // Count badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primary.withValues(alpha: isDark ? 0.45 : 0.30),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: Tween<double>(begin: 0.80, end: 1.0).animate(
                              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                            ),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Text(
                            count == 0 ? 'None' : '$count selected',
                            key: ValueKey<int>(count),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Right Group: Edit (Slot), Select All, Delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit slot (keeps its space even when invisible so right buttons never move)
                      AnimatedOpacity(
                        opacity: count == 1 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: count != 1,
                          child: _BarButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onEditSelected?.call();
                            },
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            color: primary,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Select All / Deselect
                      _BarButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelectAll?.call();
                        },
                        icon: allSelected
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        label: allSelected ? 'Deselect' : 'All',
                        color: primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 4),

                      // Delete
                      _BarButton(
                        onTap: hasAny
                            ? () {
                                HapticFeedback.mediumImpact();
                                widget.onDeleteSelected?.call();
                              }
                            : null,
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        color: hasAny ? const Color(0xFFFF4757) : Colors.grey,
                        isDark: isDark,
                        isDestructive: hasAny,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHoverContent(RoutineTask? task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.delete_forever_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          const Text(
            'RELEASE TO DELETE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          if (task != null) ...[
            const SizedBox(height: 2),
            Text(
              '"${task.title}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressRing(
    BuildContext context,
    double progress,
    Color primary,
  ) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context4, v, child3) => CircularProgressIndicator(
              value: v,
              strokeWidth: 4.5,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(Colors.white, primary, v)!,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isDestructive;

  const _BarButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final effectiveColor = disabled ? Colors.grey.withValues(alpha: 0.45) : color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: effectiveColor.withValues(alpha: 0.25),
        highlightColor: effectiveColor.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDestructive && !disabled
                ? const Color(0xFFFF4757)
                    .withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDestructive && !disabled
                  ? const Color(0xFFFF4757).withValues(alpha: 0.38)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey<String>('${icon.codePoint}-$disabled'),
                  size: 20,
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: effectiveColor,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
