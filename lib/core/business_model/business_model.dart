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

  /// The team volume (OV for dōTERRA) a rank usually needs, as the company
  /// states it: a planning prefill, never a rule Loomia checks. Ranks whose
  /// requirement is branches only have none.
  // ponytail: copied from the compensation plan by hand (2026-10-05); move to
  // the database if the company changes it more than once a year.
  Map<String, double> get levelVolumes => switch (this) {
    other => const {},
    doterra => const {
      'Manager': 500,
      'Director': 1000,
      'Executive': 2000,
      'Elite': 3000,
      'Premier': 5000,
      'Silver': 9000,
      'Gold': 15000,
      'Platinum': 27000,
    },
  };
}
