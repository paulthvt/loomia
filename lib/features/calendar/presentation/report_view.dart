import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/features/calendar/domain/event_report.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A written report, read only: its [day], then each section that has text,
/// in order, and "Open event" with [onOpenEvent].
class ReportView extends StatelessWidget {
  const ReportView({
    required this.report,
    required this.day,
    this.onOpenEvent,
    super.key,
  });

  final List<ReportEntry> report;
  final DateTime day;
  final VoidCallback? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final open = onOpenEvent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        Text(
          l10n.reportDay(day),
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: colors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              for (final entry in report)
                if (entry.text.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        entry.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(entry.text, style: theme.textTheme.bodyLarge),
                    ],
                  ),
            ],
          ),
        ),
        if (open != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: open,
              child: Text(l10n.reportOpenEvent),
            ),
          ),
      ],
    );
  }
}

/// [report] under [title] (the report, by default): a bottom sheet on a
/// phone; elsewhere a side panel whose right edge meets the left of the
/// widget at [context], so the event pane beside it stays in view. It
/// closes before [onOpenEvent] runs.
Future<void> showReportSheet(
  BuildContext context, {
  required List<ReportEntry> report,
  required DateTime day,
  VoidCallback? onOpenEvent,
  String? title,
}) {
  final l10n = AppLocalizations.of(context);
  Widget body(BuildContext sheet) => ReportView(
    report: report,
    day: day,
    onOpenEvent: onOpenEvent == null
        ? null
        : () {
            Navigator.pop(sheet);
            onOpenEvent();
          },
  );
  final heading = title ?? l10n.eventReport;

  if (context.screenSize.isMobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xs,
          children: [
            Text(heading, style: Theme.of(sheet).textTheme.titleLarge),
            body(sheet),
          ],
        ),
      ),
    );
  }

  final box = context.findRenderObject() as RenderBox?;
  final left = box == null ? 0.0 : box.localToGlobal(Offset.zero).dx;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    pageBuilder: (panel, _, _) {
      final width = MediaQuery.sizeOf(panel).width;
      // Beside the widget when there is room for it, else on the right.
      final end = left >= _panelWidth ? width - left : 0.0;
      final colors = LoomiaColors.of(panel);
      return Stack(
        children: [
          PositionedDirectional(
            top: 0,
            bottom: 0,
            end: end,
            width: _panelWidth,
            child: Material(
              color: colors.surfaceRaised,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors.borderSubtle),
                    right: BorderSide(color: colors.borderSubtle),
                  ),
                ),
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              heading,
                              style: Theme.of(panel).textTheme.titleLarge,
                            ),
                          ),
                          const CloseButton(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      body(panel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// As in Figma's desktop side panel.
const double _panelWidth = 400;
