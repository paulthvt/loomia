import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `tag` table (#332). Every method throws `PeopleFailure` and nothing
/// else. RLS scopes everything to the user. Who has a tag is written through
/// `PeopleRepository.setTags`.
class TagRepository {
  TagRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'tag';
  static const String _columns = 'id, name, color';

  /// Unordered: the controller sorts by `searchKey`.
  Future<List<Tag>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select(_columns);
    return rows.map(tagFromRow).toList();
  });

  Future<Tag> add(String name, TagColor color) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert({'name': name.trim(), 'color': color.name})
        .select(_columns)
        .single();
    return tagFromRow(row);
  });

  /// Renames and recolours [tag] for everyone who has it.
  Future<void> update(Tag tag) => guardPeople(() async {
    await _client
        .from(_table)
        .update({'name': tag.name.trim(), 'color': tag.color.name})
        .eq('id', tag.id);
  });

  /// Takes it off everyone who has it.
  Future<void> delete(String id) => guardPeople(() async {
    await _client.from(_table).delete().eq('id', id);
  });
}

Tag tagFromRow(Map<String, dynamic> row) => Tag(
  id: row['id'] as String,
  name: row['name'] as String,
  color: TagColor.values.byName(row['color'] as String),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepository(ref.watch(supabaseClientProvider)),
);
