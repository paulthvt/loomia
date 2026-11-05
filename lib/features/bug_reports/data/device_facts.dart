import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:loomia/features/bug_reports/data/os_version.dart'
    if (dart.library.js_interop) 'package:loomia/features/bug_reports/data/os_version_web.dart';
import 'package:loomia/features/bug_reports/domain/log_buffer.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What a report says about the device and the screen it came from (#463).
/// Nothing that names the user; the route has its ids as `:id`.
Future<Map<String, Object?>> collectDeviceFacts({
  required String route,
  required Locale locale,
  required Size size,
  required Brightness brightness,
}) async {
  final package = await PackageInfo.fromPlatform();
  return {
    'appVersion': package.version,
    'buildNumber': package.buildNumber,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'osVersion': osVersion(),
    'locale': locale.toLanguageTag(),
    'route': scrubIds(route),
    'screen': '${size.width.round()}x${size.height.round()}',
    'brightness': brightness.name,
  };
}
