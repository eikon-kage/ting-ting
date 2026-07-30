import 'package:flutter_test/flutter_test.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:ting_ting/services/notification_event_mapping.dart';

/// Exactly what the plugin's native side sends for one active notification:
/// six keys, and no `haveExtraPicture` among them.
Map<dynamic, dynamic> _payload() => <dynamic, dynamic>{
  'id': 42,
  'packageName': 'com.mbmobile',
  'title': 'MB Bank',
  'content': 'TK 0123|GD: +17,000VND|SD: 8,000,000VND',
  'onGoing': false,
  'postTime': 1785385000000,
};

void main() {
  group('notificationEventsFrom', () {
    test('reads a payload that carries no haveExtraPicture key', () {
      final events = notificationEventsFrom([_payload()]);

      expect(events, hasLength(1));
      expect(events.single.id, 42);
      expect(events.single.packageName, 'com.mbmobile');
      expect(events.single.title, 'MB Bank');
      expect(events.single.content, 'TK 0123|GD: +17,000VND|SD: 8,000,000VND');
      expect(events.single.timestamp, 1785385000000);
      expect(events.single.onGoing, isFalse);
      // On the status bar by definition, or it would not be in this list.
      expect(events.single.hasRemoved, isFalse);
    });

    test('the plugin\'s own fromMap is what could not read it', () {
      // This is the bug being worked around, pinned so an upgrade that fixes it
      // upstream shows up here as a failing test rather than as dead code that
      // nobody dares delete: fromMap assigns map['haveExtraPicture'] into a
      // non-nullable bool, so the whole getActiveNotifications list threw on
      // its first element and no backfill ever ran.
      expect(
        () => ServiceNotificationEvent.fromMap(_payload()),
        throwsA(isA<TypeError>()),
      );
    });

    test('an empty or null payload is not an error', () {
      expect(notificationEventsFrom(null), isEmpty);
      expect(notificationEventsFrom(const []), isEmpty);
    });

    test('skips rows that are not maps instead of throwing on them', () {
      expect(notificationEventsFrom(['rác', 7, null, _payload()]), hasLength(1));
    });

    test('missing keys fall back to defaults', () {
      final events = notificationEventsFrom([<dynamic, dynamic>{}]);

      expect(events, hasLength(1));
      expect(events.single.id, 0);
      expect(events.single.packageName, isEmpty);
      expect(events.single.title, isEmpty);
      expect(events.single.content, isEmpty);
      expect(events.single.timestamp, 0);
      expect(events.single.onGoing, isFalse);
    });
  });
}
