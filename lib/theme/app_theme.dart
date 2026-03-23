import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===== Palette theo phong cách Apple Store =====
  static const Color brandBlue   = Color(0xFF0A84FF); // iOS systemBlue
  static const Color textPrimary = Color(0xFF0F172A); // gần-black cho text
  static const Color textMuted   = Color(0xFF6B7280); // slate-500
  static const Color borderLight = Color(0xFFE6E8EC);
  static const Color bgSoft      = Color(0xFFF5F5F7); // nền xám nhạt
  static const Color cardWhite   = Colors.white;
  static const Color gold        = Color(0xFFD4AF37);

  // ===== LIGHT =====
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlue,
        brightness: Brightness.light,
        primary: brandBlue,
        surface: cardWhite,
        background: bgSoft, // ít dùng trong M3, nhưng giữ cho đồng bộ
      ),
      scaffoldBackgroundColor: bgSoft,
    );

    // ⚠️ GoogleFonts: nếu bạn đã set `GoogleFonts.config.allowRuntimeFetching = false`
    // thì cần add các file .ttf tương ứng vào pubspec assets, nếu không sẽ lỗi.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.merriweather(
          fontSize: 36, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.merriweather(
          fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: GoogleFonts.merriweather(
          fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: textPrimary),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: textMuted),
    );

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.merriweather(
            fontSize: 20, fontWeight: FontWeight.w700, color: brandBlue),
        iconTheme: const IconThemeData(color: Colors.black87),
        actionsIconTheme: const IconThemeData(color: Colors.black87),
      ),

      // ✅ Dùng CardTheme (KHÔNG phải CardThemeData)
      // LIGHT
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          side: const BorderSide(color: borderLight),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: textPrimary),
        hintStyle: const TextStyle(color: Color(0xFF7A7F87)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFEEEEF0),
        selectedColor: brandBlue,
        labelStyle: TextStyle(color: Colors.black87),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: StadiumBorder(),
        side: BorderSide(color: borderLight),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brandBlue,
        unselectedItemColor: Color(0xFF8E8E93),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dividerColor: borderLight,
      splashColor: Colors.black12,
      highlightColor: Colors.black12,
    );
  }

  // ===== DARK =====
  static ThemeData get dark {
    const darkBg   = Color(0xFF000000); // iOS grouped dark
    const darkSurf = Color(0xFF1C1C1E); // card/background elevated
    const borderDark = Color(0xFF2C2C2E);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlue,
        brightness: Brightness.dark,
        primary: brandBlue,
        surface: darkSurf,
        background: darkBg,
      ),
      scaffoldBackgroundColor: darkBg,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.merriweather(
          fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
      titleLarge: GoogleFonts.merriweather(
          fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
      titleMedium: GoogleFonts.merriweather(
          fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: Colors.white),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: Colors.white),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: Colors.white70),
    );

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: darkSurf,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.merriweather(
            fontSize: 20, fontWeight: FontWeight.w700, color: brandBlue),
        iconTheme: const IconThemeData(color: Colors.white70),
        actionsIconTheme: const IconThemeData(color: Colors.white70),
      ),

      // DARK
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),                 // darkSurf
        elevation: 0,                                   // Dark không đổ bóng
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2C2E)), // viền mảnh thay shadow
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Color(0x3DFFFFFF)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x3DFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF2C2C2E),
        selectedColor: brandBlue,
        labelStyle: TextStyle(color: Color(0xFFEBEBF5)),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: StadiumBorder(),
        side: BorderSide(color: Color(0x332C2C2E)),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        selectedItemColor: brandBlue,
        unselectedItemColor: Color(0xFF8E8E93),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dividerColor: const Color(0x332C2C2E),
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
    );
  }

  // (Tuỳ chọn) Gradient mượt cho header Auth/Drawer
  static const LinearGradient authGradient = LinearGradient(
    colors: [Color(0xFF2D2F33), Color(0xFF4B4F56)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Expose một số màu dùng ngoài
  static const Color ivory = Color(0xFFF5F2EA);
  static const Color brand = brandBlue;
  static const Color accentGold = gold;
}
