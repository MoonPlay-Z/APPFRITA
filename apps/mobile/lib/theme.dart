import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFFAD2C00);
  static const primaryContainer = Color(0xFFD83900);
  static const secondary = Color(0xFFFFB703);
  static const tertiary = Color(0xFF2A9D8F);
  static const surface = Color(0xFFFCF9F8);
  static const onSurface = Color(0xFF1C1B1B);
  static const muted = Color(0xFF5D4038);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, surface: surface),
        scaffoldBackgroundColor: surface,
        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          headlineSmall: GoogleFonts.epilogue(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: onSurface),
          titleLarge: GoogleFonts.epilogue(fontWeight: FontWeight.w700, color: onSurface),
          titleMedium: GoogleFonts.epilogue(fontWeight: FontWeight.w700, color: onSurface),
        ),
        appBarTheme: AppBarTheme(backgroundColor: surface, foregroundColor: onSurface, elevation: 0),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: const StadiumBorder())),
      );
}
