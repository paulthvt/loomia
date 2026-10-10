/// Every route path and name in the app. Widgets never write a path literal.
abstract final class Routes {
  static const String today = '/';
  static const String todayName = 'today';

  static const String contacts = '/contacts';
  static const String contactsName = 'contacts';

  /// One person, nested under [contacts] so back returns to the list.
  static const String contactSegment = ':id';
  static const String contactName = 'contact';

  static String contactLocation(String id) =>
      '$contacts/${Uri.encodeComponent(id)}';

  /// Their whole workflow, nested under the person so back returns to them.
  static const String contactWorkflowSegment = 'workflow';
  static const String contactWorkflowName = 'contactWorkflow';

  static String contactWorkflowLocation(String id) =>
      '${contactLocation(id)}/$contactWorkflowSegment';

  static const String calendar = '/calendar';
  static const String calendarName = 'calendar';

  /// One event, nested under [calendar] so back returns to the month.
  static const String eventSegment = ':id';
  static const String eventName = 'event';

  static String eventLocation(String id) =>
      '$calendar/${Uri.encodeComponent(id)}';

  /// The old Team tab (before #151). Kept so a saved link lands on Contacts.
  static const String team = '/team';
  static const String teamName = 'team';

  static const String goals = '/goals';
  static const String goalsName = 'goals';

  /// Full screen, outside the tabs: this month's plan.
  static const String goalsPlan = '/goals/plan';
  static const String goalsPlanName = 'goalsPlan';

  /// Full screen, outside the tabs: close a month, then plan the next.
  static const String goalsClose = '/goals/close';
  static const String goalsCloseName = 'goalsClose';

  static const String settings = '/settings';
  static const String settingsName = 'settings';

  /// Settings sections nest under [settings], so back from one returns to the
  /// list. The segment is what the nested `GoRoute` declares.
  static const String settingsAccountSegment = 'account';
  static const String settingsAccount = '$settings/$settingsAccountSegment';
  static const String settingsAccountName = 'settingsAccount';

  static const String settingsLanguageSegment = 'language';
  static const String settingsLanguage = '$settings/$settingsLanguageSegment';
  static const String settingsLanguageName = 'settingsLanguage';

  static const String settingsAppearanceSegment = 'appearance';
  static const String settingsAppearance =
      '$settings/$settingsAppearanceSegment';
  static const String settingsAppearanceName = 'settingsAppearance';

  static const String settingsWorkflowsSegment = 'workflows';
  static const String settingsWorkflows = '$settings/$settingsWorkflowsSegment';
  static const String settingsWorkflowsName = 'settingsWorkflows';

  /// One workflow, nested under [settingsWorkflows] so back returns to it.
  static const String settingsWorkflowSegment = ':id';
  static const String settingsWorkflowName = 'settingsWorkflow';

  static String settingsWorkflowLocation(String id) =>
      '$settingsWorkflows/${Uri.encodeComponent(id)}';

  /// One event workflow, nested under [settingsWorkflows]. Declared before
  /// [settingsWorkflowSegment] so `events/x` isn't read as a workflow id.
  static const String settingsEventWorkflowSegment = 'events/:id';
  static const String settingsEventWorkflowName = 'settingsEventWorkflow';

  static String settingsEventWorkflowLocation(String id) =>
      '$settingsWorkflows/events/${Uri.encodeComponent(id)}';

  /// First run: "Who do you already work with?", once per account.
  static const String start = '/start';
  static const String startName = 'start';

  /// The phone's contacts, to tick and import. Not on web.
  static const String importContacts = '/import-contacts';
  static const String importContactsName = 'importContacts';

  /// Someone already in Loomia, opened from [importContacts] and stacked above
  /// it so back returns to the ticks. Not [contactLocation]: that sits inside
  /// the app shell, which is already below the import screen, and go_router
  /// can't stack the same shell twice (duplicate page keys, blank screen).
  static const String importedContactName = 'importedContact';
  static const String importedContactWorkflowName = 'importedContactWorkflow';

  static String importedContactLocation(String id) =>
      '$importContacts/${Uri.encodeComponent(id)}';

  /// Reachable before the first-run screen is passed.
  static const Set<String> onboardingPaths = {start, importContacts};

  static const String welcome = '/welcome';
  static const String welcomeName = 'welcome';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String register = '/register';
  static const String registerName = 'register';

  static const String forgotPassword = '/forgot-password';
  static const String forgotPasswordName = 'forgotPassword';

  static const String checkInbox = '/check-inbox';
  static const String checkInboxName = 'checkInbox';

  static const String resetPassword = '/reset-password';
  static const String resetPasswordName = 'resetPassword';

  /// Reachable without a session. `/reset-password` is not in this set: it is
  /// reached by a deep link that has already signed the user in.
  static const Set<String> authPaths = {
    welcome,
    login,
    register,
    forgotPassword,
    checkInbox,
  };

  /// `/check-inbox` carries its copy in the query string rather than a router
  /// `extra`, so reloading the page on web does not land on an empty screen.
  static String checkInboxLocation({
    required String reason,
    required String email,
  }) => Uri(
    path: checkInbox,
    queryParameters: {'reason': reason, 'email': email},
  ).toString();
}
