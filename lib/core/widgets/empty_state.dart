import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Designed empty state: invitation, not apology (SPEC copy rules).
///
/// Requires a bounded-height parent: internally this wraps its content in a
/// [ConstrainedBox] whose `minHeight` is computed from the incoming layout
/// constraints, so placing this inside an unbounded-height ancestor (e.g. a
/// [Column] without [Expanded], or an unconstrained scroll view) throws.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  /// Wrapped in a min-height-constrained scroll view rather than a bare
  /// Center: this widget can render inside deliberately cramped parents
  /// (Trip Detail's tabs, squeezed under its fixed hero/tab-bar chrome) —
  /// centers exactly like a bare Center when there's room, scrolls instead
  /// of overflowing when there isn't. An "active trip with nothing logged
  /// yet" is every trip's actual starting state, not an edge case.
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: colors.inkMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    style:
                        AppTextStyles.title.copyWith(color: colors.inkPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body,
                    style:
                        AppTextStyles.body.copyWith(color: colors.inkSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(onPressed: onCta, child: Text(ctaLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
