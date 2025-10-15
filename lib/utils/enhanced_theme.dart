import 'package:flutter/material.dart';

/// Enhanced theme system with modern design tokens
class EnhancedTheme {
  // Modern color palettes
  static const Color _primaryIndigo = Color(0xFF6366F1);
  static const Color _primaryEmerald = Color(0xFF10B981);
  static const Color _primaryViolet = Color(0xFF8B5CF6);
  static const Color _primaryAmber = Color(0xFFF59E0B);
  static const Color _primaryRose = Color(0xFFF43F5E);
  
  static const Color _neutral50 = Color(0xFFFAFAFA);
  static const Color _neutral100 = Color(0xFFF5F5F5);
  static const Color _neutral200 = Color(0xFFE5E5E5);
  static const Color _neutral300 = Color(0xFFD4D4D4);
  static const Color _neutral400 = Color(0xFFA3A3A3);
  static const Color _neutral500 = Color(0xFF737373);
  static const Color _neutral600 = Color(0xFF525252);
  static const Color _neutral700 = Color(0xFF404040);
  static const Color _neutral800 = Color(0xFF262626);
  static const Color _neutral900 = Color(0xFF171717);
  static const Color _neutral950 = Color(0xFF0A0A0A);

  // Light theme with modern colors
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _primaryIndigo,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEEF2FF),
        onPrimaryContainer: Color(0xFF3730A3),
        secondary: _primaryViolet,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFF3E8FF),
        onSecondaryContainer: Color(0xFF581C87),
        tertiary: _primaryEmerald,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFD1FAE5),
        onTertiaryContainer: Color(0xFF065F46),
        error: _primaryRose,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: Colors.white,
        onSurface: _neutral900,
        surfaceVariant: _neutral100,
        onSurfaceVariant: _neutral700,
        outline: _neutral300,
        outlineVariant: _neutral200,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: _neutral900,
        onInverseSurface: _neutral50,
        inversePrimary: Color(0xFFA5B4FC),
        surfaceTint: _primaryIndigo,
      ),
      textTheme: _modernTextTheme,
      iconTheme: _iconTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      chipTheme: _chipTheme,
      snackBarTheme: _snackBarTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      floatingActionButtonTheme: _floatingActionButtonTheme,
      navigationBarTheme: _navigationBarTheme,
      tabBarTheme: _tabBarTheme,
      dividerTheme: _dividerTheme,
      listTileTheme: _listTileTheme,
    );
  }

  // Dark theme with modern colors
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFA5B4FC),
        onPrimary: _neutral950,
        primaryContainer: Color(0xFF3730A3),
        onPrimaryContainer: Color(0xFFEEF2FF),
        secondary: Color(0xFFC4B5FD),
        onSecondary: _neutral950,
        secondaryContainer: Color(0xFF581C87),
        onSecondaryContainer: Color(0xFFF3E8FF),
        tertiary: Color(0xFF6EE7B7),
        onTertiary: _neutral950,
        tertiaryContainer: Color(0xFF065F46),
        onTertiaryContainer: Color(0xFFD1FAE5),
        error: Color(0xFFFCA5A5),
        onError: _neutral950,
        errorContainer: Color(0xFF991B1B),
        onErrorContainer: Color(0xFFFEE2E2),
        surface: _neutral900,
        onSurface: _neutral50,
        surfaceVariant: _neutral800,
        onSurfaceVariant: _neutral300,
        outline: _neutral600,
        outlineVariant: _neutral700,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: _neutral50,
        onInverseSurface: _neutral900,
        inversePrimary: _primaryIndigo,
        surfaceTint: Color(0xFFA5B4FC),
      ),
      textTheme: _modernTextTheme,
      iconTheme: _iconTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      chipTheme: _chipTheme,
      snackBarTheme: _snackBarTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      floatingActionButtonTheme: _floatingActionButtonTheme,
      navigationBarTheme: _navigationBarTheme,
      tabBarTheme: _tabBarTheme,
      dividerTheme: _dividerTheme,
      listTileTheme: _listTileTheme,
    );
  }

  // Modern typography with better font weights and spacing
  static const TextTheme _modernTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.22,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.05,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.33,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    bodyLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.33,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.45,
    ),
  );

  // Icon theme
  static const IconThemeData _iconTheme = IconThemeData(
    size: 24,
  );

  // App bar theme
  static AppBarTheme get _appBarTheme => const AppBarTheme(
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      height: 1.27,
    ),
  );

  // Card theme
  static CardThemeData get _cardTheme => CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    margin: const EdgeInsets.all(8),
    shadowColor: Colors.black.withOpacity(0.08),
  );

  // Elevated button theme
  static ElevatedButtonThemeData get _elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );

  // Outlined button theme
  static OutlinedButtonThemeData get _outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );

  // Text button theme
  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );

  // Input decoration theme
  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    labelStyle: const TextStyle(
      fontWeight: FontWeight.w500,
    ),
  );

  // Chip theme
  static ChipThemeData get _chipTheme => ChipThemeData(
    backgroundColor: Colors.transparent,
    selectedColor: _primaryIndigo.withOpacity(0.1),
    disabledColor: _neutral200,
    labelStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    side: BorderSide.none,
  );

  // Snack bar theme
  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    contentTextStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  // Bottom sheet theme
  static BottomSheetThemeData get _bottomSheetTheme => BottomSheetThemeData(
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
  );

  // Dialog theme
  static DialogThemeData get _dialogTheme => DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
    ),
    contentTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
  );

  // Floating action button theme
  static FloatingActionButtonThemeData get _floatingActionButtonTheme => FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    elevation: 8,
  );

  // Navigation bar theme
  static NavigationBarThemeData get _navigationBarTheme => NavigationBarThemeData(
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    height: 80,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  // Tab bar theme
  static TabBarThemeData get _tabBarTheme => TabBarThemeData(
    labelStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    unselectedLabelStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: Colors.transparent,
  );

  // Divider theme
  static DividerThemeData get _dividerTheme => const DividerThemeData(
    thickness: 1,
    space: 1,
  );

  // List tile theme
  static ListTileThemeData get _listTileTheme => ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    titleTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    ),
    subtitleTextStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
  );

  // Helper methods for getting semantic colors
  static Color getTaskStatusColor(String status, BuildContext context) {
    final theme = Theme.of(context);
    switch (status.toLowerCase()) {
      case 'unclaimed':
        return theme.colorScheme.primary;
      case 'claimed':
        return theme.colorScheme.secondary;
      case 'done':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.primary;
    }
  }

  static Color getPriorityColor(bool isUrgent) {
    return isUrgent ? _primaryRose : _neutral500;
  }

  static Color getHandoffStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'proposed':
        return _primaryAmber;
      case 'accepted':
        return _primaryEmerald;
      case 'declined':
        return _primaryRose;
      default:
        return _neutral500;
    }
  }

  // Animation curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve fastCurve = Curves.easeOutQuart;
  static const Curve slowCurve = Curves.easeInOutCubic;

  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration verySlowDuration = Duration(milliseconds: 800);

  // Spacing constants
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing56 = 56;
  static const double spacing64 = 64;

  // Border radius constants
  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;
  static const double radius32 = 32;

  // Shadow constants
  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
