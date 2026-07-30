import 'package:notification_listener_service/notification_event.dart';

/// Builds [ServiceNotificationEvent]s out of raw notification maps.
///
/// Two sources produce those maps and both use the same field names: the
/// plugin's `getActiveNotifications` channel call, and the queue file that
/// `BankNotificationListener` writes. Only the six keys either of them actually
/// sends are read; the rest of the event gets the defaults the plugin's own
/// `fromMap` would have used.
///
/// Not `ServiceNotificationEvent.fromMap`, which cannot read either payload: it
/// assigns `map['haveExtraPicture']` straight into a non-nullable `bool`, and
/// neither source sends that key. Every row threw "type 'Null' is not a subtype
/// of type 'bool'", the plugin only catches `PlatformException`, so the whole
/// list died on its first element and no catch-up scan ever ran.
///
/// `hasRemoved` is false by definition here — these are notifications that were
/// posted, either still on the status bar or captured at the moment they landed.
List<ServiceNotificationEvent> notificationEventsFrom(List<dynamic>? raw) => [
  for (final item in raw ?? const [])
    if (item is Map)
      ServiceNotificationEvent(
        id: item['id'] as int? ?? 0,
        packageName: item['packageName'] as String? ?? '',
        title: item['title'] as String? ?? '',
        content: item['content'] as String? ?? '',
        onGoing: item['onGoing'] as bool? ?? false,
        timestamp: item['postTime'] as int? ?? 0,
        hasRemoved: false,
        canReply: false,
        haveExtraPicture: false,
        appIcon: null,
        extrasPicture: null,
        largeIcon: null,
      ),
];
