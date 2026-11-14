import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color telegramBlue = Color(0xFF5682A3);
  static const Color telegramBlueDark = Color(0xFF477695);
  static const Color telegramBlueLight = Color(0xFF6D98B8);
  static const Color error = Color(0xFFB6534A);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.header,
    required this.headerDark,
    required this.onHeader,
    required this.headerMuted,
    required this.selectedChat,
    required this.wallpaperTint,
    required this.incomingMessage,
    required this.outgoingMessage,
    required this.incomingMeta,
    required this.outgoingMeta,
    required this.loadingOverlay,
  });

  final Color header;
  final Color headerDark;
  final Color onHeader;
  final Color headerMuted;
  final Color selectedChat;
  final Color wallpaperTint;
  final Color incomingMessage;
  final Color outgoingMessage;
  final Color incomingMeta;
  final Color outgoingMeta;
  final Color loadingOverlay;

  static const AppPalette light = AppPalette(
    header: AppColors.telegramBlue,
    headerDark: AppColors.telegramBlueDark,
    onHeader: Colors.white,
    headerMuted: Color(0xFFD7E5EE),
    selectedChat: AppColors.telegramBlueLight,
    wallpaperTint: Colors.white,
    incomingMessage: Colors.white,
    outgoingMessage: Color(0xFFEFFDDE),
    incomingMeta: Color(0xFF97A3A8),
    outgoingMeta: Color(0xFF79A06A),
    loadingOverlay: Color(0x1AFFFFFF),
  );

  static const AppPalette dark = AppPalette(
    header: Color(0xFF3E6D8D),
    headerDark: Color(0xFF315873),
    onHeader: Colors.white,
    headerMuted: Color(0xFFC4D7E3),
    selectedChat: Color(0xFF3A627C),
    wallpaperTint: Color(0xFF18252C),
    incomingMessage: Color(0xFF253239),
    outgoingMessage: Color(0xFF293D33),
    incomingMeta: Color(0xFF9AA9B0),
    outgoingMeta: Color(0xFF91BA91),
    loadingOverlay: Color(0x520E171C),
  );

  @override
  AppPalette copyWith({
    Color? header,
    Color? headerDark,
    Color? onHeader,
    Color? headerMuted,
    Color? selectedChat,
    Color? wallpaperTint,
    Color? incomingMessage,
    Color? outgoingMessage,
    Color? incomingMeta,
    Color? outgoingMeta,
    Color? loadingOverlay,
  }) {
    return AppPalette(
      header: header ?? this.header,
      headerDark: headerDark ?? this.headerDark,
      onHeader: onHeader ?? this.onHeader,
      headerMuted: headerMuted ?? this.headerMuted,
      selectedChat: selectedChat ?? this.selectedChat,
      wallpaperTint: wallpaperTint ?? this.wallpaperTint,
      incomingMessage: incomingMessage ?? this.incomingMessage,
      outgoingMessage: outgoingMessage ?? this.outgoingMessage,
      incomingMeta: incomingMeta ?? this.incomingMeta,
      outgoingMeta: outgoingMeta ?? this.outgoingMeta,
      loadingOverlay: loadingOverlay ?? this.loadingOverlay,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return AppPalette(
      header: Color.lerp(header, other.header, t)!,
      headerDark: Color.lerp(headerDark, other.headerDark, t)!,
      onHeader: Color.lerp(onHeader, other.onHeader, t)!,
      headerMuted: Color.lerp(headerMuted, other.headerMuted, t)!,
      selectedChat: Color.lerp(selectedChat, other.selectedChat, t)!,
      wallpaperTint: Color.lerp(wallpaperTint, other.wallpaperTint, t)!,
      incomingMessage: Color.lerp(incomingMessage, other.incomingMessage, t)!,
      outgoingMessage: Color.lerp(outgoingMessage, other.outgoingMessage, t)!,
      incomingMeta: Color.lerp(incomingMeta, other.incomingMeta, t)!,
      outgoingMeta: Color.lerp(outgoingMeta, other.outgoingMeta, t)!,
      loadingOverlay: Color.lerp(loadingOverlay, other.loadingOverlay, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get appPalette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildAppTheme() => _buildAppTheme(
  brightness: Brightness.light,
  palette: AppPalette.light,
  colorScheme: const ColorScheme.light(
    primary: AppColors.telegramBlue,
    onPrimary: Colors.white,
    secondary: AppColors.telegramBlueLight,
    onSecondary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF263238),
    onSurfaceVariant: Color(0xFF84939C),
    outline: Color(0xFFBCCBD3),
    outlineVariant: Color(0xFFDFE5E8),
    surfaceContainerHighest: Color(0xFFF1F3F4),
    shadow: Color(0xFF455A64),
  ),
);

ThemeData buildDarkAppTheme() => _buildAppTheme(
  brightness: Brightness.dark,
  palette: AppPalette.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF78A8C7),
    onPrimary: Color(0xFF101A20),
    secondary: Color(0xFF78A8C7),
    onSecondary: Color(0xFF101A20),
    error: Color(0xFFE1857B),
    onError: Color(0xFF1E0A08),
    surface: Color(0xFF182229),
    onSurface: Color(0xFFE5EDF1),
    onSurfaceVariant: Color(0xFF96A7B0),
    outline: Color(0xFF596B75),
    outlineVariant: Color(0xFF35464F),
    surfaceContainerHighest: Color(0xFF26343C),
    shadow: Colors.black,
  ),
);

ThemeData _buildAppTheme({
  required Brightness brightness,
  required AppPalette palette,
  required ColorScheme colorScheme,
}) {
  final TextTheme textTheme = TextTheme(
    bodyMedium: TextStyle(
      color: colorScheme.onSurface,
      fontSize: 13,
      height: 1.25,
    ),
    bodySmall: TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 11,
      height: 1.2,
    ),
    titleMedium: TextStyle(
      color: colorScheme.onSurface,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    primaryColor: palette.header,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    cardColor: colorScheme.surface,
    colorScheme: colorScheme,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const <String>[
      'Tahoma',
      'Noto Sans',
      'Roboto',
      'sans-serif',
    ],
    textTheme: textTheme,
    visualDensity: VisualDensity.compact,
    splashColor: colorScheme.primary.withValues(alpha: 0.12),
    highlightColor: colorScheme.primary.withValues(alpha: 0.07),
    hoverColor: colorScheme.primary.withValues(alpha: 0.08),
    focusColor: colorScheme.primary.withValues(alpha: 0.12),
    disabledColor: colorScheme.onSurface.withValues(alpha: 0.38),
    dividerColor: colorScheme.outlineVariant,
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colorScheme.primary),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: colorScheme.primary,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(
        colorScheme.primary.withValues(alpha: 0.42),
      ),
      thickness: const WidgetStatePropertyAll<double>(6),
      radius: const Radius.circular(3),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[palette],
  );
}
