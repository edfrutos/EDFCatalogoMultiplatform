import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─── Sistema de diseño EDF Catálogo ─────────────────────────────────────────
///
/// Branding propio sobre Material 3.
/// Paleta generada desde seedColor cobalt (#1A4FDB).
/// Tipografía: Inter (Google Fonts).
/// Soporte light + dark completo.
class AppTheme {
  AppTheme._();

  // ─── Paleta de marca ───────────────────────────────────────────────────────
  /// Azul cobalto EDF — color principal de marca
  static const Color seedColor = Color(0xFF1A4FDB);

  /// Teal vibrante — color secundario
  static const Color brandTeal = Color(0xFF00897B);

  /// Coral — acento terciario (acciones destructivas / alertas)
  static const Color brandCoral = Color(0xFFE64A19);

  // ─── Constantes de forma ───────────────────────────────────────────────────
  static const double radiusSmall  = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge  = 16.0;
  static const double radiusXL     = 24.0;
  static const double radiusFull   = 100.0;

  // ─── Tipografía ───────────────────────────────────────────────────────────
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.interTextTheme(base);
  }

  static TextStyle get displayLarge =>
      GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w300, letterSpacing: -0.25);

  static TextStyle get headlineLarge =>
      GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.5);

  static TextStyle get headlineMedium =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600);

  static TextStyle get titleLarge =>
      GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600);

  static TextStyle get titleMedium =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15);

  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);

  static TextStyle get labelLarge =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1);

  // ─── Tema claro ───────────────────────────────────────────────────────────
  static ThemeData light() => _buildTheme(Brightness.light);

  // ─── Tema oscuro ──────────────────────────────────────────────────────────
  static ThemeData dark() => _buildTheme(Brightness.dark);

  // ─── Constructor interno ──────────────────────────────────────────────────
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      // Ajuste manual para mayor contraste y personalidad
      primary: isDark ? const Color(0xFF92B4FF) : const Color(0xFF1A4FDB),
      onPrimary: isDark ? const Color(0xFF002A8A) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF003CB3) : const Color(0xFFDDE5FF),
      onPrimaryContainer: isDark ? const Color(0xFFDDE5FF) : const Color(0xFF001258),
      secondary: isDark ? const Color(0xFF4DDBD1) : const Color(0xFF00695C),
      onSecondary: isDark ? const Color(0xFF003731) : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF004D45) : const Color(0xFFB2DFDB),
      onSecondaryContainer: isDark ? const Color(0xFFB2DFDB) : const Color(0xFF002420),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      surface: isDark ? const Color(0xFF131318) : const Color(0xFFF8F9FF),
      onSurface: isDark ? const Color(0xFFE4E1EC) : const Color(0xFF1A1B27),
      surfaceContainerLowest: isDark ? const Color(0xFF0E0E14) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF1B1B21) : const Color(0xFFF2F3FA),
      surfaceContainer: isDark ? const Color(0xFF1F1F26) : const Color(0xFFECEDF4),
      surfaceContainerHigh: isDark ? const Color(0xFF29292F) : const Color(0xFFE6E7EF),
      surfaceContainerHighest: isDark ? const Color(0xFF34343A) : const Color(0xFFE0E1E9),
      outline: isDark ? const Color(0xFF8F909A) : const Color(0xFF74758A),
      outlineVariant: isDark ? const Color(0xFF44444F) : const Color(0xFFC5C6D5),
    );

    final textTheme = _textTheme(brightness);

    // ── AppBar ──────────────────────────────────────────────────────────────
    final appBarTheme = AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    );

    // ── Cards ───────────────────────────────────────────────────────────────
    final cardTheme = CardTheme(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    );

    // ── Inputs ──────────────────────────────────────────────────────────────
    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return colorScheme.primary;
        return colorScheme.onSurfaceVariant;
      }),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
    );

    // ── Botones elevados ─────────────────────────────────────────────────────
    final elevatedButtonTheme = ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );

    // ── Botones filled ───────────────────────────────────────────────────────
    final filledButtonTheme = FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    // ── Botones outlined ─────────────────────────────────────────────────────
    final outlinedButtonTheme = OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(0, 48),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );

    // ── TextButton ───────────────────────────────────────────────────────────
    final textButtonTheme = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );

    // ── IconButton ───────────────────────────────────────────────────────────
    final iconButtonTheme = IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    );

    // ── FAB ──────────────────────────────────────────────────────────────────
    final fabTheme = FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    );

    // ── NavigationRail ───────────────────────────────────────────────────────
    final navRailTheme = NavigationRailThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedIconTheme: IconThemeData(
        color: colorScheme.onSecondaryContainer,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSecondaryContainer,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
      ),
      indicatorColor: colorScheme.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      labelType: NavigationRailLabelType.selected,
      minWidth: 72,
      groupAlignment: -0.9,
    );

    // ── NavigationBar ────────────────────────────────────────────────────────
    final navBarTheme = NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      indicatorColor: colorScheme.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.onSecondaryContainer, size: 24);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          );
        }
        return GoogleFonts.inter(
          fontSize: 12, color: colorScheme.onSurfaceVariant,
        );
      }),
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.1),
      height: 72,
    );

    // ── Drawer ───────────────────────────────────────────────────────────────
    final drawerTheme = DrawerThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      shadowColor: colorScheme.shadow.withOpacity(0.15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(radiusXL),
          bottomRight: Radius.circular(radiusXL),
        ),
      ),
      elevation: 4,
      width: 280,
    );

    // ── Chips ────────────────────────────────────────────────────────────────
    final chipTheme = ChipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      side: BorderSide.none,
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
    );

    // ── Dialogs ──────────────────────────────────────────────────────────────
    final dialogTheme = DialogTheme(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      elevation: 4,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    // ── SnackBar ─────────────────────────────────────────────────────────────
    final snackBarTheme = SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: GoogleFonts.inter(
        color: colorScheme.onInverseSurface,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      width: 400,
    );

    // ── ListTile ─────────────────────────────────────────────────────────────
    final listTileTheme = ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

    // ── Divider ──────────────────────────────────────────────────────────────
    final dividerTheme = DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    );

    // ── Tabs ─────────────────────────────────────────────────────────────────
    final tabBarTheme = TabBarTheme(
      labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: colorScheme.outlineVariant,
    );

    // ── BottomSheet ──────────────────────────────────────────────────────────
    final bottomSheetTheme = BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusXL),
          topRight: Radius.circular(radiusXL),
        ),
      ),
      elevation: 4,
    );

    // ── Tooltip ──────────────────────────────────────────────────────────────
    final tooltipTheme = TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 12,
        color: colorScheme.onInverseSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      filledButtonTheme: filledButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme,
      iconButtonTheme: iconButtonTheme,
      floatingActionButtonTheme: fabTheme,
      navigationRailTheme: navRailTheme,
      navigationBarTheme: navBarTheme,
      drawerTheme: drawerTheme,
      chipTheme: chipTheme,
      dialogTheme: dialogTheme,
      snackBarTheme: snackBarTheme,
      listTileTheme: listTileTheme,
      dividerTheme: dividerTheme,
      tabBarTheme: tabBarTheme,
      bottomSheetTheme: bottomSheetTheme,
      tooltipTheme: tooltipTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
