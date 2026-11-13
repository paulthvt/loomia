/// Spacing scale, mirroring `Loomia/scale` in Figma
/// (`docs/design/design-system.md` §3). 4-based. Use these instead of literal
/// numbers so density can be retuned in one place.
abstract final class AppSpacing {
  /// Name → reason, chip internals.
  static const double xs = 4;

  /// Chip gaps, label → field, icon → text.
  static const double sm = 8;

  /// Row internals, list item gaps.
  static const double ms = 12;

  /// Card padding, screen horizontal padding on mobile.
  static const double md = 16;

  /// Between groups inside a screen.
  static const double lg = 24;

  /// Between sections on desktop, desktop pane padding.
  static const double xl = 32;

  /// Desktop main-column horizontal padding.
  static const double xxl = 48;

  /// Marketing and empty screens.
  static const double xxxl = 64;
}

/// Corner radii (§4). Nothing is rounder than its container: a 16px card holds
/// 12px inputs and 8px chips.
abstract final class AppRadii {
  /// Chips.
  static const double sm = 8;

  /// Inputs, list rows with a hover/selected wash.
  static const double md = 12;

  /// Cards, tiles, action items.
  static const double lg = 16;

  /// The Today hero, dialogs, bottom sheets.
  static const double xl = 20;

  /// Buttons, icon buttons, progress tracks, nav pill, and avatars at every
  /// size — avatars are circular, always.
  static const double pill = 999;

  /// Standard cards.
  static const double card = 24;

  /// Hero cards.
  static const double heroCard = 28;

  /// Hero panel.
  static const double hero = 32;
}
