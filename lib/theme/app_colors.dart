import 'package:flutter/material.dart';

/// Neutral colors that must change between light and dark mode. Brand and
/// accent colors (teal, orange, green, ...) look fine in both and stay as
/// plain constants where they're used.
///
/// Read them with `context.colors.surface` etc. That also subscribes the
/// widget to theme changes, so it repaints when the mode switches.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Screen background.
  final Color bg;

  /// Cards, sheets and other raised surfaces (was plain white).
  final Color surface;

  /// Primary text/icon color.
  final Color ink;

  /// Secondary text.
  final Color inkSoft;

  /// Text/icons placed on an [ink]-filled shape (e.g. a selected chip).
  final Color onInk;

  /// Hairline borders and dividers.
  final Color line;

  /// Stronger borders, dashed outlines, disabled controls.
  final Color lineStrong;

  /// Empty progress tracks and bars with no data.
  final Color track;

  /// Placeholder/hint text.
  final Color hint;

  /// Muted icons such as dropdown chevrons.
  final Color iconMuted;

  /// Soft teal fill for selected items.
  final Color tealTint;
  final Color tealTintStrong;

  /// Bar for a day that was started but not completed.
  final Color barPartial;

  final Color amberBg;
  final Color amberText;
  final Color streakBg;
  final Color streakText;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.onInk,
    required this.line,
    required this.lineStrong,
    required this.track,
    required this.hint,
    required this.iconMuted,
    required this.tealTint,
    required this.tealTintStrong,
    required this.barPartial,
    required this.amberBg,
    required this.amberText,
    required this.streakBg,
    required this.streakText,
  });

  static const light = AppColors(
    bg: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF14201F),
    inkSoft: Color(0xFF5B6B69),
    onInk: Color(0xFFFFFFFF),
    line: Color(0xFFE4EAE9),
    lineStrong: Color(0xFFC9D4D2),
    track: Color(0xFFDDE6E4),
    hint: Color(0xFFA7B3B1),
    iconMuted: Color(0xFFB7C2C0),
    tealTint: Color(0xFFEAF7F6),
    tealTintStrong: Color(0xFFE1F5F3),
    barPartial: Color(0xFFBFE6E1),
    amberBg: Color(0xFFFFF7E6),
    amberText: Color(0xFF9A6B14),
    streakBg: Color(0xFFFFF1E6),
    streakText: Color(0xFFD9692A),
  );

  static const dark = AppColors(
    bg: Color(0xFF0E1514),
    surface: Color(0xFF182120),
    ink: Color(0xFFE7EFED),
    inkSoft: Color(0xFF9BAEAA),
    onInk: Color(0xFF0E1514),
    line: Color(0xFF283432),
    lineStrong: Color(0xFF3A4946),
    track: Color(0xFF2A3634),
    hint: Color(0xFF6C7E7A),
    iconMuted: Color(0xFF5F706D),
    tealTint: Color(0xFF14312E),
    tealTintStrong: Color(0xFF1A3F3B),
    barPartial: Color(0xFF2C5F59),
    amberBg: Color(0xFF362C12),
    amberText: Color(0xFFE8BC62),
    streakBg: Color(0xFF3A2516),
    streakText: Color(0xFFFF9B5E),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkSoft,
    Color? onInk,
    Color? line,
    Color? lineStrong,
    Color? track,
    Color? hint,
    Color? iconMuted,
    Color? tealTint,
    Color? tealTintStrong,
    Color? barPartial,
    Color? amberBg,
    Color? amberText,
    Color? streakBg,
    Color? streakText,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      onInk: onInk ?? this.onInk,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      track: track ?? this.track,
      hint: hint ?? this.hint,
      iconMuted: iconMuted ?? this.iconMuted,
      tealTint: tealTint ?? this.tealTint,
      tealTintStrong: tealTintStrong ?? this.tealTintStrong,
      barPartial: barPartial ?? this.barPartial,
      amberBg: amberBg ?? this.amberBg,
      amberText: amberText ?? this.amberText,
      streakBg: streakBg ?? this.streakBg,
      streakText: streakText ?? this.streakText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      onInk: mix(onInk, other.onInk),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      track: mix(track, other.track),
      hint: mix(hint, other.hint),
      iconMuted: mix(iconMuted, other.iconMuted),
      tealTint: mix(tealTint, other.tealTint),
      tealTintStrong: mix(tealTintStrong, other.tealTintStrong),
      barPartial: mix(barPartial, other.barPartial),
      amberBg: mix(amberBg, other.amberBg),
      amberText: mix(amberText, other.amberText),
      streakBg: mix(streakBg, other.streakBg),
      streakText: mix(streakText, other.streakText),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
