import 'package:material_ui/material_ui.dart';

/// Type ramp (`docs/design/design-system.md` §2): Plus Jakarta Sans, one
/// bundled variable font, three weights in use.
///
/// The 13 design styles map onto `TextTheme` where Material has a slot with the
/// same job; [overline], [numericLarge] and [numeric] have no slot and are
/// exposed as statics. Slots we do not define keep the Material default with
/// the family applied.
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static const _regular = FontWeight.w400;
  static const _medium = FontWeight.w500;
  static const _bold = FontWeight.w700;

  /// The file is a variable font, so the weight axis must be set explicitly —
  /// `fontWeight` alone only picks a named instance where one exists.
  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Desktop greeting, contact name on desktop detail.
  static final display = _style(32, 38, _bold, letterSpacing: -0.48);

  /// Mobile screen title, contact name on mobile.
  static final headline = _style(24, 30, _bold, letterSpacing: -0.24);

  /// Hero headline, dialog title, empty-state title.
  static final titleLarge = _style(20, 26, _bold, letterSpacing: -0.1);

  /// A person's name in a row — the most-used heading in the product.
  static final title = _style(17, 24, _bold);

  /// Input values, dialog body, sentences that matter.
  static final bodyLarge = _style(16, 24, _regular);
  static final body = _style(15, 22, _regular);

  /// The reason line under a name.
  static final bodySmall = _style(13, 18, _regular);

  /// Buttons, sidebar items.
  static final labelLarge = _style(15, 20, _bold);

  /// Field labels, small actions.
  static final label = _style(13, 16, _bold);

  /// Metadata, pace, nav labels.
  static final caption = _style(12, 16, _medium);

  /// Section headers, stat-tile labels, date eyebrows. The only uppercase in
  /// the product — never a heading, never a button.
  static final overline = _style(11, 14, _bold, letterSpacing: 1.1);

  /// The narrow week columns' titles (#448). The floor: nothing smaller.
  static final micro = _style(10, 12, _medium);

  /// Stat-tile values. Capped at 30px so no numeral out-shouts the greeting.
  static final numericLarge = _style(
    30,
    34,
    _bold,
    letterSpacing: -0.3,
    tabular: true,
  );

  /// Goal values.
  static final numeric = _style(
    20,
    24,
    _bold,
    letterSpacing: -0.1,
    tabular: true,
  );

  static TextTheme textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final inkVariant = scheme.onSurfaceVariant;
    return TextTheme(
      displaySmall: display.copyWith(color: ink),
      headlineSmall: headline.copyWith(color: ink),
      titleLarge: titleLarge.copyWith(color: ink),
      titleMedium: title.copyWith(color: ink),
      // Ink, not inkVariant: a text field paints its value in this slot's
      // colour, and a value is text/primary. Body copy in this style sets
      // onSurfaceVariant itself.
      bodyLarge: bodyLarge.copyWith(color: ink),
      bodyMedium: body.copyWith(color: inkVariant),
      bodySmall: bodySmall.copyWith(color: inkVariant),
      labelLarge: labelLarge.copyWith(color: ink),
      labelMedium: label.copyWith(color: ink),
      labelSmall: caption.copyWith(color: inkVariant),
    );
  }
}
