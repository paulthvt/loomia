import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/presentation/account_photo.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/photos/fake_photo_repository.dart';

const _google = 'https://lh3.googleusercontent.com/a/abc=s96-c';

Future<ImageProvider?> _photo(Account account) async {
  final container = ProviderContainer.test(
    overrides: [
      accountProvider.overrideWithValue(account),
      photoRepositoryProvider.overrideWithValue(FakePhotoRepository()),
    ],
  );
  // The signed URL arrives asynchronously.
  if (account.avatarPath case final path?) {
    await container.read(photoUrlProvider(path).future);
  }
  return container.read(accountPhotoProvider);
}

void main() {
  group('googlePictureAt', () {
    test('asks for the size wanted', () {
      expect(
        googlePictureAt(_google, 256),
        'https://lh3.googleusercontent.com/a/abc=s256-c',
      );
      expect(
        googlePictureAt('https://lh3.googleusercontent.com/a/abc=s96', 256),
        'https://lh3.googleusercontent.com/a/abc=s256-c',
      );
    });

    test('a URL without a size is left as it is', () {
      const plain = 'https://example.com/me.png';
      expect(googlePictureAt(plain, 256), plain);
    });
  });

  group('accountPhotoProvider', () {
    test('the uploaded photo first', () async {
      final photo = await _photo(
        const Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          avatarPath: 'u1/me',
          googlePicture: _google,
        ),
      );

      expect((photo! as NetworkImage).url, 'https://photos.test/u1/me');
    });

    test('else the Google picture, at 256 px', () async {
      final photo = await _photo(
        const Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          googlePicture: _google,
        ),
      );

      expect(
        (photo! as NetworkImage).url,
        'https://lh3.googleusercontent.com/a/abc=s256-c',
      );
    });

    test('else none: initials', () async {
      final photo = await _photo(
        const Account(firstName: 'Pauline', email: 'p@example.com'),
      );

      expect(photo, isNull);
    });
  });
}
