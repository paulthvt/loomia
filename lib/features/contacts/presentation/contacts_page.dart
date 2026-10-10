import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/add_person_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a person: beside the list on desktop (the URL changes, the list keeps
/// its scroll and filter), pushed above it elsewhere so back returns to it.
void openContact(BuildContext context, String id) {
  final location = Routes.contactLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// Reloads the book while the old list stays on screen. A failure says so in a
/// SnackBar instead of replacing the list with the error state.
Future<void> refreshPeople(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final people = peopleProvider(ref.read(accountProvider)?.email);
  try {
    ref.invalidate(people);
    await ref.read(people.future);
  } on PeopleFailure {
    messenger.showSnackBar(SnackBar(content: Text(l10n.contactsRefreshFailed)));
  }
}

/// Runs a write on the signed-in book; a failure is a SnackBar, and the book
/// stays as it was. Completes with whether it succeeded.
Future<bool> writePeople(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(PeopleController people) write,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await write(
      ref.read(peopleProvider(ref.read(accountProvider)?.email).notifier),
    );
    return true;
  } on PeopleFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
    );
    return false;
  }
}

/// Whether several people are being picked on Contacts: on a phone the bottom
/// navigation gives way to what can be done with them (#180).
final contactsPickingProvider = NotifierProvider<ContactsPicking, bool>(
  ContactsPicking.new,
);

class ContactsPicking extends Notifier<bool> {
  @override
  bool build() => false;

  /// Also called once the list is gone, when this may be disposed.
  void set(bool picking) {
    if (ref.mounted) state = picking;
  }
}

/// The Contacts destination. On desktop it also holds [pane], the selected
/// person or an empty state, beside the list.
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({this.pane, this.selectedId, super.key});

  final Widget? pane;
  final String? selectedId;

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  /// Fixed, like the Settings list, so a resized window narrows the pane.
  static const double _listWidth = 440;

  late final AppLifecycleListener _lifecycle;

  /// Read once: the list says the picking ended after this is disposed.
  late final ContactsPicking _picking;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _picking = ref.read(contactsPickingProvider.notifier);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Nothing is realtime: coming back to the app is when changes made on
  /// another device are most likely waiting. Quiet — a failure here keeps the
  /// list and says nothing; the user did not ask.
  void _onResume() {
    final people = peopleProvider(ref.read(accountProvider)?.email);
    if (!ref.read(people.notifier).isStaleAt(DateTime.now())) return;
    ref.refresh(people.future).ignore();
  }

  /// The person open beside the list goes first, so the pane never shows
  /// them missing.
  Future<bool> _delete(List<Person> people) {
    if (people.any((person) => person.id == widget.selectedId)) {
      context.go(Routes.contacts);
    }
    return writePeople(
      context,
      ref,
      (book) => book.remove([for (final person in people) person.id]),
    );
  }

  Future<void> _add() async {
    final person = await showAddPerson(context);
    if (person != null && mounted) openContact(context, person.id);
  }

  @override
  Widget build(BuildContext context) {
    final book = peopleProvider(ref.watch(accountProvider)?.email);
    final people = ref.watch(book);
    final list = people.value;
    // Starts loading the workflows (and seeds them the first time) as soon
    // as Contacts opens, so a person's card rarely waits.
    ref.listen(workflowsProvider(ref.watch(accountProvider)?.email), (_, _) {});
    final sideNavigation = context.screenSize.usesSideNavigation;
    final pane = widget.pane;

    final Widget body;
    if (list != null) {
      body = ContactList(
        people: list,
        onOpen: (person) => openContact(context, person.id),
        onAdd: _add,
        onImport: kIsWeb
            ? null
            : () => unawaited(context.push(Routes.importContacts)),
        onRefresh: () => refreshPeople(context, ref),
        onMove: (people, stage) => showChangeStage(context, people, stage),
        onChangeWorkflow: (people) => showChangeWorkflow(context, people),
        onDelete: _delete,
        model: ref.watch(accountProvider)?.businessModel ?? BusinessModel.other,
        selectedId: widget.selectedId,
        showRefresh: sideNavigation,
        onPickingChanged: _picking.set,
        accountAction: sideNavigation ? null : const AccountButton(),
      );
    } else if (people.hasError) {
      body = PeopleLoadError(onRetry: () => ref.invalidate(book));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: pane == null
            ? body
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: _listWidth,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: LoomiaColors.of(context).borderSubtle,
                        ),
                      ),
                    ),
                    child: body,
                  ),
                  Expanded(child: pane),
                ],
              ),
      ),
    );
  }
}

/// The book could not be loaded and there is nothing to show instead. #46
/// replaces it with the shared offline presentation.
class PeopleLoadError extends StatelessWidget {
  const PeopleLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.contactsLoadError,
        body: l10n.contactsLoadErrorBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}
