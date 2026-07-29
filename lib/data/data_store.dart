import 'app_database.dart';
import 'dao/backup_dao.dart';
import 'dao/category_dao.dart';
import 'dao/parser_profile_dao.dart';
import 'dao/raw_log_dao.dart';
import 'dao/rule_dao.dart';
import 'dao/settings_dao.dart';
import 'dao/source_dao.dart';
import 'dao/txn_dao.dart';
import 'data_changes.dart';
import 'repositories/backup_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/debt_repository.dart';
import 'repositories/parser_profile_repository.dart';
import 'repositories/raw_log_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/rule_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/source_repository.dart';
import 'repositories/txn_repository.dart';

export 'data_changes.dart';
export 'repositories/backup_repository.dart';
export 'repositories/category_repository.dart';
export 'repositories/debt_repository.dart';
export 'repositories/parser_profile_repository.dart';
export 'repositories/raw_log_repository.dart';
export 'repositories/report_repository.dart';
export 'repositories/rule_repository.dart';
export 'repositories/settings_repository.dart';
export 'repositories/source_repository.dart';
export 'repositories/txn_repository.dart';

/// Cửa duy nhất dẫn tới dữ liệu.
///
/// UI và service lấy repository ở đây, không ai được `import` DAO hay sqflite.
/// Muốn đổi chỗ lưu trữ (đổi engine, thêm cache, đồng bộ lên server) thì chỉ
/// sửa trong `data/`, các tầng trên không biết gì.
///
/// Test dựng được bản riêng bằng [DataStore.on] với một [AppDatabase] khác.
class DataStore {
  DataStore._({
    required this.changes,
    required this.txns,
    required this.reports,
    required this.debts,
    required this.categories,
    required this.rules,
    required this.sources,
    required this.rawLogs,
    required this.parserProfiles,
    required this.backups,
    required this.settings,
  });

  factory DataStore.on(AppDatabase database) {
    final changes = DataChanges();
    final txnDao = TxnDao(database);
    final ruleDao = RuleDao(database);
    return DataStore._(
      changes: changes,
      txns: TxnRepository(txnDao, changes),
      reports: ReportRepository(txnDao),
      debts: DebtRepository(txnDao, changes),
      categories: CategoryRepository(
        CategoryDao(database),
        txnDao,
        ruleDao,
        changes,
      ),
      rules: RuleRepository(ruleDao, changes),
      sources: SourceRepository(SourceDao(database), changes),
      rawLogs: RawLogRepository(RawLogDao(database)),
      parserProfiles: ParserProfileRepository(
        ParserProfileDao(database),
        changes,
      ),
      backups: BackupRepository(BackupDao(database), txnDao, changes),
      settings: SettingsRepository(SettingsDao(database), changes),
    );
  }

  static final DataStore instance = DataStore.on(AppDatabase.instance);

  /// Gõ chuông mỗi khi có gì đó được ghi — controller nghe để tự tải lại.
  final DataChanges changes;

  final TxnRepository txns;
  final ReportRepository reports;
  final DebtRepository debts;

  /// Nhóm chi tiêu user tự quản lý.
  final CategoryRepository categories;

  final RuleRepository rules;
  final SourceRepository sources;
  final RawLogRepository rawLogs;

  /// Mẫu bóc tách riêng user khai cho từng ngân hàng.
  final ParserProfileRepository parserProfiles;

  /// Đường đưa dữ liệu ra khỏi máy và nhận lại.
  final BackupRepository backups;

  /// Lựa chọn lặt vặt của user.
  final SettingsRepository settings;
}
