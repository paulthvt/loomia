import 'dart:math' as math;

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:material_ui/material_ui.dart';

/// A person in a list: avatar, name, one line of context, a trailing chip.
class ContactRow extends StatelessWidget {
  const ContactRow({
    required this.name,
    this.subtitle,
    this.trailing,
    this.selected = false,
    this.checked,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String name;
  final String? subtitle;
  final Widget? trailing;

  /// The person open beside the list, on desktop.
  final bool selected;

  /// Picked, while several people are being picked: the avatar turns over to
  /// a check. Null while not picking.
  final bool? checked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = subtitle;
    return ListTile(
      selected: selected || (checked ?? false),
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      hoverColor: LoomiaColors.of(context).surfaceSunken,
      leading: Semantics(
        checked: checked,
        child: _Face(name: name, turned: checked ?? false),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: text == null
          ? null
          : Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// The avatar, or its back — a check — once [turned]: it turns over on its
/// vertical axis, narrowing to an edge then widening as the other face.
/// Reduce motion: a crossfade.
class _Face extends StatelessWidget {
  const _Face({required this.name, required this.turned});

  final String name;
  final bool turned;

  @override
  Widget build(BuildContext context) {
    final front = LoomiaAvatar(name: name, size: AvatarSize.row);
    const back = _Check();
    if (context.reduceMotion) {
      return AnimatedSwitcher(
        duration: context.motion(AppMotion.medium),
        child: turned ? back : front,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: turned ? 1 : 0),
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      builder: (context, turn, _) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          math.cos(turn * math.pi).abs(),
          1,
          1,
        ),
        child: turn < 0.5 ? front : back,
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: AvatarSize.row.diameter,
      height: AvatarSize.row.diameter,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, color: scheme.onPrimary),
    );
  }
}
