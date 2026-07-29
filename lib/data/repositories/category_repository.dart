import '../../models/models.dart';
import '../dao/category_dao.dart';
import '../dao/rule_dao.dart';
import '../dao/txn_dao.dart';
import '../data_changes.dart';

/// Nhóm chi tiêu do user quản lý.
///
/// Tên nhóm được chép thẳng vào từng giao dịch (bảng `txns` giữ chuỗi tên chứ
/// không giữ khoá ngoại), nên mọi thay đổi ở đây đều phải kéo theo giao dịch và
/// quy tắc đang dùng tên cũ — nếu không, sửa một cái tên là mất cả một mảng
/// giao dịch khỏi báo cáo.
class CategoryRepository {
  CategoryRepository(this._dao, this._txns, this._rules, this._changes);

  final CategoryDao _dao;
  final TxnDao _txns;
  final RuleDao _rules;
  final DataChanges _changes;

  Future<List<Category>> all() => _dao.all();

  Future<Map<String, int>> txnCounts() => _txns.countsByCategory();

  /// Thêm nhóm mới. Tên trùng (kể cả khác dấu, khác hoa thường) bị từ chối.
  Future<CategorySaveResult> add({
    required String name,
    List<String> keywords = const [],
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return CategorySaveResult.nameEmpty;
    if (await _nameTaken(clean)) return CategorySaveResult.nameTaken;
    await _dao.insert(Category(name: clean, keywords: keywords));
    _changes.markChanged();
    return CategorySaveResult.ok;
  }

  /// Sửa nhóm đã có. Nhóm hệ thống giữ nguyên tên, chỉ đổi được từ khoá.
  Future<CategorySaveResult> save(
    Category category, {
    required String name,
    required List<String> keywords,
  }) async {
    if (category.id == null) return CategorySaveResult.ok;
    final clean = category.builtIn ? category.name : name.trim();
    if (clean.isEmpty) return CategorySaveResult.nameEmpty;
    if (await _nameTaken(clean, exceptId: category.id)) {
      return CategorySaveResult.nameTaken;
    }
    await _dao.update(category.copyWith(name: clean, keywords: keywords));
    if (clean != category.name) {
      await _txns.replaceCategory(category.name, clean);
      await _rules.replaceCategory(category.name, clean);
    }
    _changes.markChanged();
    return CategorySaveResult.ok;
  }

  /// Xoá nhóm và dồn giao dịch của nó về [moveTo].
  ///
  /// Trả về `false` với nhóm hệ thống: phần mềm tự nhắc tới tên chúng nên
  /// không cho xoá.
  Future<bool> remove(
    Category category, {
    String moveTo = Category.uncategorized,
  }) async {
    if (category.id == null || category.builtIn) return false;
    await _dao.deleteById(category.id!);
    await _txns.replaceCategory(category.name, moveTo);
    await _rules.replaceCategory(category.name, moveTo);
    _changes.markChanged();
    return true;
  }

  Future<bool> _nameTaken(String name, {int? exceptId}) async {
    final existing = await _dao.all();
    return existing.any(
      (c) => c.id != exceptId && Category.sameName(c.name, name),
    );
  }
}
