import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'notification_event_mapping.dart';

/// The queue `BankNotificationListener` writes on the Android side.
///
/// The native listener is bound by the system and runs whether or not a Flutter
/// engine exists, which is the only reason a bank message that lands after the
/// app is swiped away survives at all. It appends one JSON object per line and
/// never parses anything; this drains those lines the next time any engine runs.
///
/// Deliberately a plain file rather than a MethodChannel: the background isolate
/// that the foreground service runs only gets the plugins listed in pubspec
/// registered, not channels the app itself sets up in MainActivity. A file that
/// `dart:io` can read works the same in every isolate.
class PendingNotifications {
  PendingNotifications._();

  static final PendingNotifications instance = PendingNotifications._();

  /// Must match `BankNotificationListener.QUEUE_FILE`.
  static const String fileName = 'pending_notifications.jsonl';

  /// Where a drain in progress is moved to. Reading in place would lose
  /// anything the listener appends between the read and the delete, so the file
  /// is renamed first — a rename is atomic, and the listener simply creates a
  /// fresh queue on its next write.
  static const String takenFileName = '$fileName.taken';

  bool get supported => Platform.isAndroid;

  /// `getApplicationSupportDirectory` is Android's `filesDir`, which is what
  /// the listener writes into.
  Future<Directory> _dir() => getApplicationSupportDirectory();

  /// Takes everything queued and clears it.
  ///
  /// A leftover `.taken` file means an earlier drain died partway through; it is
  /// read first so those notifications are not lost. Returns an empty list on
  /// any failure — a broken queue must not stop the live stream from working.
  Future<List<ServiceNotificationEvent>> drain() async {
    if (!supported) return const [];
    try {
      final dir = await _dir();
      final taken = File(p.join(dir.path, takenFileName));
      final queue = File(p.join(dir.path, fileName));

      final leftover = await taken.exists() ? await taken.readAsString() : '';
      if (await queue.exists()) {
        // Append rather than replace, or the leftover is dropped on the floor.
        final fresh = await queue.readAsString();
        await taken.writeAsString(leftover + fresh);
        await queue.delete();
      } else if (leftover.isEmpty) {
        return const [];
      }

      final content = await taken.exists() ? await taken.readAsString() : '';
      final events = eventsFromQueue(content);
      if (await taken.exists()) await taken.delete();
      return events;
    } catch (e) {
      debugPrint('draining the notification queue failed: $e');
      return const [];
    }
  }
}

/// Turns the queue file's contents into events.
///
/// One JSON object per line, and a line that will not parse is skipped rather
/// than taken as the end of the file: a half-written last line is expected when
/// the process is killed mid-append, and everything before it is still good.
@visibleForTesting
List<ServiceNotificationEvent> eventsFromQueue(String content) {
  final rows = <Map<dynamic, dynamic>>[];
  for (final line in const LineSplitter().convert(content)) {
    if (line.trim().isEmpty) continue;
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map) rows.add(decoded);
    } on FormatException {
      continue;
    }
  }
  // The same field names the plugin's channel uses, so one mapper covers both.
  return notificationEventsFrom(rows);
}
