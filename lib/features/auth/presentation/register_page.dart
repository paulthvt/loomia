import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/domain/auth_validation.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/auth/presentation/auth_validation_copy.dart';
import 'package:loomia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:loomia/features/auth/presentation/widgets/password_field.dart';
import 'package:loomia/features/auth/presentation/widgets/submit_button.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Registration. The first name goes into the auth user's metadata; there is no
/// profiles table yet, and nothing in the app queries another person's name.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Two taps in the same frame reach here before `_busy` disables the button;
    // a second signup would be sent.
    if (_busy) return;
    if (!_form.currentState!.validate()) return;

    final email = normalizeEmail(_email.text);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: _password.text,
            firstName: _firstName.text.trim(),
          );
      if (!mounted) return;
      // Email confirmation is on, so there is no session yet — the next step is
      // the user's inbox.
      context.pushReplacement(
        Routes.checkInboxLocation(reason: 'confirm', email: email),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      back: Routes.welcome,
      children: [
        Text(l10n.authRegisterTitle, style: text.headlineSmall),
        if (_failure != null) FormError(authFailureCopy(l10n, _failure!)),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              LabeledField(
                label: l10n.authFirstNameLabel,
                child: TextFormField(
                  controller: _firstName,
                  enabled: !_busy,
                  validator: (value) => firstNameFieldError(l10n, value),
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                ),
              ),
              LabeledField(
                label: l10n.authEmailLabel,
                child: TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  validator: (value) => emailFieldError(l10n, value),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
              ),
              PasswordField(
                controller: _password,
                label: l10n.authPasswordLabel,
                helper: l10n.authPasswordHelperMinimum(minPasswordLength),
                enabled: !_busy,
                validator: (value) => passwordFieldError(l10n, value),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              SubmitButton(
                label: l10n.authCreateAccountSubmit,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        _PrivacyLine(style: text.bodySmall),
        // Wrap, not Row: "Already have an account?" plus the button is wider
        // than the 400-wide column at larger text scales.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.authAlreadyHaveAccount, style: text.bodySmall),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.login),
              child: Text(l10n.authSignInAction),
            ),
          ],
        ),
      ],
    );
  }
}

/// "By creating an account, you accept the privacy policy.", one translated
/// sentence whose placeholder is drawn as a link button to the site's policy.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The placeholder's position comes from the translation, not the code.
    const marker = '\u0000';
    final [before, after] = l10n.authRegisterPrivacy(marker).split(marker);
    final locale = Localizations.localeOf(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            // Text.rich already scales a WidgetSpan by the text scale; without
            // this the link's own Text would be scaled a second time.
            child: MediaQuery.withNoTextScaling(
              child: TextButton(
                style: AppTheme.inlineLink(style),
                onPressed: () =>
                    openExternal(context, siteUri(locale, '/privacy')),
                child: Text(l10n.authRegisterPrivacyLink),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      style: style,
    );
  }
}
