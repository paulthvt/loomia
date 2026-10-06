import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The only place `ThemeData` is built. Component styling lives here so widgets
/// stay style-free (`docs/design/design-system.md` §8).
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, LoomiaColors.light);
  static ThemeData get dark => _build(AppColors.dark, LoomiaColors.dark);

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

  /// The resolve ring of an action item, for an `IconButton` with
  /// `isSelected`: an empty ring that reads "tick me", filled once ticked
  /// (#190). A bare check read as a status, not a button. Selected stays filled
  /// while disabled — that is the tick in flight.
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
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: colors.borderSubtle),
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
        fillColor: colors.surfaceDefault,
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
        border: _inputBorder(colors.borderSubtle),
        enabledBorder: _inputBorder(colors.borderSubtle),
        focusedBorder: _inputBorder(colors.focus, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
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
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
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

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color, width: width),
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

  /// Row collapse on completion, list reorder, tab change.
  static const medium = Duration(milliseconds: 240);

  /// Sheet and dialog present/dismiss, page transition.
  static const slow = Duration(milliseconds: 320);

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
