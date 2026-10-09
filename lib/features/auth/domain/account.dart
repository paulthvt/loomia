import 'package:loomia/core/business_model/business_model.dart';

/// Light or dark, as chosen in Settings. [system] follows the device.
enum Appearance { system, light, dark }

/// The signed-in user, as the app sees them. No `supabase_flutter` type, so
/// screens and tests build one directly.
class Account {
  const Account({
    required this.firstName,
    required this.email,
    this.locale,
    this.appearance = Appearance.system,
    this.onboarded = true,
    this.businessModel = BusinessModel.other,
    this.avatarPath,
    this.googlePicture,
  });

  /// Empty when the user never gave one (an email sign-up always does).
  final String firstName;
  final String email;

  /// A language code the user chose in Settings, or null to follow the system.
  final String? locale;

  final Appearance appearance;

  /// False for a new account until its first-run screen is passed (imported,
  /// added someone, or skipped); then true on every device.
  final bool onboarded;

  /// Which company's words the app uses. Other until the user picks one.
  final BusinessModel businessModel;

  /// The Storage path of the user's own photo (`avatar_path`, #239); null
  /// shows initials.
  final String? avatarPath;

  /// The picture Google gave at sign-in (`avatar_url`, refreshed by Supabase
  /// on each Google sign-in, #241); null for email and Apple accounts.
  final String? googlePicture;

  /// What to show where a name is expected: the first name, else the email.
  String get displayName => firstName.isEmpty ? email : firstName;
}
