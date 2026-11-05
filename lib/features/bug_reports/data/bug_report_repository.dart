import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/auth/data/auth_failure_mapping.dart';
import 'package:loomia/features/bug_reports/domain/bug_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends a report to the `report-bug` Edge Function (#463), which holds the
/// GitHub and NAS credentials. Throws an `AuthFailure`, like the other
/// function call (`deleteAccount`).
class BugReportRepository {
  BugReportRepository(this._client);

  final SupabaseClient _client;

  /// The new issue's number.
  Future<int> send(BugReport report) async {
    late int issue;
    await guardAuth(() async {
      final response = await _client.functions.invoke(
        'report-bug',
        body: report.toJson(),
      );
      issue = (response.data as Map<String, dynamic>)['issue'] as int;
    });
    return issue;
  }
}

final bugReportRepositoryProvider = Provider<BugReportRepository>(
  (ref) => BugReportRepository(ref.watch(supabaseClientProvider)),
);
