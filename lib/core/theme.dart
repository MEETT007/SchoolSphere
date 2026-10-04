import 'package:flutter/material.dart';

const ink = Color(0xFF173C3A);
const teal = Color(0xFF146B5D);
const mint = Color(0xFFDDEDE3);
const amber = Color(0xFFE8AF55);
const clay = Color(0xFFC87557);
const paper = Color(0xFFF7F8F2);

ThemeData schoolTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: teal,
    brightness: dark ? Brightness.dark : Brightness.light,
    surface: dark ? const Color(0xFF172A28) : Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    brightness: scheme.brightness,
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF10201F) : paper,
    textTheme: base.textTheme.apply(
      bodyColor: dark ? const Color(0xFFE7F0EA) : ink,
      displayColor: dark ? const Color(0xFFE7F0EA) : ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF10201F) : paper,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF2B4541) : const Color(0xFFE7EBE2),
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? mint : ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF203633) : const Color(0xFFF4F6EF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: dark ? teal : mint,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
