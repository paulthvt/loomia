import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';

/// A label the user puts on people (#332): "Lyon", "Workshop May". A group
/// is everyone with a tag.
class Tag {
  const Tag({required this.id, required this.name, required this.color});

  final String id;

  /// 1 to 32 characters, unique per account ignoring case and accents.
  final String name;
  final TagColor color;

  static const int maxName = 32;
}

/// The colour a new tag gets: the first palette key no tag uses; all used,
/// the first.
TagColor nextTagColor(Iterable<Tag> tags) {
  final used = {for (final tag in tags) tag.color};
  return TagColor.values.firstWhere(
    (color) => !used.contains(color),
    orElse: () => TagColor.values.first,
  );
}

/// Whether a tag other than [except] already has [name], ignoring case,
/// accents and surrounding spaces.
bool tagNameTaken(String name, Iterable<Tag> tags, {String? except}) {
  final key = searchKey(name);
  return tags.any((tag) => tag.id != except && searchKey(tag.name) == key);
}

/// A checkbox's value over [people]: true when all have [tag], false when
/// none do, null when some do.
bool? tagState(Tag tag, List<Person> people) {
  final having = people.where((p) => p.tagIds.contains(tag.id)).length;
  if (having == 0) return false;
  return having == people.length ? true : null;
}

/// [ids] resolved through [tags], in [tags]' order; an id with no tag (deleted
/// on another device) is left out.
List<Tag> tagsOf(Set<String> ids, List<Tag> tags) => [
  for (final tag in tags)
    if (ids.contains(tag.id)) tag,
];
