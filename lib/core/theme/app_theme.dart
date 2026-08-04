import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color darkPurple = Color(0xFF2D103E);
  static const Color premiumGold = Color(0xFFD4AF37);
  static const Color creamBg = Color(0xFFFFFFFF); // Clean white for modern look
  static const Color textDark = Color(0xFF1E1E1E);

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: creamBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPurple,
        primary: darkPurple,
        secondary: premiumGold,
        surface: creamBg,
        onSurface: textDark,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.playfairDisplayTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(color: textDark, fontSize: 60),
        displayMedium: GoogleFonts.playfairDisplay(color: textDark, fontSize: 48),
        headlineLarge: GoogleFonts.playfairDisplay(color: textDark, fontSize: 36),
        headlineMedium: GoogleFonts.playfairDisplay(color: textDark, fontSize: 32),
        titleLarge: GoogleFonts.playfairDisplay(color: textDark, fontSize: 24, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.inter(color: textDark, fontSize: 18),
        bodyMedium: GoogleFonts.inter(color: textDark, fontSize: 16),
        bodySmall: GoogleFonts.inter(color: textDark, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creamBg,
        foregroundColor: textDark,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: GoogleFonts.playfairDisplay(color: textDark, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPurple,
          side: const BorderSide(color: darkPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    // Optionally create a dark version, but stick to light default for exact UI match
    return lightTheme;
  }
}
