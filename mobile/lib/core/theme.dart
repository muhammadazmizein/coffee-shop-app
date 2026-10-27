import 'package:flutter/material.dart';

/// Warna merek: teal. Ubah di sini (dan di tool/illus.py untuk ilustrasi) bila merek berganti.
const brandColor = Color(0xFF0F766E);
const inkColor = Color(0xFF0B2E2B);
const surfaceColor = Color(0xFFF4FAF9);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandColor, brightness: Brightness.light).copyWith(primary: brandColor, surface: surfaceColor);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: surfaceColor,
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0, backgroundColor: surfaceColor, foregroundColor: inkColor),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCFE3E0))),
    ),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: const Color(0xFFCFF3EE), labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    chipTheme: ChipThemeData(selectedColor: const Color(0xFFCFF3EE), side: const BorderSide(color: Color(0xFFD5EBE8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFD5EBE8)))),
  );
}
