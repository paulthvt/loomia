/// `solveTurnstile()` and `turnstileView()` for this platform (#529).
library;

export 'package:loomia/features/auth/data/captcha_solver_io.dart'
    if (dart.library.js_interop) 'package:loomia/features/auth/data/captcha_solver_web.dart';
