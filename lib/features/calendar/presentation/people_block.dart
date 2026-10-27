import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/team/presentation/check_in_items.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The people due on a day, in the Calendar (#378): Catch up's pattern, a
/// `PEOPLE` header, then one row per person. [foldable] (mobile) starts
/// folded, one summary line, with Show / Hide; otherwise (the desktop
/// popover) the rows always show. Look only: no ring, a row opens the
/// person. Callers key it by day, so another day starts folded again.
class PeopleBlock extends StatefulWidget {
  const PeopleBlock({
    required this.people,
    required this.model,
    required this.onOpen,
    this.foldable = true,
    super.key,
  });

  /// One run of Due items per person, as `PeopleAhead.on`; not empty.
  final List<List<Due>> people;
  final BusinessModel model;
  final void Function(Person person) onOpen;
  final bool foldable;

  @override
  State<PeopleBlock> createState() => _PeopleBlockState();
}

class _PeopleBlockState extends State<PeopleBlock> {
  bool _folded = true;

  void _toggle() => setState(() => _folded = !_folded);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final folded = widget.foldable && _folded;
    final people = widget.people;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.calendarPeopleSection,
          actionLabel: !widget.foldable
              ? null
              : folded
              ? l10n.todayCatchUpShow
              : l10n.todayCatchUpHide,
          onAction: widget.foldable ? _toggle : null,
        ),
        FoldBody(
          folded: folded,
          summary: PeopleSummary(
            names: [for (final run in people) run.first.person.name],
            label: l10n.calendarPeopleSummary(people.length),
            onTap: _toggle,
          ),
          rows: [for (final run in people) _row(l10n, run)],
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l10n, List<Due> run) {
    final person = run.first.person;
    final reason = dueReason(l10n, widget.model, run.first);
    return ActionItem(
      name: person.name,
      photoPath: person.photoPath,
      reason: run.length > 1
          ? l10n.calendarPeopleMore(reason, run.length - 1)
          : reason,
      tag: LoomiaChip(label: stageLabel(l10n, person.stage)),
      onOpen: () => widget.onOpen(person),
    );
  }
}
