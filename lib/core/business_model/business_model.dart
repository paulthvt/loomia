/// The company the user works with, asked on the first-run screen. It only
/// changes words: Other keeps neutral terms, dōTERRA brings PV, OV, ranks and
/// LRPs (through ARB `select`s, never `if (doterra)` in a widget).
///
/// Stored in the user metadata as `business_model`; Other is the absence, so
/// accounts from before the question are Other.
enum BusinessModel {
  other,
  doterra;

  /// Anything this build does not know — a newer build's company, a typo —
  /// reads as Other rather than failing.
  static BusinessModel parse(Object? stored) =>
      values.asNameMap()[stored] ?? other;

  /// What goes in the metadata: null removes the key.
  String? get stored => this == other ? null : name;

  /// A team member's possible ranks, lowest first, as the company writes them
  /// (proper nouns, never translated). Empty when Loomia does not know the
  /// company's ladder: the user types the level instead.
  List<String> get levels => switch (this) {
    other => const [],
    doterra => const [
      'Manager',
      'Director',
      'Executive',
      'Elite',
      'Premier',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Blue Diamond',
      'Presidential Diamond',
    ],
  };
}
