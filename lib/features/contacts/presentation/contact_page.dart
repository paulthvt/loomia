import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/photos/photo_picker.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/report_view.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/contacts/presentation/contact_details.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/edit_person_form.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/history_section.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/contacts/presentation/loyalty_sheet.dart';
import 'package:loomia/features/contacts/presentation/next_step_section.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/tag_sheet.dart';
import 'package:loomia/features/contacts/presentation/tags_controller.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/presentation/contact_sharing_controller.dart';
import 'package:loomia/features/sharing/presentation/invite_sheet.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One person on mobile and tablet: a screen of its own above the list.
class ContactPage extends StatelessWidget {
  const ContactPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    // The hero holds back and runs under the status bar.
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ContactPane(
          id: id,
          onBack: () => backOr(context, Routes.contacts),
        ),
      ),
    );
  }
}

/// Desktop, nobody selected: the pane beside the list.
class ContactsNoSelection extends StatelessWidget {
  const ContactsNoSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.people_outline,
        title: l10n.contactNoSelectionTitle,
        body: l10n.contactNoSelectionBody,
      ),
    );
  }
}

/// A person found in the loaded book (there is no second fetch), wired to
/// saving, navigation and the other apps. Shared by [ContactPage] and the
/// desktop pane.
class ContactPane extends ConsumerStatefulWidget {
  const ContactPane({required this.id, this.onBack, super.key});

  final String id;

  /// Back in the hero: null in the desktop pane beside the list.
  final VoidCallback? onBack;

  @override
  ConsumerState<ContactPane> createState() => _ContactPaneState();
}

class _ContactPaneState extends ConsumerState<ContactPane> {
  /// Desktop: the history entry whose report is open beside it.
  String? _reportId;

  String get id => widget.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = peopleProvider(ref.watch(accountProvider)?.email);
    final people = ref.watch(book);
    final list = people.value;
    if (list == null) {
      return people.hasError
          ? LoadFailed(
              offline: people.error == PeopleFailure.network,
              title: l10n.contactsLoadError,
              onRetry: () => ref.invalidate(book),
            )
          : const Center(child: CircularProgressIndicator());
    }

    final person = list.where((person) => person.id == id).firstOrNull;
    if (person == null) {
      // Deleted elsewhere, or a bad link.
      return Center(
        child: EmptyState(
          icon: Icons.person_off_outlined,
          title: l10n.contactMissingTitle,
          body: l10n.contactMissingBody,
          actionLabel: l10n.contactBackToContacts,
          onAction: () => context.go(Routes.contacts),
        ),
      );
    }

    final owner = ref.watch(accountProvider)?.email;
    final workflows = workflowsProvider(owner);
    final workflowName = findWorkflow(
      ref.watch(workflows).value ?? const [],
      person.place?.workflowId,
    )?.name;

    // Loads the history as the page opens, and keeps it while the section
    // scrolls out of the lazy list.
    ref.listen(historyProvider(person.id), (_, _) {});
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
    // Gone when the entry is, or when another person opens.
    final report = context.screenSize.isDesktop
        ? ref
              .watch(historyProvider(person.id))
              .value
              ?.where((entry) => entry.id == _reportId && entry.report != null)
              .firstOrNull
        : null;

    // Only a team member can share; null while it loads or if it fails, so
    // the Invite button never flashes for someone already sharing.
    final sharing = person.stage == Stage.team
        ? ref.watch(contactSharingProvider(person.id)).value
        : null;

    return ContactDetails(
      person: person,
      onBack: widget.onBack,
      sharing: sharing,
      onInvite: () => unawaited(
        showInviteSheet(context, personId: person.id, name: firstName(person)),
      ),
      onStopSharing: () => unawaited(_stopSharing(context, ref, person.id)),
      model: model,
      onStatus: (status) => unawaited(
        writePeople(context, ref, (people) => people.setStatus(person, status)),
      ),
      onEdit: (part) => unawaited(showEditPerson(context, person, part)),
      onDelete: () => unawaited(_delete(context, ref)),
      onLog: () => unawaited(showLogActivity(context, person)),
      onMove: (stage) => unawaited(showChangeStage(context, [person], stage)),
      onChangeWorkflow: () => unawaited(showChangeWorkflow(context, [person])),
      onPause: () => unawaited(
        writePeople(context, ref, (people) => people.pause(person)),
      ),
      onResume: () => unawaited(
        writePeople(context, ref, (people) => people.resume(person, today())),
      ),
      photo: ref.watch(photoProvider(person.photoPath)),
      onChoosePhoto: () async {
        final bytes = await ref.read(photoPickerProvider).pick();
        if (bytes == null || !context.mounted) return;
        await writePeople(
          context,
          ref,
          (people) => people.setPhoto(person, bytes),
        );
      },
      onRemovePhoto: () async {
        await writePeople(
          context,
          ref,
          (people) => people.setPhoto(person, null),
        );
      },
      onLoyalty: () => unawaited(showLoyalty(context, person)),
      tags: tagsOf(person.tagIds, watchTags(ref)),
      onTags: () => unawaited(showTagSheet(context, [person])),
      onLaunch: (uri) => unawaited(openExternal(context, uri)),
      onRefresh: () {
        ref.invalidate(historyProvider(person.id));
        ref.invalidate(contactSharingProvider(person.id));
        ref.invalidate(workflows);
        return refreshPeople(context, ref);
      },
      workflowName: workflowName,
      nextStep: NextStepSection(
        key: ValueKey('next-${person.id}'),
        person: person,
      ),
      history: HistorySection(
        // A new person starts collapsed.
        key: ValueKey('history-${person.id}'),
        person: person,
        onAdd: () => unawaited(showLogActivity(context, person)),
        reportId: report?.id,
        onReport: (activity) {
          if (context.screenSize.isDesktop) {
            setState(() => _reportId = activity.id);
          } else {
            unawaited(
              showReportSheet(
                context,
                report: activity.report!,
                day: activity.happenedOn,
                title: activityTitle(l10n, activity, model),
                onOpenEvent: () =>
                    context.go(Routes.eventLocation(activity.eventId!)),
              ),
            );
          }
        },
      ),
      report: report == null
          ? null
          : _ReportPanel(
              title: activityTitle(l10n, report, model),
              onClose: () => setState(() => _reportId = null),
              child: ReportView(
                report: report.report!,
                day: report.happenedOn,
                onOpenEvent: () =>
                    context.go(Routes.eventLocation(report.eventId!)),
              ),
            ),
    );
  }

  /// Their goals go; a failure keeps them and says so.
  Future<void> _stopSharing(
    BuildContext context,
    WidgetRef ref,
    String personId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(sharingRepositoryProvider).stopSharingWith(personId);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(contactSharingProvider(personId));
  }

  /// Leaves the screen first, so it never shows the missing state for the
  /// person just deleted; a failure brings nothing back but a SnackBar, and
  /// the person is still in the list.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      peopleProvider(ref.read(accountProvider)?.email).notifier,
    );
    if (context.screenSize.isDesktop) {
      context.go(Routes.contacts);
    } else {
      // Removed once the page is off screen: a removal during the pop would
      // rebuild the outgoing page without them.
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.contacts);
      await leaving?.completed;
    }
    try {
      await controller.remove([id]);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// A report read from the history, under [title], with ✕ to put the side
/// column back.
class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            CloseButton(onPressed: onClose),
          ],
        ),
        child,
      ],
    );
  }
}
