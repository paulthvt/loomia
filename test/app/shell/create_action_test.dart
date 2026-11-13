import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/l10n/app_localizations_en.dart';

void main() {
  test('no create action outside the tabs', () {
    final l10n = AppLocalizationsEn();

    expect(createActionFor('/contacts/42', l10n), isNull);
    expect(createActionFor('/settings', l10n), isNull);
    expect(createActionFor('/contacts', l10n)?.label, 'New person');
  });
}
