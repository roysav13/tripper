import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Designed error state (M4.2): what happened + what to do, never a raw
/// exception on screen. Mirrors [EmptyState]'s layout so the two read as
/// the same family of "nothing to show you right now" screens.
///
/// Requires a bounded-height parent: internally this wraps its content in a
/// [ConstrainedBox] whose `minHeight` is computed from the incoming layout
/// constraints, so placing this inside an unbounded-height ancestor (e.g. a
/// [Column] without [Expanded], or an unconstrained scroll view) throws.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title,
    this.body,
    this.onRetry,
  });

  final String? title;
  final String? body;

  /// Null hides the retry button — not every error is retryable.
  final VoidCallback? onRetry;

  /// Wrapped in a min-height-constrained scroll view rather than a bare
  /// Center: this widget can render inside deliberately cramped parents
  /// (Trip Detail's tabs, squeezed under its fixed hero/tab-bar chrome) —
  /// centers exactly like a bare Center when there's room, scrolls instead
  /// of overflowing when there isn't. An "active trip with nothing logged
  /// yet" is every trip's actual starting state, not an edge case.
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
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
                  // status.error, not warning — this is a real failure, not
                  // an expiry-style heads-up (SPEC §4.2 color rules).
                  Icon(Icons.error_outline, size: 40, color: colors.error),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title ?? l10n.errorStateTitle,
                    style:
                        AppTextStyles.title.copyWith(color: colors.inkPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body ?? l10n.errorStateBody,
                    style:
                        AppTextStyles.body.copyWith(color: colors.inkSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: Text(l10n.errorStateRetry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
