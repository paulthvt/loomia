import 'package:feedback/feedback.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Loomia's own sheet under the `feedback` panel (#463), in place of the
/// package's, which is built on the frozen `flutter/material.dart` and would
/// not follow the app's theme. Matches `FeedbackBuilder`.
Widget bugReportSheet(
  BuildContext context,
  OnSubmit onSubmit,
  ScrollController? scrollController,
) => _BugReportSheet(onSubmit: onSubmit, scrollController: scrollController);

class _BugReportSheet extends StatefulWidget {
  const _BugReportSheet({required this.onSubmit, this.scrollController});

  final OnSubmit onSubmit;
  final ScrollController? scrollController;

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _title = TextEditingController();
  final _comment = TextEditingController();

  /// The package waits for the report to go before closing the panel.
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(
        _comment.text.trim(),
        extras: {'title': _title.text.trim()},
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The package hosts this in its own (frozen) Material; material_ui's
    // TextField needs one of ours.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // The GitHub issue's title (#467). Both fields are public, so the
          // warning sits under the one every report has.
          TextField(
            controller: _title,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.bugReportTitleLabel,
              helperText: l10n.bugReportCommentHelper,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.bugReportCommentLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          ListenableBuilder(
            listenable: _title,
            builder: (context, _) => FilledButton(
              onPressed: _sending || _title.text.trim().isEmpty ? null : _send,
              child: _sending
                  ? const SizedBox.square(
                      dimension: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.bugReportSend),
            ),
          ),
        ],
      ),
    );
  }
}
