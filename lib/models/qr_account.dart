import 'dart:convert';

/// The account the user hands out to get paid, kept so the QR screen comes up
/// filled in instead of asking for twelve digits every time.
///
/// Stored as one JSON blob in the settings table rather than a table of its
/// own: it is a single row of preferences, and going through settings means
/// backups already carry it.
class QrAccount {
  const QrAccount({
    required this.bankBin,
    required this.accountNumber,
    this.holderName = '',
  });

  /// Reads back what [encode] wrote. Returns `null` for anything unreadable —
  /// a prefill is not worth crashing the screen over.
  static QrAccount? decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final bin = map['bankBin'];
      final account = map['accountNumber'];
      if (bin is! String || account is! String) return null;
      return QrAccount(
        bankBin: bin,
        accountNumber: account,
        holderName: map['holderName'] is String
            ? map['holderName'] as String
            : '',
      );
    } on FormatException {
      return null;
    }
  }

  /// NAPAS BIN of the bank, not the bank's name — names change, the BIN does
  /// not.
  final String bankBin;

  final String accountNumber;

  /// Only ever printed on the image. The QR code does not carry it.
  final String holderName;

  String encode() => jsonEncode({
    'bankBin': bankBin,
    'accountNumber': accountNumber,
    'holderName': holderName,
  });
}
