import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JalTheme {
  // Brand Palettes
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color slateNavy = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF0B132B);
  
  // Flash Flood Theme (Blue)
  static const Color floodBlue = Color(0xFF1D4ED8);
  static const Color floodBlueLight = Color(0xFFEFF6FF);
  static const Color floodBlueBorder = Color(0xFFBFDBFE);

  // Street Waterlogging Theme (Amber/Orange)
  static const Color waterlogOrange = Color(0xFFD97706);
  static const Color waterlogOrangeDark = Color(0xFFB45309);
  static const Color waterlogOrangeLight = Color(0xFFFFFBEB);
  static const Color waterlogOrangeBorder = Color(0xFFFDE68A);

  // Status & Danger
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerRedLight = Color(0xFFFEF2F2);
  static const Color dangerRedBorder = Color(0xFFFECACA);
  static const Color liveGreen = Color(0xFF10B981);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
