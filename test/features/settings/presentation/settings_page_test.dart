import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/photos/photo_picker.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/core/ui/avatar_control.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/settings/presentation/settings_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/photos/fake_photo_picker.dart';
import '../../../core/photos/fake_photo_repository.dart';
import '../../auth/fake_auth_repository.dart';

/// Through the real app, so the redirect after sign-out and the locale switch
/// are part of what is tested.
Future<FakeAuthRepository> _openSettings(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String? avatarPath,
  String? googlePicture,
  FakePhotoRepository? photos,
  FakePhotoPicker? picker,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeAuthRepository()
    ..session = true
    ..account = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      avatarPath: avatarPath,
      googlePicture: googlePicture,
    );
  addTearDown(fake.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        photoRepositoryProvider.overrideWithValue(
          photos ?? FakePhotoRepository(),
        ),
        photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      ],
      child: const LoomiaApp(),
    ),
  );
  await tester.pumpAndSettle();
  switch (Breakpoints.of(size.width)) {
    case ScreenSize.mobile:
      await tester.tap(find.byType(AccountButton));
    case ScreenSize.tablet:
      // The rail shows only an avatar; its label is for screen readers.
      final semantics = tester.ensureSemantics();
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      semantics.dispose();
    case ScreenSize.desktop:
      await tester.tap(find.text('Pauline'));
  }
  await tester.pumpAndSettle();
  return fake;
}

Future<FakeAuthRepository> _openSection(WidgetTester tester, String row) async {
  final fake = await _openSettings(tester);
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the account', (tester) async {
    await _openSettings(tester);

    expect(find.text('Pauline'), findsOneWidget);
    expect(find.text('p@example.com'), findsOneWidget);
  });

  testWidgets('choosing a language saves it and switches the app', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Language');

    // By key: French names itself only once its translations are pulled.
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateLocale(fr)']);
    final context = tester.element(find.byType(SettingsPage));
    expect(Localizations.localeOf(context), const Locale('fr'));

    // The screen itself is now in French.
    final fr = lookupAppLocalizations(const Locale('fr'));
    await tester.tap(find.text(fr.settingsLanguageSystem));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'updateLocale(null)');
  });

  testWidgets('sign out asks the repository', (tester) async {
    final fake = await _openSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signOut()']);
  });

  testWidgets('delete asks first; cancel deletes nothing', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });

  testWidgets('confirmed delete removes the account and lands on welcome', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['deleteAccount()']);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a failed delete says so and stays', (tester) async {
    final fake = await _openSection(tester, 'Pauline');
    fake.failWith = AuthFailure.network;

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Loomia. Check your connection.'),
      findsOneWidget,
    );
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('the list shows the language and appearance in use', (
    tester,
  ) async {
    await _openSettings(tester);

    expect(find.text('Same as this device'), findsNWidgets(2));
  });

  testWidgets('choosing dark saves it and switches the app', (tester) async {
    final fake = await _openSection(tester, 'Appearance');

    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateAppearance(dark)']);
    final context = tester.element(find.byType(SettingsPage));
    expect(Theme.of(context).brightness, Brightness.dark);

    await tester.tap(find.byKey(const ValueKey('appearance-system')));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'updateAppearance(system)');
    // The test device is light.
    expect(Theme.of(context).brightness, Brightness.light);
  });

  group('your photo', () {
    Future<void> tapMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byType(AvatarControl));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('a Google picture shows; nothing to remove until an upload', (
      tester,
    ) async {
      final auth = await _openSettings(
        tester,
        googlePicture: 'https://lh3.googleusercontent.com/a/abc=s96-c',
        picker: FakePhotoPicker(jpegBytes),
      );
      await tester.tap(find.text('Pauline'));
      await tester.pumpAndSettle();
      final control = find.byType(AvatarControl);
      expect(tester.widget<AvatarControl>(control).photo, isA<NetworkImage>());

      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsNothing);
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      await tapMenu(tester, 'Remove photo');

      expect(auth.calls, [
        'updateAvatarPath(u1/new)',
        'updateAvatarPath(null)',
      ]);
      // Back to Google's.
      expect(
        (tester.widget<AvatarControl>(control).photo! as NetworkImage).url,
        'https://lh3.googleusercontent.com/a/abc=s256-c',
      );
    });

    testWidgets('choose then remove: saved on the account, files swapped', (
      tester,
    ) async {
      final photos = FakePhotoRepository();
      await _openSettings(
        tester,
        photos: photos,
        picker: FakePhotoPicker(jpegBytes),
      );
      await tester.tap(find.text('Pauline'));
      await tester.pumpAndSettle();

      await tapMenu(tester, 'Choose photo');
      await tapMenu(tester, 'Remove photo');

      expect(photos.calls, ['upload(image/jpeg)', 'discard(u1/new)']);
    });

    testWidgets('the account remembers the path', (tester) async {
      final auth = await _openSettings(
        tester,
        picker: FakePhotoPicker(jpegBytes),
      );
      await tester.tap(find.text('Pauline'));
      await tester.pumpAndSettle();

      await tapMenu(tester, 'Choose photo');
      await tapMenu(tester, 'Remove photo');

      expect(auth.calls, [
        'updateAvatarPath(u1/new)',
        'updateAvatarPath(null)',
      ]);
    });

    testWidgets('a failed save says so and discards the upload', (
      tester,
    ) async {
      final photos = FakePhotoRepository();
      final auth = await _openSettings(
        tester,
        photos: photos,
        picker: FakePhotoPicker(jpegBytes),
      );
      await tester.tap(find.text('Pauline'));
      await tester.pumpAndSettle();
      auth.failWith = AuthFailure.network;

      await tapMenu(tester, 'Choose photo');

      expect(
        find.text('We could not reach Loomia. Check your connection.'),
        findsOneWidget,
      );
      expect(photos.calls, ['upload(image/jpeg)', 'discard(u1/new)']);
    });

    testWidgets('a refused upload says so', (tester) async {
      final photos = FakePhotoRepository()..failWith = PeopleFailure.unknown;
      await _openSettings(
        tester,
        photos: photos,
        picker: FakePhotoPicker(jpegBytes),
      );
      await tester.tap(find.text('Pauline'));
      await tester.pumpAndSettle();

      await tapMenu(tester, 'Choose photo');

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    for (final (label, size) in [
      ('mobile', const Size(390, 844)),
      ('desktop', const Size(1440, 900)),
    ]) {
      testWidgets('$label: the shell and the list show it', (tester) async {
        await _openSettings(tester, size: size, avatarPath: 'u1/me');

        final withPhoto = find.byWidgetPredicate(
          (widget) => widget is LoomiaAvatar && widget.photo != null,
        );
        // The list's leading avatar, and the sidebar (desktop) or the top
        // bar (mobile, hidden on Settings, so only the list there).
        expect(withPhoto, findsAtLeastNWidgets(size.width > 1000 ? 2 : 1));
      });
    }
  });

  testWidgets('editing the name saves it', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('First name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Paula ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateFirstName(Paula)']);
    expect(find.text('Paula'), findsOneWidget);
  });

  testWidgets('an empty name is refused', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('First name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('the account shows the company; choosing one saves it', (
    tester,
  ) async {
    final fake = await _openSection(tester, 'Pauline');
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    expect(find.text('Which company do you work with?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('business-model-doterra')));
    await tester.pumpAndSettle();

    expect(fake.calls, ['updateBusinessModel(doterra)']);
    expect(fake.account!.businessModel, BusinessModel.doterra);
    expect(find.text('dōTERRA'), findsOneWidget);
  });

  testWidgets('picking the company already set saves nothing', (tester) async {
    final fake = await _openSection(tester, 'Pauline');

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('business-model-other')));
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
  });

  testWidgets('mobile: delete confirms in a bottom sheet', (tester) async {
    await _openSection(tester, 'Pauline');
    // A gesture/navigation bar at the bottom of the screen.
    tester.view.padding = const FakeViewPadding(bottom: 48);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Cancel')).dy, lessThan(844 - 48));
  });

  testWidgets('desktop: the list beside the open section', (tester) async {
    await _openSettings(tester, size: const Size(1440, 900));

    // Account is open until another section is chosen.
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('desktop: delete confirms in a dialog', (tester) async {
    await _openSettings(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('tablet: a section opens on its own screen', (tester) async {
    await _openSettings(tester, size: const Size(800, 1000));

    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });
}
