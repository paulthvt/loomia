import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/business_model/business_model_copy.dart';
import 'package:loomia/core/photos/photo_picker.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/core/ui/avatar_control.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/auth/presentation/auth_validation_copy.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/settings/presentation/settings_action.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_option.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Photo, name, email, company, delete account.
///
/// Deleting needs no navigation here: the session ends, and the router's
/// redirect takes the user to /welcome.
class AccountSettings extends ConsumerStatefulWidget {
  const AccountSettings({super.key});

  @override
  ConsumerState<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends ConsumerState<AccountSettings>
    with SettingsAction {
  /// Saves [bytes] (null: removes) as the user's photo. Errors show in a
  /// SnackBar: the avatar carries the busy state, not the form.
  Future<void> _photo(Uint8List? bytes, String? old) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final photos = ref.read(photoRepositoryProvider);
    final auth = ref.read(authRepositoryProvider);
    try {
      await swapPhoto(
        photos,
        bytes: bytes,
        old: old,
        write: auth.updateAvatarPath,
      );
    } on AuthFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(authFailureCopy(l10n, failure))),
      );
    } catch (error) {
      // The upload: Storage, the connection, or bytes that are no image.
      messenger.showSnackBar(
        SnackBar(
          content: Text(peopleFailureCopy(l10n, peopleFailureFrom(error))),
        ),
      );
    }
  }

  Future<void> _editName(String current) async {
    final name = await LoomiaDialog.show<String>(
      context,
      (context) => _NameForm(initial: current),
    );
    if (name != null && name != current) {
      await run((auth) => auth.updateFirstName(name));
    }
  }

  Future<void> _editCompany(BusinessModel current) async {
    final chosen = await LoomiaDialog.show<BusinessModel>(context, (context) {
      final l10n = AppLocalizations.of(context);
      return LoomiaDialog(
        title: l10n.businessModelQuestion,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final model in const [
              BusinessModel.doterra,
              BusinessModel.other,
            ])
              SettingsOption(
                key: ValueKey('business-model-${model.name}'),
                label: businessModelLabel(l10n, model),
                selected: model == current,
                onTap: () => Navigator.pop(context, model),
              ),
          ],
        ),
      );
    });
    if (chosen != null && chosen != current) {
      await run((auth) => auth.updateBusinessModel(chosen));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await LoomiaDialog.show<bool>(context, (context) {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return LoomiaDialog(
        title: l10n.settingsDeleteTitle,
        body: l10n.settingsDeleteBody,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsDeleteConfirm),
          ),
        ],
      );
    });
    if (confirmed == true) await run((auth) => auth.deleteAccount());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(accountProvider);
    final error = failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account != null) ...[
          Center(
            child: AvatarControl(
              name: account.displayName,
              photo: ref.watch(photoProvider(account.avatarPath)),
              onChoose: () async {
                final bytes = await ref.read(photoPickerProvider).pick();
                if (bytes == null || !mounted) return;
                await _photo(bytes, account.avatarPath);
              },
              onRemove: account.avatarPath == null
                  ? null
                  : () => _photo(null, account.avatarPath),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            children: [
              ListTile(
                title: Text(l10n.authFirstNameLabel),
                subtitle: account.firstName.isEmpty
                    ? null
                    : Text(account.firstName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => _editName(account.firstName),
              ),
              ListTile(
                title: Text(l10n.authEmailLabel),
                subtitle: Text(account.email),
              ),
              ListTile(
                title: Text(l10n.settingsCompany),
                subtitle: Text(businessModelLabel(l10n, account.businessModel)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: busy ? null : () => _editCompany(account.businessModel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (error != null) ...[
          FormError(authFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              iconColor: scheme.error,
              textColor: scheme.error,
              title: Text(l10n.settingsDeleteAccount),
              onTap: busy ? null : _confirmDelete,
            ),
          ],
        ),
      ],
    );
  }
}

/// Pops with the trimmed name, or null when cancelled.
class _NameForm extends StatefulWidget {
  const _NameForm({required this.initial});

  final String initial;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return Form(
      key: _form,
      child: LoomiaDialog(
        title: l10n.settingsEditNameTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(material.saveButtonLabel),
          ),
        ],
        child: LabeledField(
          label: l10n.authFirstNameLabel,
          child: TextFormField(
            controller: _name,
            autofocus: true,
            validator: (value) => firstNameFieldError(l10n, value),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
    );
  }
}
