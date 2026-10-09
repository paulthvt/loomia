import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/activity_item.dart';
import 'package:loomia/core/ui/avatar_control.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/fact_row.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/loomia_wordmark.dart';
import 'package:loomia/core/ui/preview_photo.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/stat_tile.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Every shared component in one sheet, both modes, for
/// `flutter widget-preview start`. Nothing in the app imports this file.
@Preview(group: 'Components', name: 'Light', size: Size(420, 1800))
Widget uiComponentsLight() => _sheet(AppTheme.light);

@Preview(group: 'Components', name: 'Dark', size: Size(420, 1800))
Widget uiComponentsDark() => _sheet(AppTheme.dark);

Widget _sheet(ThemeData theme) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: const Scaffold(body: SafeArea(child: _Gallery())),
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const LoomiaTopBar(eyebrow: 'Monday 22 September', title: 'Components'),
        const SectionHeader(title: 'Wordmark'),
        Wrap(
          spacing: AppSpacing.lg,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            LoomiaWordmark(style: Theme.of(context).textTheme.displaySmall!),
            LoomiaWordmark(style: Theme.of(context).textTheme.headlineSmall!),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Avatar'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final size in AvatarSize.values) ...[
              LoomiaAvatar(name: 'Marie Dupont', size: size),
              const SizedBox(width: AppSpacing.sm),
            ],
            const LoomiaAvatarGroup(
              names: ['Marie Dupont', 'Lucas Morel', 'Amina Haddad', 'Karim B'],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final size in AvatarSize.values) ...[
              LoomiaAvatar(
                name: 'Claire Martin',
                size: size,
                photo: MemoryImage(previewPhoto),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          spacing: AppSpacing.lg,
          children: [
            AvatarControl(
              name: 'Claire Martin',
              photo: MemoryImage(previewPhoto),
              onChoose: () async {},
              onRemove: () async {},
            ),
            AvatarControl(name: 'Claire Martin', onChoose: () async {}),
            AvatarControl(
              name: 'Claire Martin',
              photo: MemoryImage(previewPhoto),
              onChoose: () async {},
              initiallyBusy: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Chip'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tone in ChipTone.values)
              LoomiaChip(label: tone.name, tone: tone),
            const DateChip('Birthday tomorrow'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Progress', actionLabel: '2'),
        const LoomiaProgressBar(
          value: 0.62,
          leadingLabel: 'Slightly behind pace',
          trailingLabel: '11 days left',
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Action item'),
        ActionItem(
          name: 'Marie Dupont',
          reason: 'Said she would decide after her holiday — she is back today',
          onOpen: () {},
          onResolve: () {},
        ),
        const SizedBox(height: AppSpacing.ms),
        ActionItem(
          name: 'Lucas Morel',
          reason: 'Turns 42 tomorrow',
          chip: const DateChip('Birthday tomorrow'),
          onOpen: () {},
          onResolve: () {},
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Contact row'),
        ContactRow(
          name: 'Marie Dupont',
          subtitle: 'Nurse',
          trailing: const LoomiaChip(label: 'Prospect'),
          onTap: () {},
        ),
        ContactRow(
          name: 'Lucas Morel',
          subtitle: 'Sleep, stress',
          trailing: const LoomiaChip(label: 'Customer'),
          selected: true,
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Fact row'),
        const FactRow(label: 'Needs', value: 'Sleep, stress, dry skin'),
        FactRow(label: 'Email', value: 'marie@example.com', onTap: () {}),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Stat tile'),
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: 'Followed up',
                  value: '18',
                  note: 'of 40 you aimed for',
                ),
              ),
              SizedBox(width: AppSpacing.ms),
              Expanded(
                child: StatTile(
                  label: 'Waiting on you',
                  value: '6',
                  note: 'oldest is 9 days',
                  tone: StatTone.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Goal card'),
        const GoalCard(
          title: 'New conversations',
          value: '24',
          suffix: 'of 40',
          progress: 24 / 40,
          pace: 'Slightly behind pace',
          behindPace: true,
          timeLeft: '11 days left',
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Activity'),
        const ActivityItem(title: 'Sophie Renard', meta: 'Yesterday · Message'),
        const ActivityItem(
          title: 'Karim Benali',
          meta: '2 days ago · Call',
          showRailLine: false,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Empty state'),
        EmptyState(
          icon: Icons.wb_twilight_rounded,
          title: 'You are up to date',
          body: 'Nothing is waiting on you today.',
          actionLabel: 'Browse contacts',
          onAction: () {},
        ),
      ],
    );
  }
}
