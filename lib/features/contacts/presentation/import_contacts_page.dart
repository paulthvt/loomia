import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/phone_contacts_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/phone_contact.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's address book; null when access is refused.
final phoneContactsProvider = FutureProvider.autoDispose<List<PhoneContact>?>(
  (ref) => ref.watch(phoneContactsRepositoryProvider).read(),
  retry: (error, _) => null,
);

/// Pick people from the phone's contacts and bring them in, all at one stage,
/// since today or an earlier day (#179): most are customers or on the team
/// already. Nobody is ticked to start with; someone who looks already in
/// Loomia says so, and can still be ticked. They start the stage's default
/// workflow only if the switch says so (#225): on for since today, off for an
/// earlier day, so an existing customer base doesn't start onboarding.
class ImportContactsPage extends ConsumerStatefulWidget {
  const ImportContactsPage({super.key});

  @override
  ConsumerState<ImportContactsPage> createState() => _ImportContactsPageState();
}

class _ImportContactsPageState extends ConsumerState<ImportContactsPage> {
  late final AppLifecycleListener _lifecycle;
  String _query = '';

  /// Indexes into the phone's list, so two contacts with the same name stay
  /// apart.
  final Set<int> _selected = {};
  Stage _stage = Stage.prospect;

  /// Null is today: picking is optional, each person can be corrected later.
  DateTime? _since;

  /// The user's flip of the workflow switch; null follows [_since]. Reset
  /// whenever the stage or the day changes.
  bool? _startPicked;
  bool get _start => _startPicked ?? _since == null;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Back from the phone's settings, access may have been granted.
  void _onResume() {
    if (ref.read(phoneContactsProvider) case AsyncData(value: null)) {
      ref.invalidate(phoneContactsProvider);
    }
  }

  Future<void> _import(List<PhoneContact> contacts) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final owner = ref.read(accountProvider)?.email;
      final workflows = ref.read(workflowsProvider(owner)).value ?? const [];
      final added = await ref
          .read(peopleProvider(owner).notifier)
          .addAll(
            [
              for (final index in _selected.toList()..sort())
                (
                  name: contacts[index].name,
                  stage: _stage,
                  phone: contacts[index].phone,
                  email: contacts[index].email,
                  instagram: null,
                ),
            ],
            workflow: _start ? defaultFor(workflows, _stage) : null,
            today: today(),
            stageSince: _since,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importDone(added.length))),
      );
      if (mounted) context.go(Routes.contacts);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    // Loads the workflows, so the default is there by the time Import is
    // tapped.
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final phone = ref.watch(phoneContactsProvider);

    final Widget body = switch (phone) {
      AsyncData(value: null) => _centered(
        EmptyState(
          icon: Icons.lock_outline_rounded,
          title: l10n.importDeniedTitle,
          body: l10n.importDeniedBody,
          actionLabel: l10n.importOpenSettings,
          onAction: ref.read(phoneContactsRepositoryProvider).openSettings,
        ),
      ),
      AsyncData(value: final contacts?) when contacts.isEmpty => _centered(
        EmptyState(
          icon: Icons.contacts_outlined,
          title: l10n.importNoneTitle,
          body: l10n.importNoneBody,
        ),
      ),
      AsyncData(value: final contacts?) => _picker(
        l10n,
        contacts,
        ref.watch(peopleProvider(owner)).value ?? const [],
        defaultFor(workflows, _stage),
      ),
      AsyncError() => _centered(
        EmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.importReadError,
          body: l10n.importReadErrorBody,
          actionLabel: l10n.contactsRetry,
          onAction: () => ref.invalidate(phoneContactsProvider),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.contacts)),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _centered(Widget child) =>
      Center(child: SingleChildScrollView(child: child));

  Widget _picker(
    AppLocalizations l10n,
    List<PhoneContact> contacts,
    List<Person> people,
    Workflow? workflow,
  ) {
    final query = searchKey(_query);
    final muted = LoomiaColors.of(context).textMuted;
    final count = _selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              LoomiaTopBar(
                eyebrow: l10n.importSelected(count),
                title: l10n.importTitle,
              ),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: AppTheme.search(context).copyWith(
                  hintText: l10n.contactsSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.importHint,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.ms),
              for (final (index, contact) in contacts.indexed)
                if (searchKey(contact.name).contains(query))
                  ContactRow(
                    name: contact.name,
                    subtitle: alreadyIn(contact, people)
                        ? l10n.importAlreadyIn
                        : contact.phone ?? contact.email,
                    trailing: Checkbox(
                      value: _selected.contains(index),
                      onChanged: (_) => _toggle(index),
                    ),
                    onTap: () => _toggle(index),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: l10n.importStage),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final stage in Stage.values)
                    ChoiceChip(
                      label: Text(stageLabel(l10n, stage)),
                      selected: _stage == stage,
                      onSelected: (_) => setState(() {
                        _stage = stage;
                        _startPicked = null;
                      }),
                    ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _pickSince,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(switch (_since) {
                    final DateTime since => l10n.importSince(since),
                    null => l10n.importSinceToday,
                  }),
                ),
              ),
              if (workflow != null)
                // The app's one switch style, as in the step sheet.
                SwitchListTile(
                  value: _start,
                  title: Text(l10n.importStartWorkflow),
                  subtitle: Text(workflow.name),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (on) => setState(() => _startPicked = on),
                ),
              const SizedBox(height: AppSpacing.ms),
              FilledButton(
                onPressed: count == 0 || _saving
                    ? null
                    : () => _import(contacts),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.importAction(count)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickSince() async {
    final now = today();
    final since = await pickDay(context, initial: _since ?? now, last: now);
    if (since != null && mounted) {
      setState(() {
        _since = since == now ? null : since;
        _startPicked = null;
      });
    }
  }

  void _toggle(int index) => setState(
    () => _selected.contains(index)
        ? _selected.remove(index)
        : _selected.add(index),
  );
}
