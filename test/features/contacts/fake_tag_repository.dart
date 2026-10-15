import 'dart:async';

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/data/tag_repository.dart';
import 'package:loomia/features/contacts/domain/tag.dart';

/// An in-memory `tag` table that records calls, and fails or stalls on
/// demand.
class FakeTagRepository implements TagRepository {
  FakeTagRepository([Iterable<Tag> tags = const []]) {
    for (final tag in tags) {
      store[tag.id] = tag;
    }
  }

  final Map<String, Tag> store = {};

  /// One entry per call, e.g. `add(Lyon, sage)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  var _next = 0;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Tag>> list() async {
    await _record('list');
    return store.values.toList();
  }

  @override
  Future<Tag> add(String name, TagColor color) async {
    await _record('add(${name.trim()}, ${color.name})');
    final tag = Tag(id: 'new-${_next++}', name: name.trim(), color: color);
    return store[tag.id] = tag;
  }

  @override
  Future<void> update(Tag tag) async {
    await _record('update(${tag.id}, ${tag.name}, ${tag.color.name})');
    store[tag.id] = tag;
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.remove(id);
  }
}
