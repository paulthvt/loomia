import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/avatar_control.dart';
import 'package:loomia/core/ui/fact_row.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/edit_person_form.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:loomia/features/sharing/presentation/contact_sharing_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The digits and `+` of a phone number, which is what `tel:` and `sms:` want.
String _dialable(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

/// A text when there is a phone, else Instagram, else nothing.
Uri? messageUri(Person person) {
  final phone = person.phone;
  if (phone != null) return Uri(scheme: 'sms', path: _dialable(phone));
  var handle = person.instagram?.trim();
  if (handle != null) {
    if (handle.startsWith('@')) handle = handle.substring(1);
    return Uri.https('instagram.com', '/$handle');
  }
  return null;
}

Uri? callUri(Person person) {
  final phone = person.phone;
  return phone == null ? null : Uri(scheme: 'tel', path: _dialable(phone));
}

typedef _Action = ({
  String label,
  IconData icon,
  VoidCallback onTap,
  String? trailing,
});

/// One person: who they are, how to reach them, where it stands, what's next,
/// what you know. A pure view; the page owns saving and navigation.
class ContactDetails extends StatelessWidget {
  /// WHAT YOU KNOW's column on desktop, beside the rest.
  static const double _factsWidth = 340;

  const ContactDetails({
    required this.person,
    required this.model,
    required this.onStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onLog,
    required this.onMove,
    required this.onChangeWorkflow,
    required this.onPause,
    required this.onResume,
    required this.onLaunch,
    required this.onRefresh,
    required this.onChoosePhoto,
    required this.onRemovePhoto,
    required this.onLoyalty,
    required this.tags,
    required this.onTags,
    required this.onInvite,
    required this.onStopSharing,
    this.sharing,
    this.photo,
    this.workflowName,
    this.nextStep,
    this.history,
    super.key,
  });

  final Person person;

  /// Which words a team member's rank and volume use.
  final BusinessModel model;

  /// The tapped status, or null when the selected one was tapped again.
  final ValueChanged<ProspectStatus?> onStatus;

  /// Called with the part to edit: a section's own, or everything from ⋯.
  final ValueChanged<EditPart> onEdit;

  /// Called once the user has confirmed.
  final VoidCallback onDelete;
  final ValueChanged<Uri> onLaunch;
  final Future<void> Function() onRefresh;
  final VoidCallback onLog;

  /// Called with the stage picked in ⋯; the page confirms and saves.
  final ValueChanged<Stage> onMove;

  final VoidCallback onChangeWorkflow;
  final VoidCallback onPause;
  final VoidCallback onResume;

  /// Their photo, resolved by the page; null shows initials.
  final ImageProvider? photo;

  /// Opens the picker and saves what comes back. The avatar shows a ring
  /// until it completes.
  final Future<void> Function() onChoosePhoto;

  /// Offered only when they have a photo.
  final Future<void> Function() onRemovePhoto;

  /// Opens the LRP sheet; offered to customers and team members.
  final VoidCallback onLoyalty;

  /// Their tags, resolved and sorted (#332).
  final List<Tag> tags;

  /// Opens the tag sheet.
  final VoidCallback onTags;

  /// What a team member shares, or the invite out to them; null until it
  /// loads, and for anyone not on the team.
  final ContactSharing? sharing;

  /// Opens the invite sheet.
  final VoidCallback onInvite;

  /// Called once the user has confirmed.
  final VoidCallback onStopSharing;

  /// The current workflow's name, shown beside Change workflow in ⋯.
  final String? workflowName;

  /// The `NEXT STEP` section, between where it stands and what you know.
  final Widget? nextStep;

  /// The `HISTORY` section, below what you know.
  final Widget? history;

  List<_Action> _actions(AppLocalizations l10n) => [
    (
      label: l10n.contactLogSomething,
      icon: Icons.edit_note_rounded,
      onTap: onLog,
      trailing: null,
    ),
    for (final stage in Stage.values)
      if (stage != person.stage)
        (
          label: moveToLabel(l10n, stage),
          icon: Icons.swap_horiz_rounded,
          onTap: () => onMove(stage),
          trailing: null,
        ),
    (
      label: l10n.contactChangeWorkflow,
      icon: Icons.alt_route_rounded,
      onTap: onChangeWorkflow,
      trailing: workflowName,
    ),
    if (person.pausedAt == null)
      (
        label: l10n.contactPause,
        icon: Icons.pause_circle_outline_rounded,
        onTap: onPause,
        trailing: null,
      )
    else
      (
        label: l10n.contactResume,
        icon: Icons.play_circle_outline_rounded,
        onTap: onResume,
        trailing: null,
      ),
    (
      label: l10n.contactEditDetails,
      icon: Icons.edit_outlined,
      onTap: () => onEdit(EditPart.everything),
      trailing: null,
    ),
  ];

  /// A sheet on mobile, a menu elsewhere; the same items either way.
  Widget _more(BuildContext context, AppLocalizations l10n) {
    final actions = _actions(l10n);
    final _Action delete = (
      label: l10n.contactDeleteName(firstName(person)),
      icon: Icons.delete_outline_rounded,
      onTap: () => _confirmDelete(context),
      trailing: null,
    );
    const icon = Icon(Icons.more_horiz_rounded);

    if (context.screenSize.isMobile) {
      return IconButton(
        tooltip: l10n.contactMore,
        icon: icon,
        onPressed: () async {
          final chosen = await showModalBottomSheet<VoidCallback>(
            context: context,
            // Sized to its items, not capped at 9/16 of the screen.
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _MoreSheet(
              title: person.name,
              actions: actions,
              delete: delete,
            ),
          );
          // Run once the sheet is gone, from this page's context.
          if (!context.mounted) return;
          chosen?.call();
        },
      );
    }
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.contactMore,
      icon: icon,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action.onTap,
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(child: Text(action.label)),
                if (action.trailing case final trailing?)
                  Text(
                    trailing,
                    style: TextStyle(color: LoomiaColors.of(context).textMuted),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: delete.onTap,
          child: Text(delete.label, style: TextStyle(color: error)),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.contactDeleteTitle(person.name),
      body: l10n.contactDeleteBody,
      action: l10n.contactDeleteConfirm,
    );
    if (confirmed) onDelete();
  }

  Future<void> _confirmStopSharing(BuildContext context, String name) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.contactStopSharingTitle(name),
      body: l10n.contactStopSharingBody,
      action: l10n.sharingStopAction,
    );
    if (confirmed) onStopSharing();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final message = messageUri(person);
    final call = callUri(person);
    final email = person.email;
    final status = person.prospectStatus;
    final facts = [
      (l10n.factNeeds, person.needs, null),
      (l10n.factProducts, person.products, null),
      (l10n.factProfession, person.profession, null),
      (l10n.factPhone, person.phone, null),
      (
        l10n.factEmail,
        email,
        email == null ? null : Uri(scheme: 'mailto', path: email),
      ),
      (l10n.factInstagram, person.instagram, null),
      (l10n.factAddress, person.address, null),
      (l10n.factNotes, person.notes, null),
    ];

    final desktop = context.screenSize.isDesktop;
    final more = _more(context, l10n);

    final buttons = [
      if (message != null)
        FilledButton.icon(
          onPressed: () => onLaunch(message),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: Text(l10n.contactMessage),
        ),
      if (call != null)
        FilledButton.tonalIcon(
          onPressed: () => onLaunch(call),
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.call_outlined),
          label: Text(l10n.contactCall),
        ),
    ];

    // "LRP · Since Oct 2" or "LRP · None", in the action colour: it opens
    // the LRP sheet (#255).
    Widget loyalty() {
      final label = l10n.loyaltyLabel(model.name);
      final since = person.loyaltySince;
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onLoyalty,
          iconAlignment: IconAlignment.end,
          // 32px, as the SectionHeader action: it sits tight under the
          // chip in Figma, and 32 still clears the 24px minimum target.
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.chevron_right),
          label: Text(switch ((since, person.loyaltyDay)) {
            (null, _) => l10n.contactLoyaltyNone(label),
            (final since?, final day) => switch (since.year ==
                    DateTime.now().year
                ? l10n.contactLoyaltySince(label, since)
                : l10n.contactLoyaltySinceWithYear(label, since)) {
              final line when day != null => l10n.contactLoyaltyRenews(
                line,
                day,
              ),
              final line => line,
            },
          }, style: AppTypography.label),
        ),
      );
    }

    final header = Row(
      crossAxisAlignment: desktop
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        AvatarControl(
          name: person.name,
          photo: photo,
          onChoose: onChoosePhoto,
          onRemove: person.photoPath == null ? null : onRemovePhoto,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Text(
                person.name,
                style: desktop
                    ? theme.textTheme.displaySmall
                    : theme.textTheme.headlineSmall,
              ),
              Text(
                l10n.contactSince(
                  stageLabel(l10n, person.stage),
                  person.stageSince.toLocal(),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              LoomiaChip(label: stageLabel(l10n, person.stage)),
              if (person.stage != Stage.prospect) loyalty(),
              Wrap(
                spacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in tags)
                    TagChip(label: tag.name, color: tag.color, onTap: onTags),
                  TagAction(empty: tags.isEmpty, onTap: onTags),
                ],
              ),
            ],
          ),
        ),
        // Desktop: the buttons sit in the header, sized to their labels.
        if (desktop) ...[
          for (final button in buttons) ...[
            const SizedBox(width: AppSpacing.sm),
            button,
          ],
          const SizedBox(width: AppSpacing.sm),
          more,
        ],
      ],
    );

    final whereItStands = [
      if (person.stage == Stage.prospect) ...[
        SectionHeader(title: l10n.contactSectionWhereItStands),
        // Each chip already pads itself to the 48px tap target.
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final option in ProspectStatus.values)
              ChoiceChip(
                label: Text(statusLabel(l10n, option)),
                selected: option == status,
                onSelected: (_) => onStatus(option == status ? null : option),
              ),
          ],
        ),
      ],
    ];

    Widget muted(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
      ),
    );
    Widget card(List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    // Facts with a value, under a header that edits them all.
    List<Widget> factsSection(
      String title,
      EditPart part,
      List<(String, String?, Uri?)> all,
    ) {
      final facts = all.where((fact) => fact.$2 != null);
      return [
        SectionHeader(
          title: title,
          actionLabel: l10n.contactEdit,
          onAction: () => onEdit(part),
        ),
        card([
          if (facts.isEmpty)
            muted(l10n.contactNothingYet)
          else
            for (final (label, value, link) in facts)
              FactRow(
                label: label,
                value: value!,
                onTap: link == null ? null : () => onLaunch(link),
              ),
        ]),
      ];
    }

    // Sharing shows only while they are on the team, like their aims.
    final sharing = person.stage == Stage.team ? this.sharing : null;
    final shared = sharing?.shared;
    final aboutMeShared = shared?.items.contains(ShareItem.aboutMe) ?? false;
    String? aimingForValue(String? level) =>
        switch ((level, person.targetLevelBy)) {
          (final String level, final DateTime by) => l10n.factAimingForBy(
            level,
            by,
          ),
          (final level, _) => level,
        };

    // What they share, in place of what you typed: never a fallback to your
    // notes, so it stays clear what came from them.
    List<Widget> sharedSection(SharedGoals shared) {
      // Their account may have no first name: the one you know them by.
      final name = shared.memberFirstName.isEmpty
          ? person.name
          : shared.memberFirstName;
      final plan = shared.plan;
      final done = shared.items.contains(ShareItem.progress)
          ? shared.progress
          : null;
      final number = NumberFormat.decimalPattern(l10n.localeName);
      double? ratio(num value, num target) =>
          target > 0 ? value / target : null;
      String written(String? value) => value == null || value.trim().isEmpty
          ? l10n.contactSharedNotWritten(name)
          : value;
      Widget row(String label, String value, [double? progress]) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow(label: label, value: value),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: LoomiaProgressBar(value: progress),
            ),
        ],
      );

      return [
        SectionHeader(
          title: l10n.contactSharedBy(name),
          trailing: PopupMenuButton<void>(
            tooltip: l10n.contactMore,
            icon: const Icon(Icons.more_vert_rounded),
            // 32px, as the header's action.
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => _confirmStopSharing(context, name),
                child: Text(l10n.sharingStopButton),
              ),
            ],
          ),
        ),
        card([
          if (shared.levelNow case final level?)
            row(l10n.factLevelNow(model.name), level),
          if (plan == null)
            muted(l10n.contactSharedNoMonth(name))
          else ...[
            if (aimingForValue(plan.levelTarget) case final level?)
              row(l10n.factAimingFor, level),
            if (plan.ownVolumeTarget case final target?)
              done == null
                  ? row(
                      l10n.goalOwnVolume,
                      l10n.factEachMonthValue(model.name, target),
                    )
                  : row(
                      l10n.goalOwnVolume,
                      l10n.contactSharedVolumeOf(
                        model.name,
                        number.format(done.ownVolume),
                        number.format(target),
                      ),
                      ratio(done.ownVolume, target),
                    ),
            // No bar: team volume is typed at close, never tracked.
            if (plan.teamVolumeTarget case final target?)
              row(
                l10n.contactSharedTeamVolume,
                l10n.contactSharedTeamVolumeValue(model.name, target),
              ),
            if (shared.items.contains(ShareItem.activityTargets))
              for (final (label, target, value) in [
                (l10n.goalNewProspects, plan.prospectsTarget, done?.prospects),
                (l10n.goalNewCustomers, plan.customersTarget, done?.customers),
                (
                  l10n.goalNewTeamMembers,
                  plan.teamMembersTarget,
                  done?.teamMembers,
                ),
                (
                  l10n.goalLoyalty(model.name),
                  plan.loyaltyTarget,
                  done?.loyalty,
                ),
              ])
                if (target != null)
                  value == null
                      ? row(label, l10n.contactSharedAimsFor(target))
                      : row(
                          label,
                          l10n.contactSharedCountOf(value, target),
                          ratio(value, target),
                        ),
          ],
          if (aboutMeShared) ...[
            row(l10n.factWhy, written(shared.why)),
            row(l10n.factOwnGoal, written(shared.ownGoal)),
          ],
        ]),
      ];
    }

    // Their own aims, in their words: nothing to rank or compare. A rank is a
    // fact they told you, never summed or shown elsewhere. What they share
    // takes the place of the rows it covers; the rest stays yours.
    final aimingFor = person.stage == Stage.team
        ? [
            ...factsSection(l10n.contactSectionAimingFor, EditPart.aims, [
              if (!aboutMeShared) (l10n.factWhy, person.why, null),
              if (shared == null) ...[
                (l10n.factLevelNow(model.name), person.currentLevel, null),
                (l10n.factAimingFor, aimingForValue(person.targetLevel), null),
                (
                  l10n.factEachMonth,
                  switch (person.monthlyVolumeTarget) {
                    final double amount => l10n.factEachMonthValue(
                      model.name,
                      amount,
                    ),
                    null => null,
                  },
                  null,
                ),
              ],
              if (!aboutMeShared) (l10n.factOwnGoal, person.ownGoal, null),
              (l10n.factTimeAvailable, person.timeAvailable, null),
              (l10n.factWouldLoveTo, person.wouldLoveTo, null),
              (l10n.factStrengths, person.strengths, null),
              (l10n.factStuckOn, person.stuckOn, null),
            ]),
            if (sharing case (shared: null, invite: null)) ...[
              const SizedBox(height: AppSpacing.ms),
              FilledButton.tonal(
                onPressed: onInvite,
                style: AppTheme.tonal(context),
                child: Text(l10n.contactInviteToShare),
              ),
            ] else if (sharing?.invite case final invite?) ...[
              const SizedBox(height: AppSpacing.ms),
              card([
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.xs,
                          children: [
                            Text(
                              l10n.contactInviteSent(formatCode(invite.code)),
                              style: theme.textTheme.bodyLarge,
                            ),
                            Text(
                              l10n.contactInviteUntil(
                                invite.expiresAt.toLocal(),
                              ),
                              style: AppTypography.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onInvite,
                      child: Text(l10n.contactShareAgain),
                    ),
                  ],
                ),
              ]),
            ],
          ]
        : <Widget>[];
    final sharedGoals = shared == null ? <Widget>[] : sharedSection(shared);
    final whatYouKnow = factsSection(
      l10n.contactSectionWhatYouKnow,
      EditPart.facts,
      facts,
    );

    // Sections with the same gap between each, none above the first.
    List<Widget> spaced(List<List<Widget>> sections) => [
      for (final (index, section)
          in sections.where((section) => section.isNotEmpty).indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.lg),
        ...section,
      ],
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
        children: desktop
            ? [
                header,
                const SizedBox(height: AppSpacing.lg),
                ContentColumns(
                  sideWidth: _factsWidth,
                  main: spaced([
                    whereItStands,
                    [?nextStep],
                    [?history],
                  ]),
                  side: spaced([sharedGoals, aimingFor, whatYouKnow]),
                ),
              ]
            : spaced([
                [
                  header,
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      // Side by side at their own width; stacked when a large
                      // text size or a longer translation would not fit, so
                      // a label never breaks mid-word.
                      Expanded(
                        child: OverflowBar(
                          spacing: AppSpacing.sm,
                          overflowSpacing: AppSpacing.sm,
                          children: buttons,
                        ),
                      ),
                      more,
                    ],
                  ),
                ],
                whereItStands,
                [?nextStep],
                sharedGoals,
                aimingFor,
                whatYouKnow,
                [?history],
              ]),
      ),
    );
  }
}

/// ⋯ on mobile: the person's name, their actions, then Delete apart.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.title,
    required this.actions,
    required this.delete,
  });

  final String title;
  final List<_Action> actions;
  final _Action delete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    Widget tile(_Action action, {Color? color}) => ListTile(
      leading: Icon(action.icon, color: color),
      title: Text(action.label, style: TextStyle(color: color)),
      trailing: switch (action.trailing) {
        final text? => Text(
          text,
          style: TextStyle(color: LoomiaColors.of(context).textMuted),
        ),
        null => null,
      },
      onTap: () => Navigator.pop(context, action.onTap),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            SettingsGroup(children: [for (final a in actions) tile(a)]),
            SettingsGroup(children: [tile(delete, color: error)]),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
