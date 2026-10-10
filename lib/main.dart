import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/core/supabase/supabase_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Committed on purpose: a DSN can only send events, and ships inside every
/// binary anyway.
const _sentryDsn =
    'https://35d8f6322bf91e8d854d0d247867ab97@o4512160213499904.ingest.de.sentry.io/4512160219398224';

Future<void> main() async {
  // A `severe` without a stack still points at its call site, not at Sentry.
  recordStackTraceAtLevel = Level.SEVERE;
  if (!kReleaseMode) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '${record.level.name} ${record.loggerName}: ${record.message}',
      );
      if (record.error != null) debugPrint('${record.error}');
      if (record.stackTrace != null) debugPrint('${record.stackTrace}');
    });
  }

  await SentryFlutter.init(
    (options) {
      // An empty DSN turns the SDK off: debug and profile builds report to the
      // console only. PII stays off (the default), so no email or IP is sent.
      // ponytail: web stack traces stay minified; upload source maps with
      // sentry_dart_plugin once web has testers.
      options
        ..dsn = kReleaseMode ? _sentryDsn : ''
        // Breadcrumbs from INFO, structured logs from WARNING, events from
        // SEVERE (docs/architecture.md → Logging).
        ..addIntegration(LoggingIntegration(minSentryLogLevel: Level.WARNING))
        ..enableLogs = true
        // Signed Storage URLs carry a token in the query; PostgREST filters
        // can carry values.
        ..beforeBreadcrumb = (breadcrumb, hint) {
          breadcrumb?.data
            ?..remove('http.query')
            ..remove('http.fragment');
          return breadcrumb;
        };
    },
    appRunner: () async {
      // Restores a stored session before the first frame, so the router's
      // first redirect already knows the answer and no auth screen flashes on
      // launch.
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        // Its own console listener would print every record a second time:
        // without hierarchical logging all loggers share the root stream.
        debug: false,
        // A breadcrumb per request. Failures are reported by the repository
        // guards, with more context than a status code.
        httpClient: SentryHttpClient(captureFailedRequests: false),
      );
      // Id only, so a report can be matched to rows; never the email.
      Supabase.instance.client.auth.onAuthStateChange
          // Offline refreshes arrive as errors (#260); anything else stays
          // uncaught and reaches Sentry.
          .handleError((_) {}, test: (e) => e is AuthRetryableFetchException)
          .listen(
            (state) => Sentry.configureScope(
              (scope) => scope.setUser(switch (state.session?.user.id) {
                final id? => SentryUser(id: id),
                null => null,
              }),
            ),
          );
      runApp(const ProviderScope(child: LoomiaApp()));
    },
  );
}
