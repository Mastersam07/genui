import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class DevFestPalette {
  static const googleBlue = Color(0xFF4285F4);
  static const googleRed = Color(0xFFEA4335);
  static const googleYellow = Color(0xFFFBBC04);
  static const googleGreen = Color(0xFF34A853);
  static const halftoneBlue = Color(0xFF57CAFF);
  static const halftoneYellow = Color(0xFFFFD427);
  static const halftoneRed = Color(0xFFFF7DAF);
  static const halftoneGreen = Color(0xFF5CDB6D);
  static const pastelBlue = Color(0xFFC3ECF6);
  static const pastelYellow = Color(0xFFFFE7A5);
  static const pastelRed = Color(0xFFF8D8D8);
  static const pastelGreen = Color(0xFFCCF6C5);
  static const offWhite = Color(0xFFF0F0F0);
  static const black02 = Color(0xFF1E1E1E);
}

abstract final class KitchenColors {
  static const background = DevFestPalette.offWhite;
  static const surface = DevFestPalette.offWhite;
  static const ink = DevFestPalette.black02;
  static const inkMuted = DevFestPalette.black02; // the palette has no grey: use weight and size
  static const border = DevFestPalette.black02;
  static const accent = DevFestPalette.googleBlue;
  static const accentSoft = DevFestPalette.pastelBlue;
  static const action = DevFestPalette.black02;
  static const onAction = DevFestPalette.offWhite;
  static const brand = DevFestPalette.googleYellow;
  static const tag = DevFestPalette.pastelYellow;
  static const spice = DevFestPalette.googleRed;
  static const spiceOff = DevFestPalette.pastelRed;
  static const done = DevFestPalette.googleGreen;
  static const error = DevFestPalette.googleRed;
}

abstract final class KitchenSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class KitchenRadius {
  static const card = 16.0;
  static const control = 12.0;
}

abstract final class KitchenMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildKitchenTheme() {
  final base = ThemeData(
    useMaterial3: true,
    // Spelled out instead of fromSeed, so Material never invents a tint
    // outside the palette.
    colorScheme: const ColorScheme.light(
      primary: KitchenColors.accent,
      onPrimary: DevFestPalette.black02,
      primaryContainer: DevFestPalette.pastelBlue,
      onPrimaryContainer: DevFestPalette.black02,
      secondary: DevFestPalette.googleGreen,
      onSecondary: DevFestPalette.black02,
      secondaryContainer: DevFestPalette.pastelGreen,
      onSecondaryContainer: DevFestPalette.black02,
      tertiary: DevFestPalette.googleYellow,
      onTertiary: DevFestPalette.black02,
      tertiaryContainer: DevFestPalette.pastelYellow,
      onTertiaryContainer: DevFestPalette.black02,
      error: KitchenColors.error,
      onError: DevFestPalette.black02,
      errorContainer: DevFestPalette.pastelRed,
      onErrorContainer: DevFestPalette.black02,
      surface: KitchenColors.background,
      onSurface: KitchenColors.ink,
      onSurfaceVariant: KitchenColors.ink,
      surfaceContainerLowest: DevFestPalette.offWhite,
      surfaceContainerLow: DevFestPalette.offWhite,
      surfaceContainer: DevFestPalette.offWhite,
      surfaceContainerHigh: DevFestPalette.pastelBlue,
      surfaceContainerHighest: DevFestPalette.pastelBlue,
      outline: KitchenColors.border,
      outlineVariant: KitchenColors.border,
      inverseSurface: DevFestPalette.black02,
      onInverseSurface: DevFestPalette.offWhite,
      surfaceTint: DevFestPalette.offWhite,
    ),
  );

  final body = GoogleFonts.dmSansTextTheme(
    base.textTheme,
  ).apply(bodyColor: KitchenColors.ink, displayColor: KitchenColors.ink);

  final textTheme = body.copyWith(
    headlineSmall: GoogleFonts.fraunces(fontSize: 26, fontWeight: .w600, height: 1.15, color: KitchenColors.ink),
    titleLarge: GoogleFonts.fraunces(fontSize: 20, fontWeight: .w600, color: KitchenColors.ink),
    labelSmall: body.labelSmall?.copyWith(fontWeight: .w700, letterSpacing: 1.1),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: .circular(KitchenRadius.control));

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: .circular(KitchenRadius.control),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    scaffoldBackgroundColor: KitchenColors.background,
    // Hover, press and focus feedback in a palette color, not Material's grey.
    hoverColor: DevFestPalette.pastelBlue,
    highlightColor: DevFestPalette.pastelBlue,
    splashColor: DevFestPalette.pastelBlue,
    focusColor: DevFestPalette.pastelBlue,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: KitchenColors.surface,
      margin: .zero,
      shape: RoundedRectangleBorder(
        borderRadius: .circular(KitchenRadius.card),
        side: const BorderSide(color: KitchenColors.border, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KitchenColors.action,
        foregroundColor: KitchenColors.onAction,
        minimumSize: const Size(48, 48),
        shape: controlShape,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: .w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: KitchenColors.action,
        foregroundColor: KitchenColors.onAction,
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KitchenColors.ink,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: KitchenColors.border),
        shape: controlShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KitchenColors.surface,
      contentPadding: const .symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
      border: inputBorder(KitchenColors.border),
      enabledBorder: inputBorder(KitchenColors.border),
      focusedBorder: inputBorder(KitchenColors.accent, 2),
      hintStyle: textTheme.bodyLarge?.copyWith(color: KitchenColors.inkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: DevFestPalette.pastelBlue,
      side: const BorderSide(color: KitchenColors.border),
      shape: controlShape,
      labelStyle: textTheme.bodyMedium?.copyWith(height: 1.3),
      padding: const .symmetric(horizontal: KitchenSpace.md, vertical: KitchenSpace.sm),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: KitchenColors.accent,
      thumbColor: KitchenColors.accent,
      inactiveTrackColor: DevFestPalette.pastelBlue,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: .resolveWith((states) => states.contains(WidgetState.selected) ? KitchenColors.done : null),
    ),
    dividerTheme: const DividerThemeData(color: KitchenColors.border),
  );
}
