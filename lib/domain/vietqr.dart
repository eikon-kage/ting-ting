/// Builds the string that sits behind a VietQR code.
///
/// VietQR is NAPAS' profile of the EMVCo merchant QR: the payload is a flat
/// run of `id + length + value` chunks with a checksum closing it. All of it is
/// plain string work — no key, no account of ours, no server — so the app can
/// print a QR for any bank account while offline.
///
/// The code carries only the bank BIN and the account number. The name of the
/// person receiving the money is not in there: the banking app that scans it
/// asks NAPAS who owns the account and shows the answer itself.
library;

import '../core/text.dart';

/// Something the user typed cannot go into a QR code.
class VietQrError implements Exception {
  const VietQrError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Longest transfer note EMVCo allows in field 62-08.
const int qrNoteLimit = 25;

/// Longest account number field 38-01-01 holds.
const int qrAccountLimit = 19;

/// Largest amount field 54 holds — thirteen digits, far past any transfer
/// limit a Vietnamese bank actually allows.
const int qrAmountLimit = 9999999999999;

/// Identifies the block of fields that belongs to NAPAS.
const String _napasGuid = 'A000000727';

/// Service code for "chuyển tới số tài khoản". The other one, `QRIBFTTC`,
/// sends to a card number and needs a different value in field 38-01-01.
const String _transferToAccount = 'QRIBFTTA';

const String _vndCurrency = '704';
const String _countryCode = 'VN';

/// Assembles the payload for a transfer into [accountNumber] at the bank with
/// NAPAS BIN [bankBin].
///
/// Leave [amount] and [note] out for a code that can be scanned again and
/// again; fill them in and the code becomes a one-off request for exactly that
/// much money, with the note already typed into the sender's transfer form.
///
/// Throws [VietQrError] when what came in cannot be encoded.
String buildVietQrPayload({
  required String bankBin,
  required String accountNumber,
  int? amount,
  String? note,
}) {
  if (!RegExp(r'^\d{6}$').hasMatch(bankBin)) {
    throw const VietQrError('Chưa chọn ngân hàng');
  }

  // Account numbers get read off a screen and retyped, so spaces and dashes
  // come along for the ride. Drop them rather than refuse the whole thing.
  final account = accountNumber.replaceAll(RegExp(r'[\s-]'), '');
  if (account.isEmpty) {
    throw const VietQrError('Nhập số tài khoản');
  }
  if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(account)) {
    throw const VietQrError('Số tài khoản chỉ gồm chữ và số');
  }
  if (account.length > qrAccountLimit) {
    throw const VietQrError('Số tài khoản dài quá $qrAccountLimit ký tự');
  }

  if (amount != null && amount <= 0) {
    throw const VietQrError('Số tiền phải lớn hơn 0');
  }
  if (amount != null && amount > qrAmountLimit) {
    throw const VietQrError('Số tiền lớn quá mức mã QR chứa được');
  }

  final cleanNote = normalizeQrNote(note ?? '');

  final beneficiary = _field('00', bankBin) + _field('01', account);
  final merchant =
      _field('00', _napasGuid) +
      _field('01', beneficiary) +
      _field('02', _transferToAccount);

  // EMVCo wants the fields in ascending id order, and readers in the wild do
  // rely on it.
  final payload = StringBuffer()
    ..write(_field('00', '01'))
    // "11" is a code meant to be reused, "12" a single-use one. A code that
    // already names an amount is by definition the second kind.
    ..write(_field('01', amount == null ? '11' : '12'))
    ..write(_field('38', merchant))
    ..write(_field('53', _vndCurrency));
  if (amount != null) payload.write(_field('54', '$amount'));
  payload.write(_field('58', _countryCode));
  if (cleanNote.isNotEmpty) {
    payload.write(_field('62', _field('08', cleanNote)));
  }
  // The checksum covers its own id and length as well, so they are written
  // before it is computed.
  payload.write('6304');

  return '$payload${crc16Ccitt(payload.toString())}';
}

/// Trims a transfer note down to what banks reliably accept.
///
/// The note travels to the sender's bank and back out on the statement, and
/// more than a few Vietnamese banks mangle accents or punctuation on the way.
/// Plain uppercase ASCII survives everywhere, and anything past [qrNoteLimit]
/// would be cut off by the receiving bank anyway.
String normalizeQrNote(String raw) {
  final ascii = removeDiacritics(raw.toLowerCase()).toUpperCase();
  final kept = ascii
      .replaceAll(RegExp('[^A-Z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (kept.length <= qrNoteLimit) return kept;
  final cut = kept.substring(0, qrNoteLimit);
  if (kept[qrNoteLimit] == ' ') return cut;
  // Cutting mid-word leaves the sender staring at "TIEN DIEN N". Drop the
  // stump, unless the whole note is one long word and there is nothing to drop.
  final lastSpace = cut.lastIndexOf(' ');
  return lastSpace > 0 ? cut.substring(0, lastSpace) : cut;
}

/// CRC-16/CCITT-FALSE, the checksum EMVCo puts in field 63.
///
/// Polynomial 0x1021 starting from 0xFFFF, no reflection, no final xor — the
/// variant whose check value over "123456789" is 0x29B1. Getting any of that
/// wrong produces a code that looks fine and every banking app rejects.
String crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// One `id + length + value` chunk. Lengths are two digits, which caps a single
/// field at 99 characters — none of ours comes close.
String _field(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';
