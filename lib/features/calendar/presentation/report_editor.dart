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
/// Its labels are [entries]' as it opens: key it by the event.
class ReportEditor extends ConsumerStatefulWidget {
  const ReportEditor({required this.event, required this.entries, super.key});

  final CalendarEvent event;
  final List<ReportEntry> entries;

  @override
  ConsumerState<ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends ConsumerState<ReportEditor> {
  late final _fields = [
    for (final entry in widget.entries) TextEditingController(text: entry.text),
  ];
  Timer? _pending;
  var _saved = false;

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
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 1), _save);
    if (_saved) setState(() => _saved = false);
  }

  Future<void> _save() async {
    _pending = null;
    try {
      await _events?.saveReport(widget.event.id, _entries);
      if (mounted) setState(() => _saved = true);
    } on PeopleFailure {
      _messenger?.showSnackBar(SnackBar(content: Text(_failed ?? '')));
    }
  }

  @override
  void dispose() {
    if (_pending != null) {
      _pending?.cancel();
      unawaited(_save());
    }
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
