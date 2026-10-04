import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/auth_redirect.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/features/auth/presentation/check_inbox_page.dart';
import 'package:loomia/features/auth/presentation/forgot_password_page.dart';
import 'package:loomia/features/auth/presentation/login_page.dart';
import 'package:loomia/features/auth/presentation/register_page.dart';
import 'package:loomia/features/auth/presentation/reset_password_page.dart';
import 'package:loomia/features/auth/presentation/welcome_page.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/import_contacts_page.dart';
import 'package:loomia/features/contacts/presentation/workflow_timeline_page.dart';
import 'package:loomia/features/goals/presentation/close_page.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/features/onboarding/presentation/first_run_page.dart';
import 'package:loomia/features/settings/presentation/settings_page.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:material_ui/material_ui.dart';

/// The app router lives in a provider so that it can watch session state and
/// `redirect` unauthenticated users.
///
/// Signed-in screens sit inside a `ShellRoute` so [AppShell] draws the sidebar
/// or the bottom bar around them. `/contacts` has its own nested `ShellRoute`:
/// on desktop it keeps the list built while the pane beside it follows the
/// URL. Tabs do not keep a stack each (no `StatefulShellRoute`): going back to
/// Contacts shows the list.
final routerProvider = Provider<GoRouter>((ref) {
  final status = ref.watch(authStatusProvider);

  final router = GoRouter(
    initialLocation: Routes.today,
    // `Supabase.initialize` has already restored any stored session, so the
    // first redirect knows the answer and no auth screen flashes on launch.
    refreshListenable: status,
    redirect: (context, state) => authRedirect(
      hasSession: status.hasSession,
      recoveringPassword: status.recoveringPassword,
      location: state.matchedLocation,
      onboarded: status.onboarded,
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.today,
            name: Routes.todayName,
            builder: (context, state) => const TodayPage(),
          ),
          // On desktop the list stays built around a pane that swaps with the
          // selection; elsewhere the list and a person are separate screens.
          ShellRoute(
            builder: (context, state, child) => context.screenSize.isDesktop
                ? ContactsPage(
                    pane: child,
                    selectedId: state.pathParameters['id'],
                  )
                : child,
            routes: [
              GoRoute(
                path: Routes.contacts,
                name: Routes.contactsName,
                pageBuilder: (context, state) =>
                    _contactsPage(context, state, null),
                routes: [
                  GoRoute(
                    path: Routes.contactSegment,
                    name: Routes.contactName,
                    pageBuilder: (context, state) => _contactsPage(
                      context,
                      state,
                      state.pathParameters['id'],
                    ),
                    routes: [
                      GoRoute(
                        path: Routes.contactWorkflowSegment,
                        name: Routes.contactWorkflowName,
                        pageBuilder: (context, state) => _workflowPage(
                          context,
                          state,
                          state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.team,
            name: Routes.teamName,
            builder: (context, state) => const TeamPage(),
          ),
          GoRoute(
            path: Routes.goals,
            name: Routes.goalsName,
            builder: (context, state) => const GoalsPage(),
          ),
          GoRoute(
            path: Routes.settings,
            name: Routes.settingsName,
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: Routes.settingsAccountSegment,
                name: Routes.settingsAccountName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.account),
              ),
              GoRoute(
                path: Routes.settingsLanguageSegment,
                name: Routes.settingsLanguageName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.language),
              ),
              GoRoute(
                path: Routes.settingsAppearanceSegment,
                name: Routes.settingsAppearanceName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.appearance),
              ),
              GoRoute(
                path: Routes.settingsWorkflowsSegment,
                name: Routes.settingsWorkflowsName,
                pageBuilder: (context, state) =>
                    _settingsPage(context, state, SettingsSection.workflows),
                routes: [
                  GoRoute(
                    path: Routes.settingsWorkflowSegment,
                    name: Routes.settingsWorkflowName,
                    pageBuilder: (context, state) => _settingsPage(
                      context,
                      state,
                      SettingsSection.workflows,
                      workflowId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.start,
        name: Routes.startName,
        builder: (context, state) => const FirstRunPage(),
      ),
      GoRoute(
        path: Routes.goalsClose,
        name: Routes.goalsCloseName,
        builder: (context, state) => const ClosePage(),
      ),
      GoRoute(
        path: Routes.goalsPlan,
        name: Routes.goalsPlanName,
        builder: (context, state) => const PlanPage(),
      ),
      GoRoute(
        path: Routes.importContacts,
        name: Routes.importContactsName,
        builder: (context, state) => const ImportContactsPage(),
      ),
      GoRoute(
        path: Routes.welcome,
        name: Routes.welcomeName,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        name: Routes.registerName,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.checkInbox,
        name: Routes.checkInboxName,
        builder: (context, state) => CheckInboxPage(
          reason:
              state.uri.queryParameters['reason'] ??
              CheckInboxPage.confirmReason,
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.resetPasswordName,
        builder: (context, state) => const ResetPasswordPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// On desktop a section only swaps the right-hand pane beside a list that stays
/// put; the platform transition would slide the whole screen in instead.
Page<void> _settingsPage(
  BuildContext context,
  GoRouterState state,
  SettingsSection section, {
  String? workflowId,
}) {
  final child = SettingsPage(section: section, workflowId: workflowId);
  return context.screenSize.isDesktop
      ? NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name,
          child: child,
        )
      : MaterialPage<void>(key: state.pageKey, name: state.name, child: child);
}

/// Desktop: the pane beside the list, swapped without a transition (see
/// [_settingsPage]). Elsewhere: the list, or a person pushed above it.
Page<void> _contactsPage(
  BuildContext context,
  GoRouterState state,
  String? id,
) {
  if (context.screenSize.isDesktop) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      child: Scaffold(
        body: id == null ? const ContactsNoSelection() : ContactPane(id: id),
      ),
    );
  }
  return MaterialPage<void>(
    key: state.pageKey,
    name: state.name,
    child: id == null ? const ContactsPage() : ContactPage(id: id),
  );
}

/// A person's whole workflow: in the pane on desktop, like [_contactsPage];
/// elsewhere pushed above the person.
Page<void> _workflowPage(BuildContext context, GoRouterState state, String id) {
  final child = WorkflowTimelinePage(id: id);
  return context.screenSize.isDesktop
      ? NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name,
          child: child,
        )
      : MaterialPage<void>(key: state.pageKey, name: state.name, child: child);
}
