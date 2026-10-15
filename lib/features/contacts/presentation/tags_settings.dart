import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/tags_controller.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// How many of [people] have [tag]: counted from the loaded book, so the
/// list and the delete confirmation need no query of their own.
int peopleWithTag(Tag tag, List<Person> people) =>
    people.where((person) => person.tagIds.contains(tag.id)).length;

/// Settings → Tags (#332): every tag with how many people have it, and New
/// tag. A row opens the tag editor.
class TagsSettings extends ConsumerWidget {
  const TagsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    final tags = tagsProvider(owner);
    final state = ref.watch(tags);
    final list = state.value;
    if (list == null) {
      return state.hasError
          ? LoadFailed(
              offline: state.error == PeopleFailure.network,
              title: l10n.nextStepLoadFailed,
              onRetry: () => ref.invalidate(tags),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            );
    }
    final people = ref.watch(peopleProvider(owner)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isNotEmpty) ...[
          SettingsGroup(
            children: [
              for (final tag in list)
                ListTile(
                  leading: TagDot(color: tag.color, size: 12),
                  title: Text(tag.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(l10n.tagsPeopleCount(peopleWithTag(tag, people))),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => unawaited(showTagEditor(context, tag)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FilledButton.tonalIcon(
          onPressed: () => unawaited(showTagEditor(context, null)),
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.tagNew),
        ),
      ],
    );
  }
}

/// Creates a tag ([tag] null) or renames, recolours and deletes [tag], for
/// everyone who has it.
Future<void> showTagEditor(BuildContext context, Tag? tag) =>
    LoomiaDialog.show<void>(context, (_) => _TagEditor(tag));

class _TagEditor extends ConsumerStatefulWidget {
  const _TagEditor(this.tag);

  final Tag? tag;

  @override
  ConsumerState<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<_TagEditor> {
  late final _name = TextEditingController(text: widget.tag?.name);
  TagColor? _color;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _write(Future<void> Function() write) async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await write();
      if (mounted) Navigator.pop(context);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  Future<void> _save(TagColor color) {
    final name = _name.text.trim();
    return _write(
      () => editTags(ref, (repository) async {
        if (widget.tag case final tag?) {
          await repository.update(Tag(id: tag.id, name: name, color: color));
        } else {
          await repository.add(name, color);
        }
      }),
    );
  }

  Future<void> _delete(Tag tag) async {
    final l10n = AppLocalizations.of(context);
    final people =
        ref.read(peopleProvider(ref.read(accountProvider)?.email)).value ??
        const [];
    final confirmed = await confirmDestructive(
      context,
      title: l10n.tagDeleteTitle(tag.name, peopleWithTag(tag, people)),
      body: l10n.tagDeleteBody,
      action: l10n.tagDelete,
    );
    if (!confirmed || !mounted) return;
    await _write(
      () => editTags(ref, (repository) => repository.delete(tag.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final tag = widget.tag;
    final tags = watchTags(ref);
    final color = _color ?? tag?.color ?? nextTagColor(tags);
    final name = _name.text.trim();
    final taken = tagNameTaken(name, tags, except: tag?.id);
    final canSave = !_saving && name.isNotEmpty && !taken;

    return LoomiaDialog(
      title: tag?.name ?? l10n.tagNew,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: canSave ? () => _save(color) : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(material.saveButtonLabel),
        ),
      ],
      footer: tag == null
          ? null
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving ? null : () => _delete(tag),
              child: Text(l10n.tagDelete),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.ms,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          LabeledField(
            label: l10n.tagNameLabel,
            child: TextField(
              controller: _name,
              autofocus: tag == null,
              maxLength: Tag.maxName,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                errorText: taken ? l10n.tagNameInUse(name) : null,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final key in TagColor.values)
                _Swatch(
                  color: key,
                  selected: key == color,
                  label: tagColorName(l10n, key),
                  onTap: () => setState(() => _color = key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One palette colour, ringed when picked.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final TagColor color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    final tag = color.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: kMinInteractiveDimension / 2,
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Center(
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: tag.container,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : tag.ink,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 18, color: tag.ink)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
