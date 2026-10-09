import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/theme_preview.dart';
import 'package:loomia/core/ui/ui_preview.dart';
import 'package:loomia/features/calendar/presentation/calendar_preview.dart';
import 'package:loomia/features/contacts/presentation/contacts_preview.dart';
import 'package:loomia/features/goals/presentation/goals_preview.dart';
import 'package:loomia/features/onboarding/presentation/first_run_preview.dart';
import 'package:loomia/features/today/presentation/today_preview.dart';
import 'package:loomia/features/workflows/presentation/workflows_preview.dart';
import 'package:material_ui/material_ui.dart';

import 'load_fonts.dart';

/// Every `@Preview`, rendered at its preview size and compared against a
/// committed PNG in `goldens/`.
///
/// The previews are their own apps — `flutter widget-preview start` builds each
/// function directly — so a missing localization delegate or a layout assertion
/// only shows up here: no shipped screen goes through these builders.
///
/// Pixels are compared on Linux only. Antialiasing differs per OS, and the
/// committed PNGs come from CI (see the `update-goldens` input in ci.yaml).
/// Elsewhere the previews still have to render without an exception.
void main() {
  final previews = <String, (Size, Widget Function())>{
    'today_mobile_light': (const Size(390, 844), todayMobileLight),
    'today_mobile_dark': (const Size(390, 844), todayMobileDark),
    'today_desktop_light': (const Size(1440, 900), todayDesktopLight),
    'today_desktop_dark': (const Size(1440, 900), todayDesktopDark),
    'today_empty_light': (const Size(390, 844), todayEmptyLight),
    'today_events_mobile_light': (const Size(390, 844), todayEventsMobileLight),
    'calendar_mobile_light': (const Size(390, 844), calendarMobileLight),
    'calendar_mobile_dark': (const Size(390, 844), calendarMobileDark),
    'calendar_desktop_light': (const Size(1440, 900), calendarDesktopLight),
    'event_mobile_light': (const Size(390, 844), eventMobileLight),
    'event_done_mobile_light': (const Size(390, 844), eventDoneMobileLight),
    'goals_mobile_light': (const Size(390, 844), goalsMobileLight),
    'goals_mobile_dark': (const Size(390, 844), goalsMobileDark),
    'goals_desktop_light': (const Size(1440, 900), goalsDesktopLight),
    'goals_empty_light': (const Size(390, 844), goalsEmptyLight),
    'goals_plan_light': (const Size(390, 844), goalsPlanLight),
    'goals_plan_desktop_light': (const Size(1440, 900), goalsPlanDesktopLight),
    'goals_close_light': (const Size(390, 844), goalsCloseLight),
    'contacts_mobile_light': (const Size(390, 844), contactsMobileLight),
    'contacts_mobile_dark': (const Size(390, 844), contactsMobileDark),
    'contact_mobile_light': (const Size(390, 844), contactMobileLight),
    'contact_photo_mobile_light': (
      const Size(390, 844),
      contactPhotoMobileLight,
    ),
    'contact_mobile_dark': (const Size(390, 844), contactMobileDark),
    'team_member_mobile_light': (const Size(390, 844), teamMemberMobileLight),
    'contacts_desktop_light': (const Size(1440, 900), contactsDesktopLight),
    'first_run_company_light': (const Size(390, 844), firstRunCompanyLight),
    'first_run_people_light': (const Size(390, 844), firstRunPeopleLight),
    'workflows_list_light': (const Size(390, 844), workflowsListLight),
    'workflow_editor_light': (const Size(390, 844), workflowEditorLight),
    'workflow_step_light': (const Size(390, 844), workflowStepLight),
    'event_workflow_editor_light': (
      const Size(390, 844),
      eventWorkflowEditorLight,
    ),
    'components_light': (const Size(420, 1800), uiComponentsLight),
    'components_dark': (const Size(420, 1800), uiComponentsDark),
    'tokens_colour_light': (const Size(420, 900), colourTokensLight),
    'tokens_colour_dark': (const Size(420, 900), colourTokensDark),
    'tokens_type_light': (const Size(420, 900), typeRampLight),
    'tokens_type_dark': (const Size(420, 900), typeRampDark),
    'tokens_spacing': (const Size(420, 700), spacingTokens),
    'tokens_components_light': (const Size(420, 760), componentsLight),
    'tokens_components_dark': (const Size(420, 760), componentsDark),
  };

  setUpAll(loadAppFonts);

  for (final MapEntry(key: name, value: (size, preview)) in previews.entries) {
    testWidgets(name, (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(preview());
      // Photos decode outside the fake clock.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (Platform.isLinux) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      }
    });
  }
}
