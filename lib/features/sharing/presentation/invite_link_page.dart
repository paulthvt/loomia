import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/presentation/accept_invite.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class InviteLinkPage extends ConsumerWidget {
  const InviteLinkPage({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSession = ref.watch(authRepositoryProvider).hasSession;
    final l10n = AppLocalizations.of(context);
    // The code comes from the URL, as typed or mangled: null when it can't work.
    final normalised = normaliseCode(code);

    if (hasSession) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: AcceptInvite(
            initialCode: normalised,
            onAccepted: () => context.go(Routes.settingsSharing),
          ),
        ),
      );
    }

    // Signed out
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (normalised == null)
                Text(
                  l10n.inviteErrorInvalid,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                )
              else ...[
                Text(
                  formatCode(normalised),
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.inviteLinkSignedOutBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => context.go(Routes.login),
                child: Text(l10n.authSignInButton),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.go(Routes.register),
                child: Text(l10n.welcomeRegisterButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
