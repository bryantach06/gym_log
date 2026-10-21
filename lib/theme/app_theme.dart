import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// GymLog's visual identity: near-black surfaces with a single electric-lime
/// accent, condensed athletic display type (Barlow Condensed) over Barlow.
/// Dark is the primary design; light mirrors it with ink-on-paper surfaces.
abstract final class AppTheme {
  static const _body = 'Barlow';
  static const _display = 'BarlowCondensed';

  /// Brand accent. Same in both modes so hero surfaces read identically.
  static const volt = Color(0xFFC8F25A);
  static const ink = Color(0xFF0E0F11);

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: volt,
          onPrimary: ink,
          primaryContainer: Color(0xFF2A3612),
          onPrimaryContainer: Color(0xFFDDF79A),
          secondary: Color(0xFF8DB4FF),
          onSecondary: ink,
          secondaryContainer: Color(0xFF1C2A44),
          onSecondaryContainer: Color(0xFFCFDDFF),
          tertiary: Color(0xFFFFC94A),
          onTertiary: ink,
          tertiaryContainer: Color(0xFF3D3010),
          onTertiaryContainer: Color(0xFFFFE6A6),
          error: Color(0xFFFF6B6B),
          onError: ink,
          errorContainer: Color(0xFF4A1A1C),
          onErrorContainer: Color(0xFFFFD6D6),
          surface: Color(0xFF0E0F11),
          onSurface: Color(0xFFF2F3F5),
          onSurfaceVariant: Color(0xFF9A9FA8),
          surfaceContainerLowest: Color(0xFF0A0B0C),
          surfaceContainerLow: Color(0xFF131417),
          surfaceContainer: Color(0xFF18191D),
          surfaceContainerHigh: Color(0xFF1F2125),
          surfaceContainerHighest: Color(0xFF282A30),
          outline: Color(0xFF3B3E45),
          outlineVariant: Color(0xFF26282D),
          inverseSurface: Color(0xFFF2F3F5),
          onInverseSurface: ink,
          inversePrimary: Color(0xFF4A6400),
          shadow: Colors.black,
          scrim: Colors.black,
        ),
        gym: GymColors.dark,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          // Volt is illegible as text on white, so light-mode "primary" is a
          // deep olive; volt still appears on hero surfaces via GymColors.
          primary: Color(0xFF3F5A00),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFDDF59A),
          onPrimaryContainer: Color(0xFF1A2600),
          secondary: Color(0xFF2F5BB7),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFDCE6FF),
          onSecondaryContainer: Color(0xFF0E2556),
          tertiary: Color(0xFF8A6200),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFE8B0),
          onTertiaryContainer: Color(0xFF2B1E00),
          error: Color(0xFFC62828),
          onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFF5F6F2),
          onSurface: Color(0xFF121316),
          onSurfaceVariant: Color(0xFF5D616A),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFFAFBF8),
          surfaceContainer: Colors.white,
          surfaceContainerHigh: Color(0xFFECEEE8),
          surfaceContainerHighest: Color(0xFFE3E5DE),
          outline: Color(0xFFC4C7BE),
          outlineVariant: Color(0xFFE2E4DD),
          inverseSurface: Color(0xFF1B1C1F),
          onInverseSurface: Color(0xFFF2F3F5),
          inversePrimary: volt,
          shadow: Colors.black,
          scrim: Colors.black,
        ),
        gym: GymColors.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required GymColors gym,
  }) {
    final isDark = brightness == Brightness.dark;
    final text = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);
    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      fontFamily: _body,
      textTheme: text,
      extensions: [gym],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: isDark ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge?.copyWith(fontSize: 16, letterSpacing: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge?.copyWith(fontSize: 16, letterSpacing: 0.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: gym.accent,
        foregroundColor: gym.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: gym.accent,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: gym.onAccent),
        checkmarkColor: gym.onAccent,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? gym.accent : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? gym.onAccent : scheme.onSurface,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: gym.accent,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? gym.onAccent : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyLarge?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? gym.accent : scheme.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? gym.onAccent : scheme.onSurfaceVariant,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static TextTheme _textTheme(Color main, Color muted) {
    TextStyle display(double size, FontWeight w, {double spacing = 0}) => TextStyle(
          fontFamily: _display,
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          height: 1.05,
          color: main,
        );
    TextStyle body(double size, FontWeight w, {Color? color, double spacing = 0, double height = 1.35}) =>
        TextStyle(
          fontFamily: _body,
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          height: height,
          color: color ?? main,
        );

    return TextTheme(
      displayLarge: display(64, FontWeight.w800, spacing: -1),
      displayMedium: display(48, FontWeight.w800, spacing: -0.5),
      displaySmall: display(38, FontWeight.w800),
      headlineLarge: display(34, FontWeight.w700),
      headlineMedium: display(28, FontWeight.w700),
      headlineSmall: display(24, FontWeight.w700),
      titleLarge: display(22, FontWeight.w700, spacing: 0.2),
      titleMedium: body(17, FontWeight.w600),
      titleSmall: body(15, FontWeight.w600),
      bodyLarge: body(16, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, color: muted),
      labelLarge: body(15, FontWeight.w600, spacing: 0.2),
      labelMedium: body(13, FontWeight.w600, spacing: 0.2),
      labelSmall: body(11.5, FontWeight.w700, color: muted, spacing: 1.2),
    );
  }

  /// Big tabular numerals for stats and set values.
  static TextStyle number(BuildContext context, {double size = 28, Color? color}) => TextStyle(
        fontFamily: _display,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1,
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// App-specific colors that ColorScheme has no slot for.
@immutable
class GymColors extends ThemeExtension<GymColors> {
  final Color accent;
  final Color onAccent;
  final Color pr;
  final Color onPr;
  final Color warmup;
  final Color dropset;
  final Map<String, Color> muscle;

  const GymColors({
    required this.accent,
    required this.onAccent,
    required this.pr,
    required this.onPr,
    required this.warmup,
    required this.dropset,
    required this.muscle,
  });

  static const _muscleDark = {
    'chest': Color(0xFFFF7A59),
    'back': Color(0xFF5AB0FF),
    'shoulders': Color(0xFFB48CFF),
    'biceps': Color(0xFF4FD6A8),
    'triceps': Color(0xFF2EC4D6),
    'legs': Color(0xFFC8F25A),
    'glutes': Color(0xFFFF6FAE),
    'core': Color(0xFFFFC94A),
    'cardio': Color(0xFFFF5C5C),
  };

  static const _muscleLight = {
    'chest': Color(0xFFD9481F),
    'back': Color(0xFF1F6FD1),
    'shoulders': Color(0xFF7A4FD6),
    'biceps': Color(0xFF138A63),
    'triceps': Color(0xFF0F8798),
    'legs': Color(0xFF557A00),
    'glutes': Color(0xFFC72F78),
    'core': Color(0xFFA87400),
    'cardio': Color(0xFFC62828),
  };

  static const dark = GymColors(
    accent: AppTheme.volt,
    onAccent: AppTheme.ink,
    pr: Color(0xFFFFC94A),
    onPr: AppTheme.ink,
    warmup: Color(0xFFFFA24A),
    dropset: Color(0xFF8DB4FF),
    muscle: _muscleDark,
  );

  static const light = GymColors(
    accent: AppTheme.volt,
    onAccent: AppTheme.ink,
    pr: Color(0xFFE0A400),
    onPr: AppTheme.ink,
    warmup: Color(0xFFD9730D),
    dropset: Color(0xFF2F5BB7),
    muscle: _muscleLight,
  );

  Color muscleColor(String group) => muscle[group] ?? const Color(0xFF8A8F98);

  static GymColors of(BuildContext context) => Theme.of(context).extension<GymColors>()!;

  @override
  GymColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? pr,
    Color? onPr,
    Color? warmup,
    Color? dropset,
    Map<String, Color>? muscle,
  }) =>
      GymColors(
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        pr: pr ?? this.pr,
        onPr: onPr ?? this.onPr,
        warmup: warmup ?? this.warmup,
        dropset: dropset ?? this.dropset,
        muscle: muscle ?? this.muscle,
      );

  @override
  GymColors lerp(GymColors? other, double t) {
    if (other == null) return this;
    return GymColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      pr: Color.lerp(pr, other.pr, t)!,
      onPr: Color.lerp(onPr, other.onPr, t)!,
      warmup: Color.lerp(warmup, other.warmup, t)!,
      dropset: Color.lerp(dropset, other.dropset, t)!,
      muscle: t < 0.5 ? muscle : other.muscle,
    );
  }
}
