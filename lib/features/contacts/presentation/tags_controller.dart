import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/tag_repository.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/domain/tag.dart';

/// One account's tags (#332), `tagsProvider(account?.email)`, sorted by
/// [searchKey] of the name. Keyed by account like `peopleProvider`. No
/// automatic retry.
final tagsProvider =
    AsyncNotifierProvider.family<TagsController, List<Tag>, String?>(
      TagsController.new,
      retry: (error, _) => null,
    );

class TagsController extends AsyncNotifier<List<Tag>> {
  TagsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<Tag>> build() async {
    final repository = ref.watch(tagRepositoryProvider);
    if (owner == null) return const [];
    return sortedTags(await repository.list());
  }

  /// Runs [write], then reloads. Rethrows its `PeopleFailure`.
  Future<T> edit<T>(Future<T> Function(TagRepository repository) write) async {
    final result = await write(ref.read(tagRepositoryProvider));
    if (ref.mounted) ref.invalidateSelf();
    return result;
  }
}

List<Tag> sortedTags(Iterable<Tag> tags) =>
    [...tags]..sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));

/// The signed-in account's tags; empty while loading or failed, so a screen
/// never waits on them.
List<Tag> watchTags(WidgetRef ref) =>
    ref.watch(tagsProvider(ref.watch(accountProvider)?.email)).value ??
    const [];

/// [TagsController.edit] on the signed-in account, read at call time.
Future<T> editTags<T>(
  WidgetRef ref,
  Future<T> Function(TagRepository repository) write,
) => ref
    .read(tagsProvider(ref.read(accountProvider)?.email).notifier)
    .edit(write);
