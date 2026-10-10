import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/stage_filter.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The book: search, stage filter, one row per person, sorted by name. A long
/// press, or Select where there is a mouse, starts picking several people to
/// move, change the workflow of, or delete at once (#180).
///
/// A pure function of [people]; the search text, the filter and who is picked
/// are this widget's own state.
class ContactList extends StatefulWidget {
  const ContactList({
    required this.people,
    required this.onOpen,
    required this.onAdd,
    required this.onRefresh,
    required this.onMove,
    required this.onChangeWorkflow,
    required this.onDelete,
    required this.model,
    this.onImport,
    this.selectedId,
    this.showRefresh = false,
    this.onPickingChanged,
    this.accountAction,
    super.key,
  });

  final List<Person> people;
  final ValueChanged<Person> onOpen;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  /// These three act on the picked people and complete with whether it was
  /// done; done, the picking ends. [onMove] gets only those not in the stage
  /// already, [onChangeWorkflow] only people all in one stage. [onDelete] is
  /// called once the user confirmed.
  final Future<bool> Function(List<Person> people, Stage stage) onMove;
  final Future<bool> Function(List<Person> people) onChangeWorkflow;
  final Future<bool> Function(List<Person> people) onDelete;

  /// Words the LRP chip.
  final BusinessModel model;

  /// Import from the phone's contacts; null where there is no address book
  /// to read (the web).
  final VoidCallback? onImport;

  /// The person open beside the list, on desktop.
  final String? selectedId;

  /// A refresh button, where a mouse cannot pull.
  final bool showRefresh;

  /// Hears picking start and end: the bottom navigation gives way to the
  /// picked people's actions meanwhile.
  final ValueChanged<bool>? onPickingChanged;

  /// Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  String _query = '';

  /// Null is everyone.
  Stage? _stage;

  /// Only people with an LRP; applies while the chip shows.
  bool _loyalty = false;

  /// The ids picked; null while not picking. Kept through search and filter
  /// changes, so a filter then Select all picks a whole stage.
  Set<String>? _picked;

  /// Every change to [_picked] goes through here, so [ContactList.
  /// onPickingChanged] hears each start and end.
  void _setPicked(Set<String>? picked) {
    final changed = (picked == null) != (_picked == null);
    setState(() => _picked = picked);
    if (changed) widget.onPickingChanged?.call(picked != null);
  }

  void _toggle(String id) {
    final picked = {...?_picked};
    if (!picked.remove(id)) picked.add(id);
    // Unpicking the last one ends the picking.
    _setPicked(picked.isEmpty ? null : picked);
  }

  Future<void> _done(Future<bool> action) async {
    if (await action && mounted) _setPicked(null);
  }

  @override
  void dispose() {
    // Gone while picking (a layout change, a deep link): the picking ends
    // too. After the frame: listeners may rebuild.
    final onPickingChanged = widget.onPickingChanged;
    if (_picked != null && onPickingChanged != null) {
      Future.microtask(() => onPickingChanged(false));
    }
    super.dispose();
  }

  Future<void> _confirmDelete(List<Person> picked) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: switch (picked) {
        [final person] => l10n.contactDeleteTitle(person.name),
        _ => l10n.contactsDeleteManyTitle(picked.length),
      },
      body: l10n.contactDeleteBody,
      action: l10n.contactDeleteConfirm,
    );
    if (confirmed && mounted) await _done(widget.onDelete(picked));
  }

  Future<void> _moveTo(List<Person> picked) async {
    final stage = await _pickStage(context, picked);
    if (stage == null || !mounted) return;
    await _done(
      widget.onMove([
        for (final person in picked)
          if (person.stage != stage) person,
      ], stage),
    );
  }

  /// What can be done with the picked people: Move to…, Change workflow (only
  /// for people in one stage — workflows belong to a stage), Delete.
  List<_PickedAction> _actions(AppLocalizations l10n, List<Person> picked) {
    final stages = {for (final person in picked) person.stage};
    return [
      (
        label: l10n.contactsMoveSelected,
        short: l10n.contactsMoveSelected,
        icon: Icons.swap_horiz_rounded,
        destructive: false,
        onTap: picked.isEmpty ? null : () => _moveTo(picked),
      ),
      (
        label: l10n.contactChangeWorkflow,
        short: l10n.contactsWorkflowSelected,
        icon: Icons.alt_route_rounded,
        destructive: false,
        onTap: stages.length == 1
            ? () => _done(widget.onChangeWorkflow(picked))
            : null,
      ),
      (
        label: l10n.contactsDeleteSelected,
        short: l10n.contactsDeleteSelected,
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onTap: picked.isEmpty ? null : () => _confirmDelete(picked),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final people = widget.people;
    final query = searchKey(_query);
    // The chip shows once anyone has an LRP; stopping the last one never
    // leaves the list filtered behind a hidden chip.
    final anyLoyalty = people.any((person) => person.loyaltySince != null);
    final shown = [
      for (final person in people)
        if (StageFilter.shows(
              _stage,
              person,
              loyalty: _loyalty && anyLoyalty,
            ) &&
            searchKey(person.name).contains(query))
          person,
    ];
    final account = widget.accountAction;
    final desktop = context.screenSize.isDesktop;
    final sideNavigation = context.screenSize.usesSideNavigation;
    final pickedIds = _picked;
    // From the whole book: someone picked stays picked when filtered out, and
    // someone deleted elsewhere drops out.
    final picked = pickedIds == null
        ? null
        : [
            for (final person in people)
              if (pickedIds.contains(person.id)) person,
          ];
    final actions = picked == null ? null : _actions(l10n, picked);

    final list = RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        // Pull to refresh works on a short list too.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(desktop ? AppSpacing.lg : AppSpacing.md),
        children: [
          if (picked != null) ...[
            _PickingHeader(
              count: picked.length,
              onSelectAll: () => _setPicked({
                ...?_picked,
                for (final person in shown) person.id,
              }),
              onClose: () => _setPicked(null),
            ),
            // With a mouse the actions sit under the header; on a phone they
            // take the bottom bar's place.
            if (sideNavigation && actions != null) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final action in actions)
                    if (action.destructive)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: action.onTap,
                        icon: Icon(action.icon),
                        label: Text(action.short),
                      )
                    else
                      FilledButton.tonalIcon(
                        style: AppTheme.tonal(context),
                        onPressed: action.onTap,
                        icon: Icon(action.icon),
                        label: Text(action.short),
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ] else
            LoomiaTopBar(
              title: l10n.contactsTitle,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sideNavigation && people.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _setPicked({}),
                      icon: const Icon(Icons.checklist_rounded),
                      label: Text(l10n.contactsSelect),
                    ),
                  if (widget.onImport case final onImport?)
                    IconButton(
                      onPressed: onImport,
                      tooltip: l10n.contactsImport,
                      icon: const Icon(Icons.contacts_outlined),
                    ),
                  if (widget.showRefresh)
                    IconButton(
                      onPressed: widget.onRefresh,
                      tooltip: l10n.contactsRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  if (desktop)
                    FilledButton.icon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(l10n.contactsAddShort),
                    )
                  else
                    IconButton.filledTonal(
                      onPressed: widget.onAdd,
                      tooltip: l10n.contactsAdd,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                    ),
                  ?account,
                ],
              ),
            ),
          if (people.isEmpty) ...[
            EmptyState(
              icon: Icons.people_outline,
              title: l10n.contactsEmptyTitle,
              body: l10n.contactsEmptyBody,
              actionLabel: l10n.contactsAdd,
              onAction: widget.onAdd,
            ),
            if (widget.onImport case final onImport?)
              Center(
                child: TextButton(
                  onPressed: onImport,
                  child: Text(l10n.contactsImport),
                ),
              ),
          ] else ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: AppTheme.search(context).copyWith(
                hintText: l10n.contactsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.ms),
            StageFilter(
              value: _stage,
              onChanged: (stage) => setState(() => _stage = stage),
              loyaltyLabel: anyLoyalty
                  ? l10n.loyaltyLabel(widget.model.name)
                  : null,
              loyalty: _loyalty,
              onLoyaltyChanged: (on) => setState(() => _loyalty = on),
            ),
            const SizedBox(height: AppSpacing.ms),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.contactsNoMatch,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: LoomiaColors.of(context).textMuted),
                ),
              )
            else
              for (final person in shown)
                ContactRow(
                  name: person.name,
                  photoPath: person.photoPath,
                  subtitle: contactSubtitle(l10n, person),
                  trailing: LoomiaChip(label: stageLabel(l10n, person.stage)),
                  selected: person.id == widget.selectedId,
                  checked: pickedIds?.contains(person.id),
                  onTap: pickedIds == null
                      ? () => widget.onOpen(person)
                      : () => _toggle(person.id),
                  onLongPress: () => _toggle(person.id),
                ),
          ],
        ],
      ),
    );

    return PopScope(
      // Back ends the picking first.
      canPop: picked == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setPicked(null);
      },
      child: !sideNavigation && actions != null
          ? Column(
              children: [
                Expanded(child: list),
                _PickedBar(actions: actions),
              ],
            )
          : list,
    );
  }
}

typedef _PickedAction = ({
  String label,

  /// Where a row of buttons has less room: "Workflow".
  String short,
  IconData icon,
  bool destructive,

  /// Null is disabled.
  VoidCallback? onTap,
});

/// ✕ · "2 selected" · Select all, on one line.
class _PickingHeader extends StatelessWidget {
  const _PickingHeader({
    required this.count,
    required this.onSelectAll,
    required this.onClose,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: l10n.contactsStopSelecting,
            icon: const Icon(Icons.close_rounded),
          ),
          Expanded(
            child: Text(
              l10n.contactsSelected(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(l10n.contactsSelectAll),
          ),
        ],
      ),
    );
  }
}

/// Takes the bottom navigation's place on a phone while picking: each action
/// an icon over its label, like a destination.
class _PickedBar extends StatelessWidget {
  const _PickedBar({required this.actions});

  final List<_PickedAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final nav = NavigationBarTheme.of(context);
    return Material(
      color: nav.backgroundColor,
      child: SizedBox(
        height: nav.height,
        child: Row(
          children: [
            for (final action in actions)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final color = action.onTap == null
                        ? colors.textDisabled
                        : action.destructive
                        ? scheme.error
                        : scheme.onSurface;
                    return InkWell(
                      onTap: action.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: AppSpacing.xs,
                        children: [
                          Icon(action.icon, color: color),
                          Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nav.labelTextStyle
                                ?.resolve({})
                                ?.copyWith(color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Where to move [picked]: only the stages someone picked is not in. Null when
/// dismissed.
Future<Stage?> _pickStage(BuildContext context, List<Person> picked) {
  final l10n = AppLocalizations.of(context);
  return LoomiaDialog.show<Stage>(
    context,
    (context) => LoomiaDialog(
      title: l10n.contactsMoveManyTitle(picked.length),
      body: l10n.contactsMoveManyBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (stage, label) in [
            (Stage.prospect, l10n.contactsFilterProspects),
            (Stage.customer, l10n.contactsFilterCustomers),
            (Stage.team, l10n.contactsFilterTeam),
          ])
            if (picked.where((person) => person.stage != stage).length
                case final moving when moving > 0)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(label),
                // Said only when some are there already.
                subtitle: moving == picked.length
                    ? null
                    : Text(l10n.contactsMovePartly(moving, picked.length)),
                onTap: () => Navigator.pop(context, stage),
              ),
        ],
      ),
    ),
  );
}
