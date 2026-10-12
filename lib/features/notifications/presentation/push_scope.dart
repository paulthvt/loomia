import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Around the signed-in screens: keeps this phone registered for push in the
/// app's language, the summary's time zone the device's, asks for permission
/// when the summary is on but this phone doesn't allow it, and opens Today
/// when a push is tapped.
class PushScope extends ConsumerStatefulWidget {
  const PushScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushScope> createState() => _PushScopeState();
}

class _PushScopeState extends ConsumerState<PushScope> {
  StreamSubscription<void>? _opened;
  String? _locale;

  @override
  void initState() {
    super.initState();
    _opened = ref
        .read(pushProvider)
        .opened
        .listen((_) => mounted ? context.go(Routes.today) : null);
    unawaited(_onLaunch());
  }

  /// Once per sign-in: the summary uses the zone the user is in now.
  Future<void> _onLaunch() async {
    final owner = ref.read(accountProvider)?.email;
    final provider = notificationSettingsProvider(owner);
    final controller = ref.read(provider.notifier);
    final push = ref.read(pushProvider);
    final zone = await ref.read(deviceTimeZoneProvider.future);
    if (zone != null && mounted) await controller.followDevice(zone);

    // The summary is the account's, permission the phone's: a phone that
    // hasn't allowed it yet is asked (#283). No memory needed here: iOS asks
    // once ever, Android 13+ twice at most, then answers without a prompt.
    try {
      final settings = await ref.read(provider.future);
      if (settings?.enabled == true && await push.allowed() == false) {
        await push.ask();
      }
    } on PeopleFailure {
      // Logged by guardPeople; the next launch tries again.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The user's choice in Settings, else the phone's, as MaterialApp
    // resolved it: what the push is written in.
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == _locale) return;
    _locale = locale;
    unawaited(ref.read(pushProvider).register(locale));
  }

  @override
  void dispose() {
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
