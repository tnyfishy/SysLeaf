import 'package:flutter/material.dart';

ThemeData buildTheme({bool dark = false, bool black = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff42694d),
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  final surface = black
      ? Colors.black
      : dark
      ? const Color(0xff111711)
      : const Color(0xfff8faf5);
  final colors = scheme.copyWith(
    surface: surface,
    primary: dark ? const Color(0xffa5d6a9) : const Color(0xff386344),
    onPrimary: dark ? const Color(0xff12371d) : Colors.white,
    surfaceContainerLow: black
        ? const Color(0xff0b0b0b)
        : dark
        ? const Color(0xff1a211a)
        : Colors.white,
    surfaceContainer: black
        ? const Color(0xff101010)
        : dark
        ? const Color(0xff202820)
        : const Color(0xffedf2e9),
  );
  return ThemeData(
    fontFamily: 'Manrope',
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: surface,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLow,
      indicatorColor: colors.primaryContainer,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: .5),
      space: 1,
    ),
    textTheme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
        .textTheme
        .apply(
          fontFamily: 'Manrope',
          bodyColor: colors.onSurface,
          displayColor: colors.onSurface,
        ),
  );
}
