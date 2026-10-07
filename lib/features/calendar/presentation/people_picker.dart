import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// People to invite: [people] (the book, sorted by name) without [except],
/// searchable, several at once. A sheet on mobile, a dialog elsewhere.
/// Resolves to the ids picked, or null when dismissed.
Future<Set<String>?> pickPeople(
  BuildContext context, {
  required List<Person> people,
  Set<String> except = const {},
}) => LoomiaDialog.show<Set<String>>(
  context,
  (_) => _PeoplePicker(
    people: [
      for (final person in people)
        if (!except.contains(person.id)) person,
    ],
  ),
);

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.people});

  final List<Person> people;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  final Set<String> _picked = {};
  String _query = '';

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = searchKey(_query);
    // ponytail: builds every row, inside the dialog's scroll view; a lazy
    // list if a book of thousands makes the sheet slow to open.
    final shown = query.isEmpty
        ? widget.people
        : [
            for (final person in widget.people)
              if (searchKey(person.name).contains(query)) person,
          ];

    return LoomiaDialog(
      title: l10n.peoplePickerTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, {..._picked}),
          child: Text(l10n.peoplePickerAdd(_picked.length)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          TextField(
            textInputAction: TextInputAction.search,
            decoration: AppTheme.search(context).copyWith(
              hintText: l10n.peoplePickerSearch,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.peoplePickerNobody,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LoomiaColors.of(context).textMuted),
              ),
            )
          else
            for (final person in shown)
              ContactRow(
                name: person.name,
                subtitle: stageLabel(l10n, person.stage),
                checked: _picked.contains(person.id),
                onTap: () => _toggle(person.id),
              ),
        ],
      ),
    );
  }
}
