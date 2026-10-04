/// What a month did: own volume (PV for dōTERRA) and four counts.
class Progress {
  const Progress({
    required this.ownVolume,
    required this.prospects,
    required this.customers,
    required this.teamMembers,
    required this.loyalty,
  });

  final double ownVolume;

  /// People added as prospects.
  final int prospects;

  /// People who became customers, or were added as one.
  final int customers;

  /// People who joined the team, or were added to it.
  final int teamMembers;

  /// Loyalty steps ticked.
  final int loyalty;
}

/// One month: what the user aimed for and, once closed, what happened.
/// Every target is optional.
class MonthPlan {
  const MonthPlan({
    required this.month,
    this.ownVolumeTarget,
    this.teamVolumeTarget,
    this.levelTarget,
    this.prospectsTarget,
    this.customersTarget,
    this.teamMembersTarget,
    this.loyaltyTarget,
    this.loyaltyForecast,
    this.actual,
    this.teamVolumeActual,
    this.levelActual,
    this.closedAt,
  });

  /// Local midnight on the 1st.
  final DateTime month;
  final double? ownVolumeTarget;
  final double? teamVolumeTarget;
  final String? levelTarget;
  final int? prospectsTarget;
  final int? customersTarget;
  final int? teamMembersTarget;
  final int? loyaltyTarget;

  /// What the forecast said when planning.
  final int? loyaltyForecast;

  /// Frozen at close; null while open.
  final Progress? actual;

  /// Typed at close: the company computes them, not the book.
  final double? teamVolumeActual;
  final String? levelActual;
  final DateTime? closedAt;

  bool get closed => closedAt != null;
}
