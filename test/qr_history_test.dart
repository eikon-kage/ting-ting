import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/qr_history.dart';
import 'package:ting_ting/models/saved_qr.dart';

SavedQr _qr({
  String bankBin = '970436',
  String accountNumber = '0123456789',
  String holderName = 'NGUYEN VAN A',
  int? amount,
  String note = '',
}) => SavedQr(
  bankBin: bankBin,
  accountNumber: accountNumber,
  holderName: holderName,
  amount: amount,
  note: note,
);

void main() {
  group('withQrRemembered', () {
    test('puts the newest code at the front', () {
      final first = _qr(accountNumber: '111');
      final second = _qr(accountNumber: '222');

      final history = withQrRemembered(
        withQrRemembered(const [], first),
        second,
      );

      expect(history.map((e) => e.accountNumber), ['222', '111']);
    });

    test('promotes a code that is already saved instead of doubling it', () {
      final a = _qr(accountNumber: '111');
      final b = _qr(accountNumber: '222');
      var history = withQrRemembered(withQrRemembered(const [], a), b);

      history = withQrRemembered(history, a);

      expect(history.map((e) => e.accountNumber), ['111', '222']);
    });

    test('lets a re-saved code carry a corrected holder name', () {
      final typo = _qr(holderName: 'NGUYEN VAN Q');
      final fixed = _qr(holderName: 'NGUYEN VAN A');

      final history = withQrRemembered(withQrRemembered(const [], typo), fixed);

      expect(history.single.holderName, 'NGUYEN VAN A');
    });

    test('treats a different amount or note as a different code', () {
      var history = withQrRemembered(const [], _qr());
      history = withQrRemembered(history, _qr(amount: 50000));
      history = withQrRemembered(history, _qr(note: 'Tien com'));

      expect(history, hasLength(3));
    });

    test('drops the oldest once the list is full', () {
      var history = const <SavedQr>[];
      for (var i = 0; i < qrHistoryLimit + 5; i++) {
        history = withQrRemembered(history, _qr(accountNumber: '$i'));
      }

      expect(history, hasLength(qrHistoryLimit));
      expect(history.first.accountNumber, '${qrHistoryLimit + 4}');
      expect(history.map((e) => e.accountNumber), isNot(contains('0')));
    });
  });

  group('withQrForgotten', () {
    test('removes just the one asked for', () {
      final a = _qr(accountNumber: '111');
      final b = _qr(accountNumber: '222');
      final history = withQrRemembered(withQrRemembered(const [], a), b);

      expect(withQrForgotten(history, a).single.accountNumber, '222');
    });

    test('leaves the list alone when the code is not in it', () {
      final history = withQrRemembered(const [], _qr(accountNumber: '111'));

      expect(withQrForgotten(history, _qr(accountNumber: '999')), hasLength(1));
    });
  });

  group('isQrRemembered', () {
    test('ignores the holder name, which is not part of the code', () {
      final history = withQrRemembered(const [], _qr(holderName: 'A'));

      expect(isQrRemembered(history, _qr(holderName: 'B')), isTrue);
    });

    test('says no for a code that only differs by amount', () {
      final history = withQrRemembered(const [], _qr());

      expect(isQrRemembered(history, _qr(amount: 1000)), isFalse);
    });
  });

  group('SavedQr storage', () {
    test('survives a round trip through JSON', () {
      final history = [
        _qr(amount: 50000, note: 'Tien com'),
        _qr(accountNumber: '999', holderName: ''),
      ];

      final read = SavedQr.decodeList(SavedQr.encodeList(history));

      expect(read, hasLength(2));
      expect(read.first.amount, 50000);
      expect(read.first.note, 'Tien com');
      expect(read.first.holderName, 'NGUYEN VAN A');
      expect(read.last.accountNumber, '999');
      expect(read.last.amount, isNull);
    });

    test('reads the single account the first version wrote', () {
      // That build stored one object under its own key, not a list. Machines
      // updating from it still have it, and nothing rewrites it.
      const legacy =
          '{"bankBin":"970422","accountNumber":"0334343619",'
          '"holderName":"NGUYEN QUANG VINH"}';

      final read = SavedQr.decodeList(legacy);

      expect(read.single.bankBin, '970422');
      expect(read.single.holderName, 'NGUYEN QUANG VINH');
      expect(read.single.amount, isNull);
    });

    test('keeps the readable entries when one row is rubbish', () {
      const raw = '[{"bankBin":"970436","accountNumber":"111"},{"bankBin":7}]';

      expect(SavedQr.decodeList(raw), hasLength(1));
    });

    test('returns nothing for a value that is not JSON at all', () {
      expect(SavedQr.decodeList('not json'), isEmpty);
    });
  });
}
