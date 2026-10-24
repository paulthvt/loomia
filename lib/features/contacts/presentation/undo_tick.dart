import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// How long Undo is offered after a tick (#372).
const undoTickDuration = Duration(seconds: 5);

/// The snackbar's width on desktop, bottom centre (Figma "Undo — #372").
/// On a phone it spans the screen, inset as the theme says.
const _desktopWidth = 480.0;

/// After a tick went through: "[message]" with Undo, replacing whatever
/// snackbar shows. [undo] runs on the app's provider container, not the
/// page's, so it still works once the screen that ticked is gone.
void offerUndo(
  BuildContext context,
  String message,
  Future<void> Function(ProviderContainer container) undo,
) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: undoTickDuration,
        // An action keeps a snackbar up by default; only a screen reader
        // user needs that, to reach Undo.
        persist: MediaQuery.accessibleNavigationOf(context),
        width: context.screenSize == ScreenSize.desktop ? _desktopWidth : null,
        action: SnackBarAction(
          label: l10n.tickUndo,
          onPressed: () => unawaited(_run(messenger, l10n, container, undo)),
        ),
      ),
    );
}

/// Ticks [step] for [person] through the book, then offers to take it back.
/// Completes with whether the tick went through. Today has its own, which
/// also counts the tick.
Future<bool> tickStep(
  BuildContext context,
  WidgetRef ref,
  Person person,
  OnStep step,
) async {
  final day = today();
  Person? after;
  final ticked = await writePeople(
    context,
    ref,
    (people) async => after = await people.completeStep(person, step, day),
  );
  if (ticked && context.mounted) {
    _offerOnBook(
      context,
      ref,
      AppLocalizations.of(context).tickDoneFor(person.name, step.step.label),
      (people) => people.undoStep(person, after!, step, day),
    );
  }
  return ticked;
}

/// As [tickStep], for one of [person]'s reminders.
Future<bool> tickReminder(
  BuildContext context,
  WidgetRef ref,
  Person person,
  Reminder reminder,
) async {
  final day = today();
  final ticked = await writePeople(
    context,
    ref,
    (people) => people.completeReminder(person, reminder, day),
  );
  if (ticked && context.mounted) {
    _offerOnBook(
      context,
      ref,
      AppLocalizations.of(context).tickDoneFor(person.name, reminder.text),
      (people) => people.undoReminder(person, reminder, day),
    );
  }
  return ticked;
}

void _offerOnBook(
  BuildContext context,
  WidgetRef ref,
  String message,
  Future<void> Function(PeopleController people) undo,
) {
  final owner = ref.read(accountProvider)?.email;
  offerUndo(
    context,
    message,
    (container) => undo(container.read(peopleProvider(owner).notifier)),
  );
}

Future<void> _run(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ProviderContainer container,
  Future<void> Function(ProviderContainer container) undo,
) async {
  String? failure;
  try {
    await undo(container);
  } on UndoStale {
    failure = l10n.tickUndoStale;
  } on PeopleFailure catch (error) {
    failure = peopleFailureCopy(l10n, error);
  }
  if (failure != null && messenger.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(failure)));
  }
}
