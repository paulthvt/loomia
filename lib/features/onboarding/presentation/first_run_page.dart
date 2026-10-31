import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/business_model/business_model_copy.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/auth/presentation/auth_validation_copy.dart';
import 'package:loomia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:loomia/features/auth/presentation/widgets/submit_button.dart';
import 'package:loomia/features/contacts/presentation/add_person_sheet.dart';
import 'package:loomia/features/sharing/presentation/accept_invite.dart';
import 'package:loomia/features/sharing/presentation/sharing_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Shown once, after sign-up: the user's first name when the account came
/// without one (an Apple sign-in, #22), which company they work with, then who
/// they already work with. One decision per step.
///
/// The step is local state, not a route, so the router's onboarding guard
/// stays as it is. Back — the button or the system gesture — returns to the
/// step before; nothing comes before the first one shown.
class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({super.key});

  @override
  ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

enum _Step { name, company, invite, people }

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  /// Read once: a Google backfill landing later must not swap the step away.
  late final bool _askName =
      ref.read(authRepositoryProvider).account?.needsName ?? false;
  late _Step _step = _askName ? _Step.name : _Step.company;

  /// What the name step saved, to prefill it on the way back.
  String _name = '';

  void _show(_Step step) => setState(() => _step = step);

  _Step? get _previous => switch (_step) {
    _Step.name => null,
    _Step.company => _askName ? _Step.name : null,
    _Step.invite => _Step.company,
    _Step.people => _Step.invite,
  };

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    return PopScope(
      canPop: previous == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && previous != null) _show(previous);
      },
      child: switch (_step) {
        _Step.name => FirstRunNameStep(
          initial: _name,
          onSaved: (name) {
            _name = name;
            _show(_Step.company);
          },
        ),
        _Step.company => FirstRunCompanyStep(
          onChosen: () => _show(_Step.invite),
          onBack: _askName ? () => _show(_Step.name) : null,
        ),
        _Step.invite => FirstRunInviteStep(
          onDone: () => _show(_Step.people),
          onBack: () => _show(_Step.company),
        ),
        _Step.people => FirstRunPeopleStep(onBack: () => _show(_Step.invite)),
      },
    );
  }
}

/// Before the company, only when the account has no name. Required, like on
/// sign-up; saved where sign-up and Settings save it. A failure stays here.
class FirstRunNameStep extends ConsumerStatefulWidget {
  const FirstRunNameStep({
    required this.initial,
    required this.onSaved,
    super.key,
  });

  final String initial;
  final ValueChanged<String> onSaved;

  @override
  ConsumerState<FirstRunNameStep> createState() => _FirstRunNameStepState();
}

class _FirstRunNameStepState extends ConsumerState<FirstRunNameStep> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateFirstName(name);
      if (mounted) widget.onSaved(name);
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    return AuthScaffold(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            Text(l10n.firstRunEyebrow, style: text.displaySmall),
            Text(l10n.firstRunNameQuestion, style: text.titleLarge),
            Text(l10n.firstRunNameBody, style: text.bodyMedium),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              LabeledField(
                label: l10n.authFirstNameLabel,
                child: TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  validator: (value) => firstNameFieldError(l10n, value),
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              SubmitButton(
                label: l10n.firstRunNameContinue,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tapping a company saves it and moves on: nothing is preselected and there
/// is no Next, the tap is the answer. A failure stays here.
class FirstRunCompanyStep extends ConsumerStatefulWidget {
  const FirstRunCompanyStep({required this.onChosen, this.onBack, super.key});

  final VoidCallback onChosen;

  /// Back to the name step, when it was shown; then "Welcome" was said there.
  final VoidCallback? onBack;

  @override
  ConsumerState<FirstRunCompanyStep> createState() =>
      _FirstRunCompanyStepState();
}

class _FirstRunCompanyStepState extends ConsumerState<FirstRunCompanyStep> {
  bool _busy = false;
  AuthFailure? _failure;

  Future<void> _choose(BusinessModel model) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateBusinessModel(model);
      if (mounted) widget.onChosen();
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    return AuthScaffold(
      onBack: widget.onBack,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (widget.onBack == null)
              Text(l10n.firstRunEyebrow, style: text.displaySmall),
            Text(l10n.businessModelQuestion, style: text.titleLarge),
            Text(l10n.firstRunCompanyBody, style: text.bodyMedium),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            for (final model in const [
              BusinessModel.doterra,
              BusinessModel.other,
            ])
              Card(
                key: ValueKey('business-model-${model.name}'),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(businessModelLabel(l10n, model)),
                  subtitle: Text(switch (model) {
                    BusinessModel.doterra => l10n.firstRunDoterraDetail,
                    BusinessModel.other => l10n.firstRunOtherDetail,
                  }),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : () => _choose(model),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 2: who the user already works with. Every way out, Skip included,
/// marks the account onboarded, so it never comes back.
///
/// The web has no address book to read: there, only Add someone.
class FirstRunPeopleStep extends ConsumerStatefulWidget {
  const FirstRunPeopleStep({required this.onBack, super.key});

  /// Back to step 1.
  final VoidCallback onBack;

  @override
  ConsumerState<FirstRunPeopleStep> createState() => _FirstRunPeopleStepState();
}

class _FirstRunPeopleStepState extends ConsumerState<FirstRunPeopleStep> {
  bool _busy = false;
  AuthFailure? _failure;

  /// Marks the account, then goes to [location], with [above] pushed on top
  /// so back returns to [location] rather than out of the app. A failure
  /// stays here.
  Future<void> _leaveTo(String location, {String? above}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).markOnboarded();
      if (!mounted) return;
      context.go(location);
      if (above != null) unawaited(context.push(above));
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure;
        });
      }
    }
  }

  Future<void> _add() async {
    final person = await showAddPerson(context);
    if (person != null && mounted) {
      await _leaveTo(Routes.contactLocation(person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final failure = _failure;

    // No "Welcome" here: step 1 said it (Figma 212:3241).
    return AuthScaffold(
      onBack: widget.onBack,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            Text(l10n.firstRunTitle, style: text.titleLarge),
            Text(
              kIsWeb ? l10n.firstRunBodyWeb : l10n.firstRunBody,
              style: text.bodyMedium,
            ),
          ],
        ),
        if (failure != null) FormError(authFailureCopy(l10n, failure)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (kIsWeb)
              FilledButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _leaveTo(
                        Routes.contacts,
                        above: Routes.importContacts,
                      ),
                icon: const Icon(Icons.contacts_outlined),
                label: Text(l10n.contactsImport),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _add,
                child: Text(l10n.contactsAdd),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : () => _leaveTo(Routes.today),
              child: Text(l10n.firstRunSkip),
            ),
          ],
        ),
      ],
    );
  }
}

/// Step between company and people: accept an invite code, or skip.
class FirstRunInviteStep extends ConsumerWidget {
  const FirstRunInviteStep({
    required this.onDone,
    required this.onBack,
    super.key,
  });

  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myShare = ref.watch(myShareProvider);

    return AuthScaffold(
      onBack: onBack,
      children: [
        myShare.when(
          data: (share) => share == null
              ? AcceptInvite(
                  onAccepted: () {
                    ref.invalidate(myShareProvider);
                    onDone();
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.sharingLinkedWith(share.mentorFirstName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: onDone,
                      child: Text(
                        MaterialLocalizations.of(context).continueButtonLabel,
                      ),
                    ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => AcceptInvite(
            onAccepted: () {
              ref.invalidate(myShareProvider);
              onDone();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onDone, child: Text(l10n.firstRunSkipInvite)),
      ],
    );
  }
}
