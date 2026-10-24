import 'package:material_ui/material_ui.dart';

/// Colour tokens, mirroring the Figma collection `Loomia/color`
/// (see `docs/design/design-system.md` §1). Figma is the source of truth; this
/// file is its Dart projection, so token names match one-to-one.
///
/// Two homes for a token:
/// * `ColorScheme` when Material already has a slot with the same meaning,
/// * [LoomiaColors] when it does not (sunken surfaces, borders, muted ink,
///   accent, progress track, focus ring, semantic states).
///
/// Widgets read `Theme.of(context).colorScheme` and `LoomiaColors.of(context)`.
/// Never a literal colour.
abstract final class AppColors {
  /// Opacity of `onPrimary` for the hero's secondary labels (eyebrow,
  /// captions). The hero is the same colour in both modes, so one value holds
  /// both; below 0.92 it drops under AA on `primary`.
  static const quietOnPrimary = 0.94;

  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFA75C15), // primary/base — identical in both modes
    onPrimary: Color(0xFFFFFFFF), // text/on-primary
    primaryContainer: Color(0xFFF2E8DE),
    onPrimaryContainer: Color(0xFF713E0E),
    secondary: Color(0xFF697DAB),
    onSecondary: Color(0xFF0B111E), // text/on-secondary
    secondaryContainer: Color(0xFFE5E7EB),
    onSecondaryContainer: Color(0xFF3D4B6C),
    error: Color(0xFFCF3046),
    onError: Color(0xFFFFFFFF), // semantic/on-error
    errorContainer: Color(0xFFF0E0E2),
    onErrorContainer: Color(0xFF88202E),
    surface: Color(0xFFFBFAF8), // surface/canvas
    onSurface: Color(0xFF201B16), // text/primary
    onSurfaceVariant: Color(0xFF57524C), // text/secondary
    surfaceContainerLowest: Color(0xFFFFFFFF), // surface/default
    surfaceContainerLow: Color(0xFFFFFFFF), // surface/raised
    surfaceContainer: Color(0xFFF4F1EE), // surface/sunken
    surfaceContainerHigh: Color(0xFFF4F1EE),
    surfaceContainerHighest: Color(0xFFF2EFEC), // surface/disabled
    outline: Color(0xFFCFC8C0), // border/strong
    outlineVariant: Color(0xFFE8E4E1), // border/subtle
    shadow: Color(0xFF201B16),
    scrim: Color(0xFF201B16),
    inverseSurface: Color(0xFF201B16),
    onInverseSurface: Color(0xFFFBFAF8),
    // The snackbar's Undo (#372): 8.4:1 on inverseSurface.
    inversePrimary: Color(0xFFE0AB7B),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA75C15),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF271E16),
    onPrimaryContainer: Color(0xFFE0AB7B),
    secondary: Color(0xFF909FC1),
    onSecondary: Color(0xFF0B111E),
    secondaryContainer: Color(0xFF1B1D22),
    onSecondaryContainer: Color(0xFFAAB5CF),
    error: Color(0xFFD5818C),
    onError: Color(0xFF241110),
    errorContainer: Color(0xFF25181A),
    onErrorContainer: Color(0xFFE0A3AC),
    surface: Color(0xFF120F0C),
    onSurface: Color(0xFFF1EEEC),
    onSurfaceVariant: Color(0xFFC2BCB7),
    surfaceContainerLowest: Color(0xFF181411), // surface/sunken
    surfaceContainerLow: Color(0xFF1E1A15), // surface/default
    surfaceContainer: Color(0xFF1E1A15),
    surfaceContainerHigh: Color(0xFF26211C), // surface/raised
    surfaceContainerHighest: Color(0xFF26211C),
    outline: Color(0xFF48413A),
    outlineVariant: Color(0xFF312C26),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF1EEEC),
    onInverseSurface: Color(0xFF201B16),
    // 5.9:1 on inverseSurface; primary itself is 4.3:1, under AA.
    inversePrimary: Color(0xFF8A4A0F),
  );
}

/// The colour tokens `ColorScheme` has no slot for.
///
/// `LoomiaColors.of(context)` is the only way widgets should reach them.
@immutable
class LoomiaColors extends ThemeExtension<LoomiaColors> {
  const LoomiaColors({
    required this.brand,
    required this.surfaceDefault,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.surfaceDisabled,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textMuted,
    required this.textDisabled,
    required this.primaryHover,
    required this.primaryText,
    required this.primaryMuted,
    required this.secondaryText,
    required this.secondaryTrack,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.focus,
  });

  /// Logo, app icon, decorative marks. Never behind text — too light for
  /// white ink; text sits on `colorScheme.primary`.
  final Color brand;

  /// Cards, rows, bars.
  final Color surfaceDefault;

  /// Search field, sidebar, wells.
  final Color surfaceSunken;

  /// Menus, sheets, dialogs. In dark this steps *up* instead of adding shadow.
  final Color surfaceRaised;
  final Color surfaceDisabled;

  /// The default 1px hairline.
  final Color borderSubtle;

  /// Unchecked controls, dividers that must be seen.
  final Color borderStrong;

  /// Metadata, overlines, captions.
  final Color textMuted;
  final Color textDisabled;

  /// Pointer hover on a primary fill; also the hero's own progress track.
  final Color primaryHover;

  /// Primary used as *ink*. Flips between modes — `colorScheme.primary` does
  /// not, and fails contrast on a dark surface.
  final Color primaryText;

  /// Hover wash, selected row.
  final Color primaryMuted;

  /// "On pace", pace labels.
  final Color secondaryText;

  /// Track under a `secondary` progress bar.
  final Color secondaryTrack;

  /// Date-anchored marks only — a birthday, a promised call-back. Never
  /// judgement (see design principle #4).
  final Color accent;
  final Color accentContainer;
  final Color onAccentContainer;

  final Color success;
  final Color successContainer;

  /// System states only (sync, permission) — olive-gold, so it cannot be
  /// read as [brand] or [accent].
  final Color warning;
  final Color warningContainer;

  final Color info;
  final Color infoContainer;

  /// 2px focus-visible ring.
  final Color focus;

  /// Same in both modes: the logo does not change with the theme.
  static const _brand = Color(0xFFE8964A);

  static const light = LoomiaColors(
    brand: _brand,
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF4F1EE),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceDisabled: Color(0xFFF2EFEC),
    borderSubtle: Color(0xFFE8E4E1),
    borderStrong: Color(0xFFCFC8C0),
    textMuted: Color(0xFF706A64),
    textDisabled: Color(0xFFA9A49F),
    primaryHover: Color(0xFF8C4C12),
    primaryText: Color(0xFF995413),
    primaryMuted: Color(0xFFF9F5F1),
    secondaryText: Color(0xFF495B83),
    secondaryTrack: Color(0xFFCBCFD8),
    accent: Color(0xFFA94C8D),
    accentContainer: Color(0xFFEDE3EA),
    onAccentContainer: Color(0xFF71335E),
    success: Color(0xFF2E7D5B),
    successContainer: Color(0xFFDCEFE4),
    warning: Color(0xFF8A690F),
    warningContainer: Color(0xFFF2EDDE),
    info: Color(0xFF2C6B7A),
    infoContainer: Color(0xFFDDEDF1),
    focus: Color(0xFF995413),
  );

  static const dark = LoomiaColors(
    brand: _brand,
    surfaceDefault: Color(0xFF1E1A15),
    surfaceSunken: Color(0xFF181411),
    surfaceRaised: Color(0xFF26211C),
    surfaceDisabled: Color(0xFF211E1A),
    borderSubtle: Color(0xFF312C26),
    borderStrong: Color(0xFF48413A),
    textMuted: Color(0xFFA59E97),
    textDisabled: Color(0xFF68625C),
    primaryHover: Color(0xFFB06017),
    primaryText: Color(0xFFD38A45),
    primaryMuted: Color(0xFF1A140F),
    secondaryText: Color(0xFF909FC1),
    secondaryTrack: Color(0xFF2D3139),
    accent: Color(0xFFBF87AE),
    accentContainer: Color(0xFF231B20),
    onAccentContainer: Color(0xFFD1A9C5),
    success: Color(0xFF5FC196),
    successContainer: Color(0xFF13291F),
    warning: Color(0xFFBC9529),
    warningContainer: Color(0xFF272316),
    info: Color(0xFF74BDCB),
    infoContainer: Color(0xFF14282E),
    focus: Color(0xFFD38A45),
  );

  /// Throws if the extension is missing, which only happens outside
  /// [AppTheme] — a bug, not a case to fall back from.
  static LoomiaColors of(BuildContext context) =>
      Theme.of(context).extension<LoomiaColors>()!;

  /// No field-by-field override exists because nothing needs one: the two
  /// instances above are the whole palette.
  @override
  LoomiaColors copyWith() => this;

  @override
  LoomiaColors lerp(LoomiaColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LoomiaColors(
      brand: c(brand, other.brand),
      surfaceDefault: c(surfaceDefault, other.surfaceDefault),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceDisabled: c(surfaceDisabled, other.surfaceDisabled),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderStrong: c(borderStrong, other.borderStrong),
      textMuted: c(textMuted, other.textMuted),
      textDisabled: c(textDisabled, other.textDisabled),
      primaryHover: c(primaryHover, other.primaryHover),
      primaryText: c(primaryText, other.primaryText),
      primaryMuted: c(primaryMuted, other.primaryMuted),
      secondaryText: c(secondaryText, other.secondaryText),
      secondaryTrack: c(secondaryTrack, other.secondaryTrack),
      accent: c(accent, other.accent),
      accentContainer: c(accentContainer, other.accentContainer),
      onAccentContainer: c(onAccentContainer, other.onAccentContainer),
      success: c(success, other.success),
      successContainer: c(successContainer, other.successContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      focus: c(focus, other.focus),
    );
  }
}

/// A tag's two colours in one mode: the chip's fill, and its text, dot and
/// check.
typedef TagInk = ({Color container, Color ink});

/// The tag palette (#332), Figma `tag/<key>/container` and `tag/<key>/ink`.
/// Stored by name in `tag.color`; the order is the order new tags take them.
/// No red: no chip is red (components.md #6).
enum TagColor {
  stone(
    light: (container: Color(0xFFECE8E3), ink: Color(0xFF6B6158)),
    dark: (container: Color(0xFF3A3631), ink: Color(0xFFDDD6CD)),
  ),
  sand(
    light: (container: Color(0xFFF2E7CF), ink: Color(0xFF7D5B0F)),
    dark: (container: Color(0xFF45391F), ink: Color(0xFFEBD7AA)),
  ),
  olive(
    light: (container: Color(0xFFE7E9CD), ink: Color(0xFF5F6614)),
    dark: (container: Color(0xFF3B3D1F), ink: Color(0xFFD6DAA6)),
  ),
  sage(
    light: (container: Color(0xFFDCEADC), ink: Color(0xFF36714A)),
    dark: (container: Color(0xFF283D2C), ink: Color(0xFFB9D9BE)),
  ),
  teal(
    light: (container: Color(0xFFD3EAE7), ink: Color(0xFF176D66)),
    dark: (container: Color(0xFF1E3D3A), ink: Color(0xFFA9DCD5)),
  ),
  sky(
    light: (container: Color(0xFFD8E7F3), ink: Color(0xFF285F94)),
    dark: (container: Color(0xFF20364A), ink: Color(0xFFB4D2EC)),
  ),
  indigo(
    light: (container: Color(0xFFDFE1F4), ink: Color(0xFF4A52AE)),
    dark: (container: Color(0xFF2C3058), ink: Color(0xFFC5CAF2)),
  ),
  violet(
    light: (container: Color(0xFFEBE0F2), ink: Color(0xFF7A47A6)),
    dark: (container: Color(0xFF3D2C4D), ink: Color(0xFFDCC6EE)),
  );

  const TagColor({required this.light, required this.dark});

  final TagInk light;
  final TagInk dark;

  /// This key's colours in the theme's mode.
  TagInk of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
