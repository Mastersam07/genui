import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors are named by role. Palm-oil red is the only accent: use it
/// for the one action that matters on a screen, never for decoration.
abstract final class KitchenColors {
  static const background = Color(0xFFFBF6EE); // garri cream
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B1D14);
  static const inkMuted = Color(0xFF7A6658);
  static const border = Color(0xFFEADFD0);
  static const accent = Color(0xFFC2410C); // palm oil
  static const accentSoft = Color(0xFFFCE9DD);
  static const done = Color(0xFF2F6B3A); // ewedu green
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
    colorScheme: ColorScheme.fromSeed(
      seedColor: KitchenColors.accent,
      primary: KitchenColors.accent,
      surface: KitchenColors.background,
      onSurface: KitchenColors.ink,
    ),
  );

  final body = GoogleFonts.dmSansTextTheme(
    base.textTheme,
  ).apply(bodyColor: KitchenColors.ink, displayColor: KitchenColors.ink);

  final textTheme = body.copyWith(
    headlineSmall: GoogleFonts.fraunces(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: KitchenColors.ink,
    ),
    titleLarge: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: KitchenColors.ink),
    labelSmall: body.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(KitchenRadius.control));

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(KitchenRadius.control),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    scaffoldBackgroundColor: KitchenColors.background,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: KitchenColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KitchenRadius.card),
        side: const BorderSide(color: KitchenColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KitchenColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: controlShape,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: KitchenColors.accent,
        foregroundColor: Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: KitchenSpace.lg, vertical: KitchenSpace.md),
      border: inputBorder(KitchenColors.border),
      enabledBorder: inputBorder(KitchenColors.border),
      focusedBorder: inputBorder(KitchenColors.accent, 1.5),
      hintStyle: textTheme.bodyLarge?.copyWith(color: KitchenColors.inkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KitchenColors.surface,
      side: const BorderSide(color: KitchenColors.border),
      shape: controlShape,
      labelStyle: textTheme.bodyMedium?.copyWith(height: 1.3),
      padding: const EdgeInsets.symmetric(horizontal: KitchenSpace.md, vertical: KitchenSpace.sm),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: KitchenColors.accent,
      thumbColor: KitchenColors.accent,
      inactiveTrackColor: KitchenColors.border,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? KitchenColors.done : null,
      ),
    ),
    dividerTheme: const DividerThemeData(color: KitchenColors.border),
  );
}
