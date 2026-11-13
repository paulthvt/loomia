import 'package:feedback/feedback.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The only place `ThemeData` is built. Component styling lives here so widgets
/// stay style-free (`docs/design/design-system.md` §8).
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, LoomiaColors.light);
  static ThemeData get dark => _build(AppColors.dark, LoomiaColors.dark);

  /// The bug report panel's own toolbar and backdrop (#463), from [scheme].
  /// No red pen: red stays for errors.
  static FeedbackThemeData feedback(ColorScheme scheme) => FeedbackThemeData(
    background: scheme.scrim.withValues(alpha: .4),
    feedbackSheetColor: scheme.surface,
    activeFeedbackModeColor: scheme.primary,
    dragHandleColor: scheme.outlineVariant,
    drawColors: [
      scheme.primary,
      scheme.tertiary,
      scheme.onSurface,
      scheme.surface,
    ],
    brightness: scheme.brightness,
  );

  /// Standard card decoration (surfaceContainerLowest, soft shadow in light,
  /// no border).
  static BoxDecoration card(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return BoxDecoration(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.card),
      boxShadow: colors.cardShadow,
    );
  }

  /// Hero card decoration (surfaceContainerLowest, deeper shadow, subtle
  /// border in dark).
  static BoxDecoration heroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return BoxDecoration(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.heroCard),
      boxShadow: colors.heroCardShadow,
      border: Border.all(color: colors.heroCardBorder, width: 1),
    );
  }

  /// The Tonal button (`docs/design/components.md` #2), for
  /// `FilledButton.tonal`. Material's tonal reads `secondaryContainer`; ours is
  /// `primary/container`, which a theme cannot tell apart from Primary.
  static ButtonStyle tonal(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    );
  }

  /// The Calendar's view switch on the hero gradient: a translucent track,
  /// the selected segment white with the primary tint's ink.
  static ButtonStyle heroSegmented(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return SegmentedButton.styleFrom(
      backgroundColor: colors.heroFillSubtle,
      foregroundColor: colors.onHero,
      selectedBackgroundColor: colors.onHero,
      selectedForegroundColor: colors.onHeroFill,
      side: BorderSide.none,
    );
  }

  /// A white pill button on the hero gradient (an event's Join).
  static ButtonStyle heroPill(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return FilledButton.styleFrom(
      backgroundColor: colors.onHero,
      foregroundColor: colors.onHeroFill,
    );
  }

  /// A translucent pill button on the hero gradient, beside a [heroPill]
  /// (a contact's Call).
  static ButtonStyle heroFillPill(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return FilledButton.styleFrom(
      backgroundColor: colors.heroFill,
      foregroundColor: colors.onHero,
    );
  }

  /// Choice chips on the page (a prospect's Where it stands), as a theme for
  /// a `Theme` above them: outlined pills, the picked one in the primary
  /// tint with a check.
  static ThemeData choiceChips(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final chips = theme.chipTheme;
    return theme.copyWith(
      chipTheme: chips.copyWith(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        showCheckmark: true,
        checkmarkColor: scheme.onPrimaryContainer,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? colors.primaryText.withValues(alpha: .4)
                : colors.borderSubtle,
          ),
        ),
        labelStyle: chips.labelStyle?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.ms,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }

  /// A text button on the hero gradient (the desktop Calendar's Today).
  static ButtonStyle heroButton(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return TextButton.styleFrom(
      backgroundColor: colors.heroFill,
      foregroundColor: colors.onHero,
    );
  }

  /// A search field on the hero gradient (Contacts): a translucent pill,
  /// its hint and icon quieter than what is typed.
  static InputDecoration heroSearch(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final pill = BorderRadius.circular(AppRadii.pill);
    return InputDecoration(
      fillColor: colors.heroFillSubtle,
      hintStyle: AppTypography.bodyLarge.copyWith(color: colors.onHeroQuiet),
      prefixIconColor: colors.onHeroQuiet,
      enabledBorder: OutlineInputBorder(
        borderRadius: pill,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: pill,
        borderSide: BorderSide(color: colors.onHero, width: 2),
      ),
    );
  }

  /// Filter chips on the hero gradient, as a theme for a `Theme` above
  /// them: white when picked, with the hero fill's ink; translucent
  /// otherwise.
  static ThemeData heroChips(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final chips = theme.chipTheme;
    return theme.copyWith(
      // A chip paints its fill on a canvas Material: without this, the
      // translucent fill sits on the canvas colour, not the gradient.
      canvasColor: Colors.transparent,
      chipTheme: chips.copyWith(
        backgroundColor: colors.heroFill,
        selectedColor: colors.onHero,
        labelStyle: chips.labelStyle?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onHeroFill
                : colors.onHero,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.ms,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }

  /// The white + on the dark chrome (floating bar, sidebar, rail), for an
  /// `IconButton` or a `FilledButton.icon`. The caller sets its size.
  static ButtonStyle createButton(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return FilledButton.styleFrom(
      backgroundColor: colors.onChrome,
      foregroundColor: colors.chrome,
    );
  }

  /// The Sign in with Apple button, on top of the outlined theme (same height,
  /// pill and label as Google's). Apple's HIG allows only black, white or
  /// white-with-outline, so these are Apple's colours, not ours: white with a
  /// black outline in light (it matches the outlined Google button), plain
  /// white in dark.
  static ButtonStyle signInWithApple(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.styleFrom(
      backgroundColor: white,
      foregroundColor: black,
      side: dark ? BorderSide.none : const BorderSide(color: black),
    );
  }

  /// The resolve ring of an action item, for an `IconButton` with
  /// `isSelected`: an empty ring that reads "tick me", filled once ticked
  /// (#190). A bare check read as a status, not a button. Selected stays filled
  /// while disabled — that is the tick in flight.
  /// A link inside a sentence: a TextButton that sits on the text's line, in
  /// the sentence's own size, with no padding of its own.
  static ButtonStyle inlineLink(TextStyle? style) => TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: style?.copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
  );

  static ButtonStyle resolveRing(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size.square(28)),
      minimumSize: const WidgetStatePropertyAll(Size.square(28)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      iconSize: const WidgetStatePropertyAll(18),
      // The ring is small; the touch target is not.
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const WidgetStatePropertyAll(CircleBorder()),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide.none
            : BorderSide(color: colors.textMuted, width: 2),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : colors.textMuted.withValues(alpha: 0.45),
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, LoomiaColors colors) {
    final text = AppTypography.textTheme(scheme);
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
    );

    return ThemeData(
      colorScheme: scheme,
      extensions: [colors],
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,

      // Content is flat: a hairline and space, never a shadow (principle #6).
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceDefault,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),

      filledButtonTheme: FilledButtonThemeData(
        // No fill colours: Material's defaults are Primary's, and setting them
        // here would paint the tonal variant primary too.
        style: FilledButton.styleFrom(
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textDisabled,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: pill,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primaryText,
          side: BorderSide(color: colors.borderStrong),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primaryText,
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.ms),
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(44, 44),
          shape: pill,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        hintStyle: AppTypography.bodyLarge.copyWith(color: colors.textMuted),
        // Drawn above the box by LabeledField; fields carry no labelText.
        labelStyle: AppTypography.label.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        helperStyle: AppTypography.caption.copyWith(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.ms,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: colors.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      // Segmented buttons off the hero: the selected side in the primary
      // tint, as an active filter chip. The Calendar's switch sits on the
      // hero and uses heroSegmented instead.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: AppTypography.label,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSunken,
        side: BorderSide.none,
        showCheckmark: false,
        labelPadding: EdgeInsets.zero,
        // Without a colour the label paints white, invisible on light chips.
        labelStyle: AppTypography.caption.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: colors.secondaryTrack,
        linearMinHeight: AppSpacing.sm,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),

      // Overlays are the only surfaces allowed a shadow; in dark they step up a
      // surface token instead, because shadow is invisible on a near-black
      // canvas.
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      // Menus are raised (design-system §5): a soft shadow lifts the white
      // menu off the near-white canvas; in dark the surface steps up instead.
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: scheme.shadow,
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.body.copyWith(color: scheme.onSurface),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      // Flat like the rest (design-system §5): Material's FAB casts a shadow
      // and is tonal.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceDefault,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: pill,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(AppTypography.caption),
        // No badge counts on navigation (principle #4).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colors.surfaceSunken,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: pill,
        labelTextStyle: WidgetStatePropertyAll(AppTypography.labelLarge),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppTypography.caption.copyWith(
          color: scheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }

  /// The value of a compact `DropdownButton` in a Settings row's trailing
  /// slot: the row's trailing size, in the text colour, as it can be changed.
  static TextStyle? rowDropdown(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );
  }

  /// A search field: a pill with no hairline, the focus ring kept.
  static InputDecoration search(BuildContext context) {
    final pill = BorderRadius.circular(AppRadii.pill);
    return InputDecoration(
      fillColor: LoomiaColors.of(context).surfaceSunken,
      enabledBorder: OutlineInputBorder(
        borderRadius: pill,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: pill,
        borderSide: BorderSide(color: LoomiaColors.of(context).focus, width: 2),
      ),
    );
  }
}

/// Elevation (§5). Three levels, two of which cast a shadow — content surfaces
/// are flat and keep a hairline instead.
abstract final class AppElevation {
  /// Menus, dropdowns, snackbars. Never on a content card.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Dialogs and bottom sheets only.
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 28),
  ];

  /// Scrim behind an overlay: `text/primary` at 40%.
  static const double scrimOpacity = 0.4;
}

/// Motion (§7). Motion explains what moved; it never celebrates.
abstract final class AppMotion {
  /// Hover, pressed, focus ring. Also the reduce-motion fallback for every
  /// duration below.
  static const fast = Duration(milliseconds: 120);

  /// Chip/toggle state, small fades.
  static const quick = Duration(milliseconds: 180);

  /// List reorder, tab change.
  static const medium = Duration(milliseconds: 240);

  /// Sheet and dialog present/dismiss, page transition, a completed card
  /// sliding out (and its next one in).
  static const slow = Duration(milliseconds: 320);

  /// The floating bar's pill travelling between tabs, on an emphasized curve.
  static const emphasized = Duration(milliseconds: 420);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const decelerate = Cubic(0, 0, 0, 1);
  static const accelerate = Cubic(0.3, 0, 1, 1);
}

/// The reduce-motion contract: every duration in the app reaches a widget
/// through [motion], so "reduce motion" is honoured in one place.
///
/// The OS flag collapses movement to a 120ms opacity change (§7) rather than to
/// zero: something still has to explain what moved.
extension Motion on BuildContext {
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  Duration motion(Duration duration) =>
      reduceMotion ? AppMotion.fast : duration;
}
