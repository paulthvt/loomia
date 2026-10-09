import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The header avatar that takes a photo (#239): a camera badge, a tap opens
/// Choose photo and, when there is one, Remove photo. While [onChoose] or
/// [onRemove] runs, a ring over the avatar and no badge; it takes no tap.
/// Errors are the caller's to show.
class AvatarControl extends StatefulWidget {
  const AvatarControl({
    required this.name,
    required this.onChoose,
    this.photo,
    this.onRemove,
    this.initiallyBusy = false,
    super.key,
  });

  final String name;
  final ImageProvider? photo;
  final Future<void> Function() onChoose;

  /// Null hides Remove photo: there is nothing to remove.
  final Future<void> Function()? onRemove;

  /// Previews only: the uploading state without a pending future, its ring
  /// still (at 60%, as in the Figma board) so a golden can settle.
  final bool initiallyBusy;

  @override
  State<AvatarControl> createState() => _AvatarControlState();
}

class _AvatarControlState extends State<AvatarControl> {
  late bool _busy = widget.initiallyBusy;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    const size = AvatarSize.header;
    final remove = widget.onRemove;
    final badge = AvatarSize.inline.diameter;

    return PopupMenuButton<Future<void> Function()>(
      tooltip: l10n.photoChange,
      enabled: !_busy,
      // The ink follows the avatar, not the square box it sits in.
      borderRadius: BorderRadius.circular(size.diameter / 2),
      onSelected: (action) => _run(action),
      // Under the avatar, as the Figma frames place it.
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: widget.onChoose,
          child: _Item(icon: Icons.image_outlined, label: l10n.photoChoose),
        ),
        if (remove != null)
          PopupMenuItem(
            value: remove,
            child: _Item(
              icon: Icons.delete_outline_rounded,
              label: l10n.photoRemove,
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: l10n.photoChange,
        excludeSemantics: true,
        child: SizedBox.square(
          // Room for the badge to sit on the edge without being clipped.
          dimension: size.diameter,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LoomiaAvatar(name: widget.name, size: size, photo: widget.photo),
              if (_busy)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: widget.initiallyBusy ? 0.6 : null,
                    color: scheme.primary,
                    backgroundColor: scheme.surface.withValues(alpha: 0.6),
                  ),
                )
              else
                Positioned(
                  right: -AppSpacing.xs / 2,
                  bottom: -AppSpacing.xs / 2,
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: badge * 0.55,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(spacing: AppSpacing.ms, children: [Icon(icon), Text(label)]);
}
