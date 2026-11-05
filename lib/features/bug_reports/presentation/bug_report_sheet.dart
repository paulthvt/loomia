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
  final _comment = TextEditingController();

  @override
  void dispose() {
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
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.bugReportCommentLabel,
              helperText: l10n.bugReportCommentHelper,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListenableBuilder(
            listenable: _comment,
            builder: (context, _) => FilledButton(
              onPressed: _comment.text.trim().isEmpty
                  ? null
                  : () => widget.onSubmit(_comment.text.trim()),
              child: Text(l10n.bugReportSend),
            ),
          ),
        ],
      ),
    );
  }
}
