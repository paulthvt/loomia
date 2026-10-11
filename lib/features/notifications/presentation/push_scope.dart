import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:material_ui/material_ui.dart';

/// Around the signed-in screens: keeps this phone registered for push in the
/// app's language, and opens Today when a push is tapped.
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
