import 'package:flutter/widgets.dart';

/// Layout classes. Screens pick a layout from these instead of testing raw
/// pixel widths, so the thresholds can move in one place.
enum ScreenSize {
  mobile,
  tablet,
  desktop;

  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;
  bool get isDesktop => this == ScreenSize.desktop;

  /// True when navigation should be a persistent sidebar rather than a bottom
  /// bar.
  bool get usesSideNavigation => this != ScreenSize.mobile;
}

abstract final class Breakpoints {
  static const double tablet = 600;

  /// Measured on the whole window, so it leaves room for the expanded sidebar,
  /// a list and a side pane. 1200, not 1024: a portrait iPad Pro 13" (1032)
  /// squeezed the pane to one letter a line (#403).
  static const double desktop = 1200;

  /// Max content width on very large screens, to avoid full-bleed text lines.
  static const double maxContentWidth = 1400;

  static ScreenSize of(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }
}

extension BreakpointContext on BuildContext {
  /// Depends on [MediaQuery] size only, so it rebuilds on resize (web) and
  /// rotation (mobile).
  ScreenSize get screenSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
}
