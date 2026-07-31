import '../core/text.dart';

/// A bank that can receive a transfer through VietQR.
///
/// The QR itself carries nothing about the bank but its six-digit NAPAS BIN —
/// the names and the logo exist only so the user has something to recognise.
class VietQrBank {
  const VietQrBank(
    this.bin,
    this.shortName,
    this.fullName, {
    this.aliases = '',
  });

  /// NAPAS bank identification number, the value that goes into field 38.
  final String bin;

  /// What the bank calls itself on its app icon.
  final String shortName;

  final String fullName;

  /// Names the bank used to trade under. Banks here rebrand often and people
  /// keep searching for the old name for years.
  final String aliases;

  /// Logo shipped with the app, named after the BIN so a rebrand never leaves a
  /// file behind under a dead code.
  String get logoAsset => 'assets/banks/$bin.png';
}

/// Banks that accept a VietQR transfer straight to an account number.
///
/// Generated from NAPAS' published member list (api.vietqr.io/v2/banks), kept
/// to the members whose `transferSupported` flag is set — the rest would give
/// the user a code no app can pay. Roughly ordered by how many people bank
/// there, so the first screenful of the picker covers most users without
/// typing anything.
const List<VietQrBank> vietQrBanks = [
  VietQrBank(
    '970436',
    'Vietcombank',
    'Ngân hàng TMCP Ngoại Thương Việt Nam',
  ),
  VietQrBank(
    '970422',
    'MBBank',
    'Ngân hàng TMCP Quân đội',
    aliases: 'MB Bank Quan doi',
  ),
  VietQrBank('970407', 'Techcombank', 'Ngân hàng TMCP Kỹ thương Việt Nam'),
  VietQrBank('970415', 'VietinBank', 'Ngân hàng TMCP Công thương Việt Nam'),
  VietQrBank('970418', 'BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam'),
  VietQrBank(
    '970405',
    'Agribank',
    'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam',
    aliases: 'NN&PTNT',
  ),
  VietQrBank('970416', 'ACB', 'Ngân hàng TMCP Á Châu'),
  VietQrBank('970432', 'VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng'),
  VietQrBank('970423', 'TPBank', 'Ngân hàng TMCP Tiên Phong'),
  VietQrBank('970403', 'Sacombank', 'Ngân hàng TMCP Sài Gòn Thương Tín'),
  VietQrBank(
    '970437',
    'HDBank',
    'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh',
  ),
  VietQrBank('970441', 'VIB', 'Ngân hàng TMCP Quốc tế Việt Nam'),
  VietQrBank('970443', 'SHB', 'Ngân hàng TMCP Sài Gòn - Hà Nội'),
  VietQrBank('970426', 'MSB', 'Ngân hàng TMCP Hàng Hải Việt Nam'),
  VietQrBank('970448', 'OCB', 'Ngân hàng TMCP Phương Đông'),
  VietQrBank('970431', 'Eximbank', 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam'),
  VietQrBank('970440', 'SeABank', 'Ngân hàng TMCP Đông Nam Á'),
  VietQrBank(
    '970449',
    'LPBank',
    'Ngân hàng TMCP Lộc Phát Việt Nam',
    aliases: 'LienVietPostBank',
  ),
  VietQrBank(
    '970428',
    'NamABank',
    'Ngân hàng TMCP Nam Á',
    aliases: 'Nam A Bank',
  ),
  VietQrBank('970429', 'SCB', 'Ngân hàng TMCP Sài Gòn'),
  VietQrBank('970412', 'PVcomBank', 'Ngân hàng TMCP Đại Chúng Việt Nam'),
  VietQrBank('970419', 'NCB', 'Ngân hàng TMCP Quốc Dân'),
  VietQrBank('970427', 'VietABank', 'Ngân hàng TMCP Việt Á'),
  VietQrBank('970433', 'VietBank', 'Ngân hàng TMCP Việt Nam Thương Tín'),
  VietQrBank('970438', 'BaoVietBank', 'Ngân hàng TMCP Bảo Việt'),
  VietQrBank('970425', 'ABBANK', 'Ngân hàng TMCP An Bình'),
  VietQrBank(
    '970409',
    'BacABank',
    'Ngân hàng TMCP Bắc Á',
    aliases: 'Bac A Bank',
  ),
  VietQrBank('970452', 'KienLongBank', 'Ngân hàng TMCP Kiên Long'),
  VietQrBank('970400', 'SaigonBank', 'Ngân hàng TMCP Sài Gòn Công Thương'),
  VietQrBank('970430', 'PGBank', 'Ngân hàng TMCP Thịnh vượng và Phát triển'),
  VietQrBank(
    '970454',
    'VietCapitalBank',
    'Ngân hàng TMCP Bản Việt',
    aliases: 'BVBank Ban Viet',
  ),
  VietQrBank('970446', 'COOPBANK', 'Ngân hàng Hợp tác xã Việt Nam'),
  VietQrBank('970424', 'ShinhanBank', 'Ngân hàng TNHH MTV Shinhan Việt Nam'),
  VietQrBank('970457', 'Woori', 'Ngân hàng TNHH MTV Woori Việt Nam'),
  VietQrBank(
    '546034',
    'CAKE',
    'TMCP Việt Nam Thịnh Vượng - Ngân hàng số CAKE by VPBank',
    aliases: 'Cake by VPBank',
  ),
  VietQrBank(
    '546035',
    'Ubank',
    'TMCP Việt Nam Thịnh Vượng - Ngân hàng số Ubank by VPBank',
    aliases: 'Ubank by VPBank',
  ),
  VietQrBank(
    '963388',
    'Timo',
    'Ngân hàng số Timo by Ban Viet Bank (Timo by Ban Viet Bank)',
  ),
  VietQrBank('422589', 'CIMB', 'Ngân hàng TNHH MTV CIMB Việt Nam'),
  VietQrBank('668888', 'KBank', 'Ngân hàng Đại chúng TNHH Kasikornbank'),
  VietQrBank(
    '970414',
    'MBV',
    'Ngân hàng TNHH MTV Việt Nam Hiện Đại',
    aliases: 'OceanBank Ocean',
  ),
  VietQrBank(
    '971025',
    'MoMo',
    'CTCP Dịch Vụ Di Động Trực Tuyến',
    aliases: 'Vi MoMo',
  ),
  VietQrBank(
    '971133',
    'PVcomBank Pay',
    'Ngân hàng TMCP Đại Chúng Việt Nam Ngân hàng số',
  ),
];

/// The bank a saved BIN belongs to, or `null` when the list no longer has it.
VietQrBank? bankByBin(String bin) {
  for (final bank in vietQrBanks) {
    if (bank.bin == bin) return bank;
  }
  return null;
}

/// Banks matching what the user typed in the picker's search box.
///
/// Matches accent-insensitively, and on the BIN too: people who know their bank
/// only by the number on a transfer slip still find it.
List<VietQrBank> searchBanks(String query) {
  final needle = flatten(query.trim());
  if (needle.isEmpty) return vietQrBanks;
  return [
    for (final bank in vietQrBanks)
      if (flatten(bank.shortName).contains(needle) ||
          flatten(bank.fullName).contains(needle) ||
          flatten(bank.aliases).contains(needle) ||
          bank.bin.contains(needle))
        bank,
  ];
}
