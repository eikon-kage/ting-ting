import '../models/models.dart';
import 'bank_parser.dart';
import 'categorizer.dart';

/// Dựng đối tượng [Txn] từ dữ liệu thô. Đây là chỗ duy nhất quyết định một
/// giao dịch mới mang nhóm gì, có bị loại khỏi báo cáo không, có phải chuyển
/// ví không — service lẫn UI đều gọi vào đây thay vì tự ráp.
class TxnFactory {
  const TxnFactory._();

  /// Giao dịch dựng từ một notification đã bóc tách được.
  static Txn fromNotification({
    required String packageName,
    required String bankName,
    required String title,
    required String content,
    required DateTime postTime,
    required ParseResult parsed,
    List<Rule> userRules = const [],
    List<Category> categories = defaultCategories,
  }) {
    final suggestion = Categorizer.categorize(
      '$title $content',
      parsed.direction,
      userRules: userRules,
      categories: categories,
    );
    return Txn(
      packageName: packageName,
      bankName: bankName,
      direction: parsed.direction,
      amount: parsed.amount,
      balance: parsed.balance,
      description: parsed.description,
      category: suggestion.category,
      rawTitle: title,
      rawContent: content,
      postTime: postTime,
      needsReview: !parsed.directionConfident,
      excluded: suggestion.excluded,
      // Rút tiền ATM chỉ là chuyển tiền từ tài khoản sang ví tiền mặt,
      // không phải một khoản chi.
      isTransfer:
          suggestion.category == Categorizer.withdrawal &&
          parsed.direction == TxnDirection.expense,
    );
  }

  /// Giao dịch user tự nhập.
  ///
  /// Mỗi bản ghi nhận một khoá riêng: user có quyền ghi hai khoản giống hệt
  /// nhau, không được coi là trùng.
  static Txn manual({
    required TxnDirection direction,
    required int amount,
    required String category,
    required DateTime postTime,
    required AccountKind accountKind,
    String? walletName,
    String? description,
    String? note,
  }) {
    final wallet = walletName?.trim();
    return Txn(
      packageName: Txn.manualPackage,
      bankName: wallet == null || wallet.isEmpty ? accountKind.label : wallet,
      accountKind: accountKind,
      direction: direction,
      amount: amount,
      description: _clean(description),
      category: category,
      rawTitle: '',
      rawContent: '',
      postTime: postTime,
      note: _clean(note),
      fingerprintOverride: 'manual|${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  /// Khoản bù trừ khi user tự sửa "số tiền đang có".
  ///
  /// Số dư không được lưu thành một con số riêng: tiền mặt là tổng các giao
  /// dịch, số dư tài khoản là dòng "SD" mới nhất. Muốn nó thành [target] thì
  /// ghi thêm đúng phần chênh lệch — lịch sử vẫn cộng ra được con số đang hiện,
  /// không có chỗ nào phải "tin lời" một giá trị chép tay.
  ///
  /// Khoản này không phải thu hay chi thật nên bị loại khỏi báo cáo.
  /// Trả về `null` khi số dư không đổi — không cần ghi gì.
  static Txn? balanceAdjustment({
    required AccountKind accountKind,
    required String walletName,
    required int current,
    required int target,
    required DateTime at,
    String? note,
  }) {
    final delta = target - current;
    if (delta == 0) return null;
    final wallet = walletName.trim();
    return Txn(
      packageName: Txn.manualPackage,
      bankName: wallet.isEmpty ? accountKind.label : wallet,
      accountKind: accountKind,
      direction: delta > 0 ? TxnDirection.income : TxnDirection.expense,
      amount: delta.abs(),
      // Ví ngân hàng đọc số dư từ trường này chứ không cộng dồn giao dịch,
      // nên phải đặt luôn con số user vừa nhập vào đây.
      balance: accountKind == AccountKind.bank ? target : null,
      description: 'Sửa số dư',
      category: Categorizer.uncategorized,
      rawTitle: '',
      rawContent: '',
      postTime: at,
      note: _clean(note),
      excluded: true,
      fingerprintOverride: 'manual|${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  /// Khoản bù cho một chỗ hở mà việc đối soát số dư tìm ra.
  ///
  /// Đây là giao dịch có thật, đã xảy ra ở ngân hàng, chỉ là app không nhận
  /// được thông báo nên chưa ghi. Vì vậy nó **được** tính vào Thu–Chi — bỏ nó
  /// ra thì báo cáo vẫn thiếu đúng chỗ vừa phát hiện. Nhưng không ai biết nó
  /// là khoản gì nên gắn cờ "cần xem lại" để user tự đặt lại nhóm.
  ///
  /// Không đặt `balance`: chỉ cần số tiền đúng là mắt xích khớp trở lại, và
  /// khai một số dư mình không thực sự biết thì lần đối soát sau sẽ tin nhầm.
  ///
  /// [at] nên nằm trong khoảng hai đầu chỗ hở. Không biết chính xác lúc nào
  /// nên UI mặc định lấy sát ngay trước giao dịch làm lộ ra chênh lệch.
  static Txn missing({
    required String bankName,
    required TxnDirection direction,
    required int amount,
    required DateTime at,
    String? note,
  }) => Txn(
    packageName: Txn.manualPackage,
    bankName: bankName,
    direction: direction,
    amount: amount,
    description: 'Khoản bù từ kiểm sổ',
    category: direction == TxnDirection.income
        ? Categorizer.income
        : Categorizer.uncategorized,
    rawTitle: '',
    rawContent: '',
    postTime: at,
    note: _clean(note),
    needsReview: true,
    fingerprintOverride: 'manual|${DateTime.now().microsecondsSinceEpoch}',
  );

  /// Khoản nợ user ghi thẳng vào sổ, không đi từ giao dịch nào có sẵn.
  ///
  /// Hướng tiền suy ra từ loại nợ chứ không hỏi lại user: cho vay thì tiền ra,
  /// thu nợ thì tiền vào. Nhóm để mặc định vì khoản nợ không vào Thu–Chi.
  static Txn debt({
    required DebtType type,
    required int amount,
    required String person,
    required DateTime postTime,
    required AccountKind accountKind,
    String? walletName,
    String? note,
  }) {
    final wallet = walletName?.trim();
    final who = person.trim();
    return Txn(
      packageName: Txn.manualPackage,
      bankName: wallet == null || wallet.isEmpty ? accountKind.label : wallet,
      accountKind: accountKind,
      direction: type.direction,
      amount: amount,
      description: '${type.label} · $who',
      category: Categorizer.uncategorized,
      rawTitle: '',
      rawContent: '',
      postTime: postTime,
      note: _clean(note),
      debtType: type,
      person: who,
      fingerprintOverride: 'manual|${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  static String? _clean(String? raw) {
    final text = raw?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
