import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/services/pending_notifications.dart';

/// One line of the queue, shaped exactly as BankNotificationListener writes it.
String _line({
  String package = 'com.mbmobile',
  String content = 'TK 03xxx619|GD: -15,000VND|SD: 1,880,000VND',
  int postTime = 1785387000000,
}) =>
    '{"id":994,"packageName":"$package","title":"MB Bank",'
    '"content":"$content","postTime":$postTime,"onGoing":false}';

void main() {
  group('eventsFromQueue', () {
    test('reads one queued notification', () {
      final events = eventsFromQueue('${_line()}\n');

      expect(events, hasLength(1));
      expect(events.single.packageName, 'com.mbmobile');
      expect(events.single.title, 'MB Bank');
      expect(events.single.content, contains('-15,000VND'));
      expect(events.single.timestamp, 1785387000000);
      expect(events.single.onGoing, isFalse);
    });

    test('reads every line, in the order they were appended', () {
      final events = eventsFromQueue(
        '${_line(content: 'first')}\n'
        '${_line(content: 'second')}\n'
        '${_line(content: 'third')}\n',
      );

      expect(
        events.map((e) => e.content),
        ['first', 'second', 'third'],
      );
    });

    test('skips a half-written last line instead of losing the file', () {
      // The process can be killed partway through an append, and everything
      // before that point is still a perfectly good notification.
      final events = eventsFromQueue(
        '${_line(content: 'complete')}\n{"id":995,"packageNam',
      );

      expect(events, hasLength(1));
      expect(events.single.content, 'complete');
    });

    test('skips junk lines without giving up on the rest', () {
      final events = eventsFromQueue(
        'không phải json\n${_line(content: 'good')}\n[]\n"chuỗi"\n',
      );

      expect(events, hasLength(1));
      expect(events.single.content, 'good');
    });

    test('an empty queue is not an error', () {
      expect(eventsFromQueue(''), isEmpty);
      expect(eventsFromQueue('\n\n  \n'), isEmpty);
    });
  });

  group('PendingNotifications', () {
    test('the queue file name matches the one the listener writes', () {
      // BankNotificationListener.QUEUE_FILE. Renaming one side without the
      // other silently strands every notification captured while the app is
      // closed, which is the whole point of the file.
      expect(PendingNotifications.fileName, 'pending_notifications.jsonl');
      expect(
        PendingNotifications.takenFileName,
        'pending_notifications.jsonl.taken',
      );
    });
  });
}
