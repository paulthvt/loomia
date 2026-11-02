import 'package:material_ui/material_ui.dart';

/// The bell beside a switch that sends a push (#439), as on a task's time:
/// ringing when on, crossed out when off.
Icon pushBell({required bool on}) => Icon(
  on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
);
