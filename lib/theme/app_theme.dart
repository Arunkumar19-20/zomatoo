import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFFFF8A3D);
  static const Color primaryDark = Color(0xFFE06E20);
  static const Color primaryLight = Color(0xFFFFB27A);
  
  static const Color accentColor = Color(0xFFFFD54F); // Golden Yellow
  static const Color scaffoldBackground = Color(0xFFFAFAFA);
  static const Color cardBackground = Colors.white;
  
  static const Color textDark = Color(0xFF1A1A1A); // Soft charcoal gray
  static const Color textLight = Color(0xFF757575);
  static const Color textLightest = Color(0xFF9E9E9E);
  
  static const Color dividerColor = Color(0xFFEAEAEA);
  static const Color disabledColor = Color(0xFFEAEAEA);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFF25C05), // Deep Orange
      Color(0xFFFFA000), // Golden Yellow
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [
      Color(0xFFFFA726), // Warm light orange
      Color(0xFFE65100), // Deep orange
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: cardBackground,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      
      // Typography
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displayMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displaySmall: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 26,
          color: textDark,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textDark,
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textDark,
        ),
        titleMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textDark,
        ),
        titleSmall: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textLight,
        ),
        bodySmall: GoogleFonts.poppins(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: textLightest,
        ),
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(), // Pill-shaped
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0, // Enforce flat look with custom soft shadow
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Page Transitions Theme
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
        },
      ),
      
      // Input Fields (TextFormField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.poppins(color: textLightest, fontSize: 14),
        prefixIconColor: textLight,
        suffixIconColor: textLight,
      ),
    );
  }
}

class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}
