import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/vietqr.dart';
import 'package:ting_ting/domain/vietqr_banks.dart';

/// Reads a payload back into its `id -> value` chunks, the way a banking app
/// does. Asserting on the parsed structure rather than on one long expected
/// string keeps the tests readable and still catches a field in the wrong
/// place.
Map<String, String> _fields(String payload) {
  final fields = <String, String>{};
  var at = 0;
  while (at + 4 <= payload.length) {
    final id = payload.substring(at, at + 2);
    final length = int.parse(payload.substring(at + 2, at + 4));
    fields[id] = payload.substring(at + 4, at + 4 + length);
    at += 4 + length;
  }
  return fields;
}

String _payload({
  String bankBin = '970436',
  String accountNumber = '0123456789',
  int? amount,
  String? note,
}) => buildVietQrPayload(
  bankBin: bankBin,
  accountNumber: accountNumber,
  amount: amount,
  note: note,
);

void main() {
  group('crc16Ccitt', () {
    test('matches the published check value for CRC-16/CCITT-FALSE', () {
      expect(crc16Ccitt('123456789'), '29B1');
    });

    test('always returns four hex digits, zeros included', () {
      // A checksum written as "2B7" instead of "02B7" shifts every reader by
      // one character and the code stops scanning.
      for (final input in ['', 'A', 'VIETQR', '00020101021138']) {
        expect(crc16Ccitt(input), matches(RegExp(r'^[0-9A-F]{4}$')));
      }
    });
  });

  group('buildVietQrPayload', () {
    test('puts the bank BIN and account number in the NAPAS block', () {
      final fields = _fields(_payload());

      final merchant = _fields(fields['38']!);
      expect(merchant['00'], 'A000000727');
      expect(merchant['02'], 'QRIBFTTA');

      final beneficiary = _fields(merchant['01']!);
      expect(beneficiary['00'], '970436');
      expect(beneficiary['01'], '0123456789');
    });

    test('declares itself an EMVCo QR paying in dong from Vietnam', () {
      final fields = _fields(_payload());

      expect(fields['00'], '01');
      expect(fields['53'], '704');
      expect(fields['58'], 'VN');
    });

    test('closes with a checksum over everything ahead of it', () {
      final payload = _payload();
      final body = payload.substring(0, payload.length - 4);

      expect(body.endsWith('6304'), isTrue);
      expect(payload.substring(payload.length - 4), crc16Ccitt(body));
    });

    test('is reusable when no amount is named', () {
      final fields = _fields(_payload());

      expect(fields['01'], '11');
      expect(fields.containsKey('54'), isFalse);
    });

    test('becomes single use once an amount is named', () {
      final fields = _fields(_payload(amount: 50000));

      expect(fields['01'], '12');
      expect(fields['54'], '50000');
    });

    test('carries the transfer note in field 62-08', () {
      final fields = _fields(_payload(note: 'Tra tien com'));

      expect(_fields(fields['62']!)['08'], 'TRA TIEN COM');
    });

    test('leaves field 62 out when there is no note', () {
      expect(_fields(_payload()).containsKey('62'), isFalse);
      expect(_fields(_payload(note: '   ')).containsKey('62'), isFalse);
    });

    test('drops spaces and dashes copied along with the account number', () {
      final fields = _fields(_payload(accountNumber: '0123 456-789'));

      expect(_fields(_fields(fields['38']!)['01']!)['01'], '0123456789');
    });

    test('refuses an account number that is not there', () {
      expect(() => _payload(accountNumber: '  '), throwsA(isA<VietQrError>()));
    });

    test('refuses punctuation inside an account number', () {
      expect(
        () => _payload(accountNumber: '0123#456'),
        throwsA(isA<VietQrError>()),
      );
    });

    test('refuses an account number longer than the field holds', () {
      expect(
        () => _payload(accountNumber: '1' * (qrAccountLimit + 1)),
        throwsA(isA<VietQrError>()),
      );
    });

    test('refuses a bank BIN that is not six digits', () {
      expect(() => _payload(bankBin: '97043'), throwsA(isA<VietQrError>()));
      expect(() => _payload(bankBin: 'VCB123'), throwsA(isA<VietQrError>()));
    });

    test('refuses an amount of zero or less', () {
      expect(() => _payload(amount: 0), throwsA(isA<VietQrError>()));
      expect(() => _payload(amount: -1000), throwsA(isA<VietQrError>()));
    });
  });

  group('normalizeQrNote', () {
    test('strips Vietnamese accents and shouts the rest', () {
      expect(normalizeQrNote('Trả tiền cơm trưa'), 'TRA TIEN COM TRUA');
    });

    test('turns punctuation into single spaces', () {
      expect(normalizeQrNote('Tra no  (T7)'), 'TRA NO T7');
    });

    test('cuts a long note down to what the field holds', () {
      final note = normalizeQrNote('Thanh toan hoa don dien nuoc thang bay');

      expect(note.length, lessThanOrEqualTo(qrNoteLimit));
      expect(note, 'THANH TOAN HOA DON DIEN');
    });

    test('keeps a word that ends right on the limit', () {
      // "THANH TOAN HOA DON TIEN" is 23 characters and the next character is a
      // space, so nothing needs dropping.
      expect(
        normalizeQrNote('Thanh toan hoa don tien dien'),
        'THANH TOAN HOA DON TIEN',
      );
    });

    test('cuts inside a single long word rather than return nothing', () {
      expect(normalizeQrNote('A' * 40), 'A' * qrNoteLimit);
    });

    test('leaves an empty note empty', () {
      expect(normalizeQrNote(''), '');
      expect(normalizeQrNote('...'), '');
    });
  });

  group('vietQrBanks', () {
    test('every bank carries a six digit BIN', () {
      for (final bank in vietQrBanks) {
        expect(bank.bin, matches(RegExp(r'^\d{6}$')), reason: bank.shortName);
      }
    });

    test('no two banks share a BIN', () {
      final bins = vietQrBanks.map((bank) => bank.bin).toSet();

      expect(bins, hasLength(vietQrBanks.length));
    });

    test('finds a bank by the BIN kept in settings', () {
      expect(bankByBin('970436')?.shortName, 'Vietcombank');
      expect(bankByBin('000000'), isNull);
    });

    test('searches without caring about accents or case', () {
      expect(searchBanks('ngoại thương').single.shortName, 'Vietcombank');
      expect(searchBanks('VIETCOM').single.shortName, 'Vietcombank');
    });

    test('searches by BIN, the number on a transfer slip', () {
      expect(searchBanks('970422').single.shortName, 'MBBank');
    });

    test('finds a bank people still call by its old name', () {
      // NAPAS lists this one as VietCapitalBank; every customer says BVBank.
      expect(searchBanks('bvbank').single.bin, '970454');
    });

    test('every bank has its logo file on disk', () {
      // Adding a bank without dropping its logo in leaves a bare icon in the
      // picker, which nobody notices until the list is scrolled that far.
      for (final bank in vietQrBanks) {
        expect(
          File(bank.logoAsset).existsSync(),
          isTrue,
          reason: '${bank.shortName} thiếu ${bank.logoAsset}',
        );
      }
    });

    test('an empty search leaves the whole list alone', () {
      expect(searchBanks('  '), hasLength(vietQrBanks.length));
    });
  });
}
