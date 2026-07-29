import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final textTheme = TextTheme(
      displaySmall: AppTextStyles.display.copyWith(color: c.inkPrimary),
      titleLarge: AppTextStyles.title.copyWith(color: c.inkPrimary),
      bodyMedium: AppTextStyles.body.copyWith(color: c.inkPrimary),
      labelLarge: AppTextStyles.label.copyWith(color: c.inkPrimary),
      labelSmall: AppTextStyles.sectionLabel.copyWith(color: c.inkMuted),
      bodySmall: AppTextStyles.mono.copyWith(color: c.inkSecondary),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.surface,
      secondary: c.accent,
      onSecondary: c.surface,
      error: c.error,
      onError: c.surface,
      surface: c.paper,
      onSurface: c.inkPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.paper,
      fontFamily: AppFonts.sans,
      textTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.display.copyWith(color: c.inkPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: c.hairline.withValues(alpha: 0.6),
        dividerHeight: AppShape.hairlineWidth,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.radius),
          side: BorderSide(color: c.hairline, width: AppShape.hairlineWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: AppShape.hairlineWidth,
        space: AppShape.hairlineWidth,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color:
                states.contains(WidgetState.selected) ? c.accent : c.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.sectionLabel.copyWith(
            letterSpacing: 0,
            color:
                states.contains(WidgetState.selected) ? c.accent : c.inkMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.surface,
          textStyle: AppTextStyles.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.radius),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inkPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: c.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.radius),
        ),
      ),
    );
  }
}
