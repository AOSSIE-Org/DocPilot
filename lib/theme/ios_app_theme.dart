import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Ios-style theme configuration with perfect responsive design
class IosAppTheme {
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color secondaryBlue = Color(0xFF5AC8FA);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemYellow = Color(0xFFFFCC00);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);

  // Ios background colors
  static const Color systemBackground = Color(0xFFFFFFFF);
  static const Color secondarySystemBackground = Color(0xFFF2F2F7);
  static const Color tertiarySystemBackground = Color(0xFFFFFFFF);
  static const Color systemGroupedBackground = Color(0xFFF2F2F7);
  static const Color secondarySystemGroupedBackground = Color(0xFFFFFFFF);
  static const Color tertiarySystemGroupedBackground = Color(0xFFF2F2F7);

  // Dark mode colors
  static const Color darkSystemBackground = Color(0xFF000000);
  static const Color darkSecondarySystemBackground = Color(0xFF1C1C1E);
  static const Color darkTertiarySystemBackground = Color(0xFF2C2C2E);

  /// Light theme with Ios design system
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(primaryBlue),
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: systemGroupedBackground,
      cardColor: secondarySystemGroupedBackground,
      dividerColor: systemGray4,

      // AppBar theme with Ios navigation bar style
      appBarTheme: AppBarTheme(
        backgroundColor: systemBackground,
        foregroundColor: CupertinoColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.black,
        ),
        toolbarHeight: 44.h,
      ),

      // Card theme with Ios style
      cardTheme: CardThemeData(
        color: secondarySystemGroupedBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        minVerticalPadding: 8.h,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          textStyle: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          textStyle: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tertiarySystemBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: systemGray4, width: 1.w),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: systemGray4, width: 1.w),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: primaryBlue, width: 2.w),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: systemRed, width: 1.w),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: systemRed, width: 2.w),
        ),
      ),

      // Text theme with Ios typography
      textTheme: TextTheme(
        // Ios Large Title
        displayLarge: TextStyle(
          fontSize: 34.sp,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.black,
          height: 1.2,
        ),
        // Ios Title 1
        displayMedium: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.w400,
          color: CupertinoColors.black,
          height: 1.2,
        ),
        // Ios Title 2
        displaySmall: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.black,
          height: 1.2,
        ),
        // Ios Title 3
        headlineMedium: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.black,
          height: 1.2,
        ),
        // Ios Headline
        headlineSmall: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.black,
          height: 1.3,
        ),
        // Ios Body
        bodyLarge: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w400,
          color: CupertinoColors.black,
          height: 1.3,
        ),
        // Ios Callout
        bodyMedium: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: CupertinoColors.black,
          height: 1.3,
        ),
        // Ios Subhead
        bodySmall: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w400,
          color: systemGray,
          height: 1.3,
        ),
        // Ios Footnote
        labelLarge: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w400,
          color: systemGray,
          height: 1.3,
        ),
        // Ios Caption 1
        labelMedium: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: systemGray,
          height: 1.3,
        ),
        // Ios Caption 2
        labelSmall: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w400,
          color: systemGray,
          height: 1.3,
        ),
      ),

      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: secondaryBlue,
        surface: systemBackground,
        surfaceContainerHighest: systemGroupedBackground,
        error: systemRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: CupertinoColors.black,
        onError: Colors.white,
      ),
    );
  }

  /// Dark theme with Ios design system
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: _createMaterialColor(primaryBlue),
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: darkSystemBackground,
      cardColor: darkSecondarySystemBackground,
      dividerColor: Color(0xFF38383A),

      appBarTheme: AppBarTheme(
        backgroundColor: darkSystemBackground,
        foregroundColor: CupertinoColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: darkSecondarySystemBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      ),

      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: secondaryBlue,
        surface: darkSecondarySystemBackground,
        surfaceContainerHighest: darkSystemBackground,
        error: systemRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: CupertinoColors.white,
        onError: Colors.white,
      ),
    );
  }

  /// Create MaterialColor from Color
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    final Map<int, Color> swatch = {};

    // Extract RGB values using modern approach
    final argb = color.value;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.value, swatch);
  }
}

/// Responsive design utilities
class ResponsiveHelper {
  static bool isPhone(BuildContext context) => ScreenUtil().screenWidth < 768;
  static bool isTablet(BuildContext context) => ScreenUtil().screenWidth >= 768 && ScreenUtil().screenWidth < 1024;
  static bool isDesktop(BuildContext context) => ScreenUtil().screenWidth >= 1024;

  static double getResponsiveFontSize(double size) => size.sp;
  static double getResponsiveWidth(double width) => width.w;
  static double getResponsiveHeight(double height) => height.h;
  static double getResponsiveRadius(double radius) => radius.r;

  /// Safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Standard Ios spacing values
  static const double tinySpacing = 4;
  static const double smallSpacing = 8;
  static const double mediumSpacing = 16;
  static const double largeSpacing = 24;
  static const double extraLargeSpacing = 32;

  /// Get responsive spacing
  static double spacing(double value) => value.h;
}

/// Ios-style constants
class IosDesignConstants {
  // Navigation bar height
  static double get navigationBarHeight => 44.h;

  // Tab bar height
  static double get tabBarHeight => 49.h;

  // Standard corner radius
  static double get standardRadius => 10.r;

  // Large corner radius
  static double get largeRadius => 16.r;

  // Button height
  static double get buttonHeight => 50.h;

  // Cell height
  static double get cellHeight => 44.h;

  // Section header height
  static double get sectionHeaderHeight => 35.h;

  // Standard margin
  static double get standardMargin => 16.w;

  // Small margin
  static double get smallMargin => 8.w;
}