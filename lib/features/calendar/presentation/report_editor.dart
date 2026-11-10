import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/event_report.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [event]'s report, one field per entry, saved on its own a second after
/// the last keystroke and when the screen goes, so nothing typed is lost.
/// Kept alive in a scrolling list, so its fields keep what was typed even
/// when a save failed. Its labels are [entries]' as it opens: key it by the
/// event and the labels (see [reportEditorKey]).
class ReportEditor extends ConsumerStatefulWidget {
  const ReportEditor({required this.event, required this.entries, super.key});

  final CalendarEvent event;
  final List<ReportEntry> entries;

  @override
  ConsumerState<ReportEditor> createState() => _ReportEditorState();
}

/// A new template (the event's type changed) builds a new editor.
Key reportEditorKey(CalendarEvent event, List<ReportEntry> entries) =>
    ValueKey((event.id, [for (final entry in entries) entry.label].join('\n')));

class _ReportEditorState extends ConsumerState<ReportEditor>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final _fields = [
    for (final entry in widget.entries) TextEditingController(text: entry.text),
  ];
  Timer? _pending;
  var _saved = false;

  // One save at a time, whole report each: overlapping ones could land out
  // of order. [_version] counts edits, [_savedVersion] is the last one a
  // save succeeded with.
  Future<void>? _inFlight;
  var _version = 0;
  var _savedVersion = 0;
  bool get _dirty => _version != _savedVersion;

  // Read on the first keystroke, as `ref` and the context are gone by
  // dispose, where a pending save still has to go out.
  EventsController? _events;
  ScaffoldMessengerState? _messenger;
  String? _failed;

  List<ReportEntry> get _entries => [
    for (final (index, entry) in widget.entries.indexed)
      (label: entry.label, text: _fields[index].text),
  ];

  void _changed(String _) {
    _events ??= ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    _messenger ??= ScaffoldMessenger.maybeOf(context);
    _failed ??= AppLocalizations.of(context).eventReportSaveFailed;
    _version++;
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 1), _save);
    if (_saved) setState(() => _saved = false);
  }

  /// Sends the fields now, or once the save out lands.
  void _save() {
    _pending = null;
    if (_inFlight != null) return;
    final version = _version;
    _inFlight = _send(_entries, version).whenComplete(() {
      _inFlight = null;
      if (!mounted) return;
      // Typed while it was out: those words go next. A failure on the same
      // words waits for the next keystroke or the screen going, not a loop.
      if (version != _version && _pending == null) _save();
      setState(() => _saved = !_dirty);
    });
  }

  Future<void> _send(List<ReportEntry> entries, int version) async {
    try {
      await _events?.saveReport(widget.event.id, entries);
      _savedVersion = version;
    } on PeopleFailure {
      _messenger?.showSnackBar(SnackBar(content: Text(_failed ?? '')));
    }
  }

  @override
  void dispose() {
    // Unsaved words, a failed save's included, go out after any save still
    // out, read now as the fields go with this state.
    if (_dirty) {
      _pending?.cancel();
      final entries = _entries;
      final version = _version;
      final inFlight = _inFlight;
      // Now when nothing is out: the controller may go with this screen.
      unawaited(
        inFlight == null
            ? _send(entries, version)
            : inFlight.then((_) async {
                if (_dirty) await _send(entries, version);
              }),
      );
    }
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final muted = LoomiaColors.of(context).textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.eventReport,
          trailing: _saved
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: muted),
                    Text(
                      l10n.eventReportSaved,
                      style: AppTypography.caption.copyWith(color: muted),
                    ),
                  ],
                )
              : null,
        ),
        for (final (index, entry) in widget.entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: LabeledField(
              label: entry.label,
              child: TextField(
                controller: _fields[index],
                onChanged: _changed,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
      ],
    );
  }
}
