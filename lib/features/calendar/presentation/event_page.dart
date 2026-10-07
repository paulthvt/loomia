import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One event on mobile and tablet: a screen of its own above the month.
class EventPage extends StatelessWidget {
  const EventPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.calendar)),
      ),
      body: SafeArea(top: false, child: EventPane(id: id)),
    );
  }
}

/// An event found in the loaded calendar (there is no second fetch), wired
/// to editing, deleting and the other apps. Shared by [EventPage] and the
/// desktop pane.
class EventPane extends ConsumerWidget {
  const EventPane({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    final events = ref.watch(provider);
    final list = events.value;
    if (list == null) {
      return events.hasError
          ? Center(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l10n.calendarLoadFailed,
                body: l10n.contactsLoadErrorBody,
                actionLabel: l10n.contactsRetry,
                onAction: () => ref.invalidate(provider),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final event = list.where((event) => event.id == id).firstOrNull;
    if (event == null) {
      return Center(
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.eventNotFound,
          body: l10n.eventNotFoundBody,
        ),
      );
    }
    return EventView(
      event: event,
      onEdit: () => unawaited(showEventForm(context, event: event)),
      onDelete: () => unawaited(_delete(context, ref, event)),
      onOpenPlace: (place) => unawaited(
        openExternal(
          context,
          mapsUri(
            place,
            apple: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          ),
        ),
      ),
      onJoin: (link) => unawaited(openExternal(context, link)),
    );
  }

  /// Leaves the event first, so its screen never shows it missing.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final confirmed = await confirmDestructive(
      context,
      title: l10n.eventDeleteTitle(event.title),
      body: l10n.eventDeleteBody,
      action: l10n.eventDeleteAction,
    );
    if (!confirmed || !context.mounted) return;
    if (context.screenSize.isDesktop) {
      context.go(Routes.calendar);
    } else {
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.calendar);
      await leaving?.completed;
    }
    try {
      await events.remove(event.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// The event as a function of its inputs, for previews and tests.
class EventView extends StatelessWidget {
  const EventView({
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenPlace,
    required this.onJoin,
    super.key,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Opens the maps app on the place.
  final void Function(String place) onOpenPlace;
  final void Function(Uri link) onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = event.place;
    final link = event.link;
    final notes = event.notes;

    return ListView(
      padding: EdgeInsets.all(
        context.screenSize.isDesktop ? AppSpacing.lg : AppSpacing.md,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(event.title, style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: l10n.eventEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.eventDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.ms),
        _Line(icon: Icons.schedule_rounded, text: whenLabel(context, event)),
        if (place != null)
          _Line(
            icon: Icons.place_outlined,
            text: place,
            onTap: () => onOpenPlace(place),
          ),
        if (link != null)
          _Line(
            icon: Icons.videocam_outlined,
            text: shownLink(link),
            trailing: FilledButton.tonal(
              style: AppTheme.tonal(context),
              onPressed: () => onJoin(Uri.parse(link)),
              child: Text(l10n.eventJoin),
            ),
          ),
        if (notes != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              notes,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// An icon and a line. With [onTap], the line reads as a link.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tap = onTap;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(icon, color: muted),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: tap == null
                    ? muted
                    : LoomiaColors.of(context).primaryText,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return tap == null
        ? row
        : Semantics(
            link: true,
            child: InkWell(onTap: tap, child: row),
          );
  }
}
