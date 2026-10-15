import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// The tag palette as chips (#332): each colour plain, off and on, then the
/// row dots and the add / edit actions. Nothing in the app imports this file.
@Preview(group: 'Components', name: 'Tags — light', size: Size(420, 640))
Widget tagsLight() => _sheet(AppTheme.light);

@Preview(group: 'Components', name: 'Tags — dark', size: Size(420, 640))
Widget tagsDark() => _sheet(AppTheme.dark);

Widget _sheet(ThemeData theme) => MaterialApp(
  debugShowCheckedModeBanner: false,
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final color in TagColor.values)
          Row(
            spacing: AppSpacing.sm,
            children: [
              TagChip(label: color.name, color: color),
              TagChip(label: color.name, color: color, selected: false),
              TagChip(label: color.name, color: color, selected: true),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          spacing: AppSpacing.lg,
          children: [
            TagDots(
              tags: [
                for (final color in TagColor.values.take(2))
                  (name: color.name, color: color),
              ],
            ),
            TagDots(
              tags: [
                for (final color in TagColor.values.take(5))
                  (name: color.name, color: color),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          spacing: AppSpacing.sm,
          children: [
            TagAction(empty: true, onTap: () {}),
            TagAction(empty: false, onTap: () {}),
          ],
        ),
      ],
    ),
  ),
);
