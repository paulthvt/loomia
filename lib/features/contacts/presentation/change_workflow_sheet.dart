import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/follow_with_field.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Picks what [people] follow next, in one write: a sheet on mobile, a dialog
/// elsewhere. Saving starts the picked workflow from its first step, even the
/// current one. Closes once saved, and completes with whether it was. They
/// must all be in the same stage: the workflows offered are that stage's.
Future<bool> showChangeWorkflow(
  BuildContext context,
  List<Person> people,
) async =>
    await LoomiaDialog.show<bool>(context, (_) => _ChangeWorkflow(people)) ??
    false;

class _ChangeWorkflow extends ConsumerStatefulWidget {
  const _ChangeWorkflow(this.people);

  final List<Person> people;

  @override
  ConsumerState<_ChangeWorkflow> createState() => _ChangeWorkflowState();
}

class _ChangeWorkflowState extends ConsumerState<_ChangeWorkflow> {
  /// Null until the user picks; see Change stage.
  ({FollowWith? follow})? _picked;
  bool _saving = false;
  PeopleFailure? _failure;

  Stage get _stage => widget.people.first.stage;

  /// The workflow they all follow, if they follow the same one.
  String? get _shared {
    final ids = {for (final person in widget.people) person.place?.workflowId};
    return ids.length == 1 ? ids.single : null;
  }

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested =
        findWorkflow(workflows, _shared) ?? defaultFor(workflows, _stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }

  Future<void> _save(FollowWith? follow) async {
    // Close without writing when nothing was picked and they all already
    // follow what is shown.
    if (_picked == null && follow?.workflow.id == _shared) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .setWorkflow(widget.people, follow);
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
    final owner = ref.watch(accountProvider)?.email;
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);

    return LoomiaDialog(
      title: switch (widget.people) {
        [final person] => l10n.changeWorkflowTitle(firstName(person)),
        final people => l10n.changeWorkflowTitleMany(people.length),
      },
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(follow),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(material.saveButtonLabel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.ms,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          FollowWithField(
            workflows: forStage(workflows, _stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
          ),
        ],
      ),
    );
  }
}
