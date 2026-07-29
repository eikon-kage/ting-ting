import '../../models/models.dart';
import '../dao/rule_dao.dart';
import '../data_changes.dart';

/// Quy tắc phân loại do user tạo.
class RuleRepository {
  RuleRepository(this._dao, this._changes);

  final RuleDao _dao;
  final DataChanges _changes;

  Future<List<Rule>> all() => _dao.all();

  Future<void> add(Rule rule) async {
    await _dao.insert(rule);
    _changes.markChanged();
  }

  Future<void> remove(int id) async {
    await _dao.deleteById(id);
    _changes.markChanged();
  }
}
