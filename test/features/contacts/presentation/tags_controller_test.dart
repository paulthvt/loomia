import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/data/tag_repository.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/tags_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_tag_repository.dart';

void main() {
  test(
    'loads sorted by name, accents and case ignored; edit reloads',
    () async {
      final auth = FakeAuthRepository()
        ..session = true
        ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
      addTearDown(auth.dispose);
      final repository = FakeTagRepository(const [
        Tag(id: 's', name: 'sleep', color: TagColor.sky),
        Tag(id: 'e', name: 'Été', color: TagColor.sand),
        Tag(id: 'l', name: 'Lyon', color: TagColor.sage),
      ]);
      final container = ProviderContainer.test(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          tagRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final tags = tagsProvider('p@example.com');

      expect(
        [for (final t in await container.read(tags.future)) t.name],
        ['Été', 'Lyon', 'sleep'],
      );

      await container
          .read(tags.notifier)
          .edit((r) => r.add('Atelier', TagColor.teal));

      expect(
        [for (final t in await container.read(tags.future)) t.name].first,
        'Atelier',
      );
    },
  );
}
