import '../../models/models.dart';
import 'base_controller.dart';

/// Quy tắc tự phân loại do user tạo.
class RulesController extends BaseController {
  RulesController({super.data});

  List<Rule> _rules = const [];

  List<Rule> get rules => _rules;
  bool get isEmpty => _rules.isEmpty;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _rules = await data.rules.all();
  });

  Future<void> add(Rule rule) => data.rules.add(rule);

  Future<void> remove(Rule rule) async {
    if (rule.id == null) return;
    await data.rules.remove(rule.id!);
  }
}
