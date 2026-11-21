import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/data/captcha_solver.dart';
import 'package:material_ui/material_ui.dart';

/// Holds the invisible Turnstile web view under [child] while signed out
/// (#529), and fetches the first token as soon as it mounts, so tapping
/// "Sign in" doesn't wait for it. One for the whole app: a web view can't sit
/// in two screens on the stack at once.
class CaptchaHost extends ConsumerWidget {
  const CaptchaHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedOut = ref.watch(accountProvider.select((a) => a == null));
    if (!signedOut) return child;
    return Stack(
      children: [
        // Under the app and 1×1: the challenge runs, nothing shows, and
        // screen readers skip it.
        const Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: ExcludeSemantics(child: _Warm()),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Warm extends ConsumerStatefulWidget {
  const _Warm();

  @override
  ConsumerState<_Warm> createState() => _WarmState();
}

class _WarmState extends ConsumerState<_Warm> {
  @override
  void initState() {
    super.initState();
    // After the first frame, once the web view is attached.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(captchaProvider).warm(),
    );
  }

  @override
  Widget build(BuildContext context) => turnstileView();
}
