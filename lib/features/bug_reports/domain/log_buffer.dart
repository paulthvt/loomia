import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The recent log lines a bug report carries (#463). They go to a public
/// GitHub issue, so this is stricter than what Sentry gets: ids become `:id`,
/// an error keeps only its type and code (its text can hold row values or an
/// email), and only a `SEVERE` keeps its stack.
class LogBuffer {
  LogBuffer({this.capacity = 200});

  final int capacity;
  final _entries = ListQueue<LogEntry>();

  void add(LogRecord record) {
    if (_entries.length == capacity) _entries.removeFirst();
    _entries.add(
      LogEntry(
        time: record.time,
        level: record.level.name,
        logger: record.loggerName,
        message: scrubIds(record.message),
        error: switch (record.error) {
          null => null,
          final PostgrestException e => 'PostgrestException ${e.code}',
          final AuthException e => 'AuthException ${e.code}',
          final e => '${e.runtimeType}',
        },
        stack: record.level >= Level.SEVERE && record.stackTrace != null
            ? scrubIds('${record.stackTrace}')
            : null,
      ),
    );
  }

  /// Oldest first.
  List<LogEntry> get entries => List.unmodifiable(_entries);
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.logger,
    required this.message,
    this.error,
    this.stack,
  });

  final DateTime time;
  final String level;
  final String logger;
  final String message;
  final String? error;
  final String? stack;

  Map<String, Object?> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'level': level,
    'logger': logger,
    'message': message,
    'error': error,
    'stack': stack,
  };
}

final _uuid = RegExp(
  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// Every UUID in [text] as `:id`.
String scrubIds(String text) => text.replaceAll(_uuid, ':id');

/// Fed from `Logger.root` in `main.dart` from launch, whatever the mode, so a
/// report holds what happened before the tap.
final logBuffer = LogBuffer();

final logBufferProvider = Provider<LogBuffer>((_) => logBuffer);
