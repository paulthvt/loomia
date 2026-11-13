import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/loomia_card.dart';
import 'package:material_ui/material_ui.dart';

/// Token sheets for `flutter widget-preview start`. This is the visual check on
/// the theme: if a token is wrong, it is wrong here first.
///
/// Nothing in the app imports this file.
@Preview(group: 'Tokens', name: 'Colour — light', size: Size(420, 900))
Widget colourTokensLight() => _sheet(AppTheme.light, const _ColourSheet());

@Preview(group: 'Tokens', name: 'Colour — dark', size: Size(420, 900))
Widget colourTokensDark() => _sheet(AppTheme.dark, const _ColourSheet());

@Preview(group: 'Tokens', name: 'Type ramp — light', size: Size(420, 900))
Widget typeRampLight() => _sheet(AppTheme.light, const _TypeSheet());

@Preview(group: 'Tokens', name: 'Type ramp — dark', size: Size(420, 900))
Widget typeRampDark() => _sheet(AppTheme.dark, const _TypeSheet());

@Preview(group: 'Tokens', name: 'Spacing & shape', size: Size(420, 700))
Widget spacingTokens() => _sheet(AppTheme.light, const _ScaleSheet());

@Preview(group: 'Tokens', name: 'Components — light', size: Size(420, 760))
Widget componentsLight() => _sheet(AppTheme.light, const _ComponentSheet());

@Preview(group: 'Tokens', name: 'Components — dark', size: Size(420, 760))
Widget componentsDark() => _sheet(AppTheme.dark, const _ComponentSheet());

Widget _sheet(ThemeData theme, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.overline.copyWith(
              color: LoomiaColors.of(context).textMuted,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, {this.ink});

  final String name;
  final Color color;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: ink == null
                ? null
                : Text('Aa', style: AppTypography.label.copyWith(color: ink)),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(child: Text(name, style: AppTypography.bodySmall)),
          Text(
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ColourSheet extends StatelessWidget {
  const _ColourSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group('brand', [_Swatch('brand/base', colors.brand)]),
        _Group('surface', [
          _Swatch('surface/canvas', scheme.surface, ink: scheme.onSurface),
          _Swatch(
            'surface/default',
            colors.surfaceDefault,
            ink: scheme.onSurface,
          ),
          _Swatch(
            'surface/raised',
            colors.surfaceRaised,
            ink: scheme.onSurface,
          ),
          _Swatch(
            'surface/sunken',
            colors.surfaceSunken,
            ink: scheme.onSurface,
          ),
          _Swatch('surface/disabled', colors.surfaceDisabled),
        ]),
        _Group('border', [
          _Swatch('border/subtle', colors.borderSubtle),
          _Swatch('border/strong', colors.borderStrong),
        ]),
        _Group('text', [
          _Swatch('text/primary', scheme.onSurface),
          _Swatch('text/secondary', scheme.onSurfaceVariant),
          _Swatch('text/muted', colors.textMuted),
          _Swatch('text/disabled', colors.textDisabled),
        ]),
        _Group('primary', [
          _Swatch('primary/base', scheme.primary, ink: scheme.onPrimary),
          _Swatch('primary/hover', colors.primaryHover, ink: scheme.onPrimary),
          _Swatch('primary/text', colors.primaryText),
          _Swatch(
            'primary/container',
            scheme.primaryContainer,
            ink: scheme.onPrimaryContainer,
          ),
          _Swatch('primary/muted', colors.primaryMuted),
        ]),
        _Group('secondary', [
          _Swatch('secondary/base', scheme.secondary, ink: scheme.onSecondary),
          _Swatch('secondary/text', colors.secondaryText),
          _Swatch(
            'secondary/container',
            scheme.secondaryContainer,
            ink: scheme.onSecondaryContainer,
          ),
          _Swatch('secondary/track', colors.secondaryTrack),
        ]),
        _Group('accent — dates only', [
          _Swatch('accent/base', colors.accent),
          _Swatch(
            'accent/container',
            colors.accentContainer,
            ink: colors.onAccentContainer,
          ),
        ]),
        _Group('semantic', [
          _Swatch('success', colors.success),
          _Swatch('success/container', colors.successContainer),
          _Swatch('warning', colors.warning),
          _Swatch('warning/container', colors.warningContainer),
          _Swatch('error', scheme.error, ink: scheme.onError),
          _Swatch('error/container', scheme.errorContainer),
          _Swatch('info', colors.info),
          _Swatch('info/container', colors.infoContainer),
          _Swatch('state/focus', colors.focus),
        ]),
        _Group('horizon — hero & chrome', [
          _Swatch('chrome', colors.chrome, ink: colors.onChrome),
          _Swatch('chrome/muted', colors.onChromeMuted),
          _Swatch('hero/on', colors.onHero),
          _Swatch('hero/quiet', colors.onHeroQuiet),
          _Swatch('hero/fill', colors.heroFill),
          _Swatch('hero/fill-subtle', colors.heroFillSubtle),
          _Swatch('hero-card/border', colors.heroCardBorder),
          _Swatch('chrome/border', colors.chromeBorder),
        ]),
      ],
    );
  }
}

class _TypeSheet extends StatelessWidget {
  const _TypeSheet();

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final rows = <(String, TextStyle)>[
      ('display 32/38', AppTypography.display),
      ('headline 24/30', AppTypography.headline),
      ('title-lg 20/26', AppTypography.titleLarge),
      ('title 17/24', AppTypography.title),
      ('body-lg 16/24', AppTypography.bodyLarge),
      ('body 15/22', AppTypography.body),
      ('body-sm 13/18', AppTypography.bodySmall),
      ('label-lg 15/20', AppTypography.labelLarge),
      ('label 13/16', AppTypography.label),
      ('caption 12/16', AppTypography.caption),
      ('overline 11/14', AppTypography.overline),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group('ramp', [
          for (final (name, style) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.ms),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.caption.copyWith(
                      color: LoomiaColors.of(context).textMuted,
                    ),
                  ),
                  Text(
                    'Call Marie before Friday',
                    style: style.copyWith(color: ink),
                  ),
                ],
              ),
            ),
        ]),
        _Group('numerals — tabular', [
          Text(
            '1 240 / 1 500',
            style: AppTypography.numericLarge.copyWith(color: ink),
          ),
          Text('11 111', style: AppTypography.numeric.copyWith(color: ink)),
        ]),
      ],
    );
  }
}

class _ScaleSheet extends StatelessWidget {
  const _ScaleSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    const spacing = <(String, double)>[
      ('xs', AppSpacing.xs),
      ('sm', AppSpacing.sm),
      ('ms', AppSpacing.ms),
      ('md', AppSpacing.md),
      ('lg', AppSpacing.lg),
      ('xl', AppSpacing.xl),
      ('xxl', AppSpacing.xxl),
      ('xxxl', AppSpacing.xxxl),
    ];
    const radii = <(String, double)>[
      ('sm', AppRadii.sm),
      ('md', AppRadii.md),
      ('lg', AppRadii.lg),
      ('xl', AppRadii.xl),
      ('pill', AppRadii.pill),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group('space', [
          for (final (name, value) in spacing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(name, style: AppTypography.label),
                  ),
                  Container(width: value, height: 12, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${value.toInt()}',
                    style: AppTypography.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ]),
        _Group('radius', [
          Wrap(
            spacing: AppSpacing.ms,
            runSpacing: AppSpacing.ms,
            children: [
              for (final (name, value) in radii)
                Container(
                  width: 72,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    border: Border.all(color: colors.borderStrong),
                    borderRadius: BorderRadius.circular(value),
                  ),
                  child: Text(name, style: AppTypography.label),
                ),
            ],
          ),
        ]),
        _Group('elevation — overlays only', [
          Row(
            children: [
              for (final (name, shadow) in const <(String, List<BoxShadow>)>[
                ('raised', AppElevation.raised),
                ('overlay', AppElevation.overlay),
              ])
                Container(
                  width: 96,
                  height: 64,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: shadow,
                  ),
                  child: Text(name, style: AppTypography.label),
                ),
            ],
          ),
        ]),
      ],
    );
  }
}

class _ComponentSheet extends StatelessWidget {
  const _ComponentSheet();

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group('buttons', [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Log a call')),
              OutlinedButton(onPressed: () {}, child: const Text('Snooze')),
              TextButton(onPressed: () {}, child: const Text('Skip')),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
              const FilledButton(onPressed: null, child: Text('Disabled')),
            ],
          ),
        ]),
        const _Group('field', [
          TextField(decoration: InputDecoration(hintText: 'Search people')),
        ]),
        _Group('card + chips', [
          LoomiaCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marie Dupont',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Promised to call back after her trip',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.ms),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      Chip(
                        label: const Text('Birthday Friday'),
                        backgroundColor: colors.accentContainer,
                        labelStyle: AppTypography.caption.copyWith(
                          color: colors.onAccentContainer,
                        ),
                      ),
                      const Chip(label: Text('Customer')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
        const _Group('progress — pace, not judgement', [
          LinearProgressIndicator(value: 0.62),
        ]),
      ],
    );
  }
}
