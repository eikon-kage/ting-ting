/// Tên gợi ý cho vài app ngân hàng / ví phổ biến. Chỉ là nhãn hiển thị ban đầu,
/// user đổi lại được trong màn Nguồn — đoán sai cũng không ảnh hưởng dữ liệu.
const Map<String, String> knownBankNames = {
  'com.VCB': 'Vietcombank',
  'com.vietinbank.ipay': 'VietinBank',
  'com.mbmobile': 'MB Bank',
  'vn.com.techcombank.bb.app': 'Techcombank',
  'com.tpb.mb.gprsandroid': 'TPBank',
  'com.vnpay.bidv': 'BIDV',
  'com.vnpay.agribank3g': 'Agribank',
  'com.vnpay.vpbankonline': 'VPBank',
  'mobile.acb.com.vn': 'ACB',
  'vn.com.msb.smartBanking': 'MSB',
  'com.ocb.omniapp': 'OCB',
  'com.mservice.momotransfer': 'MoMo',
  'vn.com.vng.zalopay': 'ZaloPay',
};

/// Tên hiển thị mặc định cho một app chưa biết: lấy tên gợi ý nếu có, không thì
/// dùng luôn package name.
String suggestedBankName(String packageName) =>
    knownBankNames[packageName] ?? packageName;
