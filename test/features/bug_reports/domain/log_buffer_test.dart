import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:loomia/features/bug_reports/domain/log_buffer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '3f2b8c1e-9a4d-4e6b-8c2f-1a2b3c4d5e6f';

void main() {
  test('keeps the last 200, oldest dropped', () {
    final buffer = LogBuffer();
    for (var i = 0; i < 205; i++) {
      buffer.add(LogRecord(Level.INFO, 'm$i', 'x'));
    }
    expect(buffer.entries.length, 200);
    expect(buffer.entries.first.message, 'm5');
    expect(buffer.entries.last.message, 'm204');
  });

  test('replaces UUIDs with :id', () {
    expect(scrubIds('→ /contacts/$_id/edit'), '→ /contacts/:id/edit');
    expect(scrubIds(_id.toUpperCase()), ':id');
  });

  test('messages are scrubbed on the way in', () {
    final buffer = LogBuffer()..add(LogRecord(Level.INFO, '→ /p/$_id', 'r'));
    expect(buffer.entries.single.message, '→ /p/:id');
  });

  group('keeps only the type and code of an error', () {
    LogEntry entryFor(Object error) =>
        (LogBuffer()..add(LogRecord(Level.WARNING, 'x', 'people', error)))
            .entries
            .single;

    test('PostgrestException', () {
      final entry = entryFor(
        const PostgrestException(
          message: 'Ana 0612345678',
          code: '23505',
          details: 'Key (name)=(Ana)',
        ),
      );
      expect(entry.error, 'PostgrestException 23505');
    });

    test('AuthException', () {
      final entry = entryFor(
        const AuthException('ana@example.com taken', code: 'user_exists'),
      );
      expect(entry.error, 'AuthException user_exists');
    });

    test('anything else', () {
      expect(entryFor(StateError('Ana')).error, 'StateError');
    });

    test('none', () {
      final buffer = LogBuffer()..add(LogRecord(Level.INFO, 'x', 'y'));
      expect(buffer.entries.single.error, isNull);
    });
  });

  test('a stack trace only for SEVERE, with ids scrubbed', () {
    final stack = StackTrace.fromString('#0 open ($_id)');
    final buffer = LogBuffer()
      ..add(LogRecord(Level.INFO, 'a', 'x', null, stack))
      ..add(LogRecord(Level.SEVERE, 'b', 'x', null, stack));
    expect(buffer.entries.first.stack, isNull);
    expect(buffer.entries.last.stack, '#0 open (:id)');
  });

  test('toJson has time in UTC, level, logger, message, error, stack', () {
    final record = LogRecord(Level.SEVERE, 'boom', 'people', StateError('x'));
    final json = (LogBuffer()..add(record)).entries.single.toJson();
    expect(json.keys, ['time', 'level', 'logger', 'message', 'error', 'stack']);
    expect(json['time'], record.time.toUtc().toIso8601String());
    expect(json['level'], 'SEVERE');
    expect(json['logger'], 'people');
    expect(json['error'], 'StateError');
  });
}
