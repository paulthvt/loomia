import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// In place of a screen or section that could not load (#46). [offline]
/// (the caller's `error == PeopleFailure.network`) says so whatever the
/// screen; anything else keeps [title] and does not blame the connection.
class LoadFailed extends StatelessWidget {
  const LoadFailed({
    required this.offline,
    required this.title,
    required this.onRetry,
    super.key,
  });

  final bool offline;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: offline ? l10n.offlineTitle : title,
        body: offline ? l10n.offlineBody : l10n.loadFailedBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}
