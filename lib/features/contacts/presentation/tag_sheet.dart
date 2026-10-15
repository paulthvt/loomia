import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/tags_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Ticks [people]'s tags (#332): a sheet on mobile, a dialog elsewhere. Done
/// writes once for all of them; closing any other way writes nothing. With
/// several people a box can be mixed, and a mixed box left alone changes
/// nothing. Completes with whether it was saved.
Future<bool> showTagSheet(BuildContext context, List<Person> people) async =>
    await LoomiaDialog.show<bool>(context, (_) => _TagSheet(people)) ?? false;

class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet(this.people);

  final List<Person> people;

  @override
  ConsumerState<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<_TagSheet> {
  final _search = TextEditingController();

  /// The boxes the user changed, by tag id; absent is as it was.
  final Map<String, bool> _changed = {};

  /// Created here, shown before the tags reload with them.
  final List<Tag> _created = [];
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool? _value(Tag tag) => _changed[tag.id] ?? tagState(tag, widget.people);

  /// Unchanged → its opposite; a box that started mixed goes ticked, empty,
  /// then mixed again (no change).
  void _toggle(Tag tag) {
    final initial = tagState(tag, widget.people);
    setState(() {
      switch ((initial, _changed[tag.id])) {
        case (null, null):
          _changed[tag.id] = true;
        case (null, true):
          _changed[tag.id] = false;
        case (null, false):
          _changed.remove(tag.id);
        case (final bool start, _):
          final next = !(_value(tag) ?? start);
          if (next == start) {
            _changed.remove(tag.id);
          } else {
            _changed[tag.id] = next;
          }
      }
    });
  }

  Future<void> _create(String name, List<Tag> tags) async {
    setState(() => _failure = null);
    try {
      final tag = await editTags(
        ref,
        (repository) => repository.add(name, nextTagColor(tags)),
      );
      if (!mounted) return;
      setState(() {
        _created.add(tag);
        _changed[tag.id] = true;
        _search.clear();
      });
    } on PeopleFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .setTags(
            widget.people,
            {
              for (final MapEntry(:key, :value) in _changed.entries)
                if (value) key,
            },
            {
              for (final MapEntry(:key, :value) in _changed.entries)
                if (!value) key,
            },
          );
      if (mounted) Navigator.pop(context, true);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final loaded = watchTags(ref);
    final tags = sortedTags([
      ...loaded,
      for (final tag in _created)
        if (!loaded.any((other) => other.id == tag.id)) tag,
    ]);
    final text = _search.text.trim();
    final query = searchKey(text);
    final shown = [
      for (final tag in tags)
        if (searchKey(tag.name).contains(query)) tag,
    ];
    final canCreate =
        text.isNotEmpty &&
        text.length <= Tag.maxName &&
        !tagNameTaken(text, tags);
    final many = widget.people.length > 1;

    return LoomiaDialog(
      title: many ? l10n.tagsTitleMany(widget.people.length) : l10n.tagsTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.tagsDone),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            maxLength: Tag.maxName,
            textInputAction: TextInputAction.done,
            onSubmitted: canCreate ? (_) => _create(text, tags) : null,
            decoration: AppTheme.search(context).copyWith(
              hintText: l10n.tagsSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              counterText: '',
            ),
          ),
          if (canCreate)
            ListTile(
              leading: TagDot(color: nextTagColor(tags), size: 12),
              title: Text(l10n.tagsCreate(text)),
              onTap: () => _create(text, tags),
            ),
          if (tags.isEmpty && text.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l10n.tagsEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LoomiaColors.of(context).textMuted),
              ),
            ),
          for (final tag in shown)
            CheckboxListTile(
              value: _value(tag),
              tristate: many,
              onChanged: (_) => _toggle(tag),
              secondary: TagDot(color: tag.color, size: 12),
              title: Text(tag.name),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
        ],
      ),
    );
  }
}
