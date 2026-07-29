import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/core/date_range.dart';
import 'package:ting_ting/ui/controllers/home_controller.dart';

void main() {
  // Mốc giả: 15/07/2026, 21h — có phần giờ để chắc là bộ lọc cắt về đầu ngày.
  final now = DateTime(2026, 7, 15, 21, 30);

  group('DateFilterPreset', () {
    test('tháng này là trọn tháng đang xem', () {
      final (from, to) = DateFilterPreset.thisMonth.resolve(now);
      expect(from, DateTime(2026, 7, 1));
      expect(to, DateTime(2026, 7, 31));
    });

    test('tháng trước không dính sang ngày đầu tháng này', () {
      final (from, to) = DateFilterPreset.lastMonth.resolve(now);
      expect(from, DateTime(2026, 6, 1));
      expect(to, DateTime(2026, 6, 30));
    });

    test('7 ngày qua tính cả hôm nay nên chỉ lùi 6 ngày', () {
      final (from, to) = DateFilterPreset.last7Days.resolve(now);
      expect(from, DateTime(2026, 7, 9));
      expect(to, DateTime(2026, 7, 15));
      expect(DateRange.days(from!, to!).contains(now), isTrue);
    });

    test('tất cả là bỏ hẳn điều kiện thời gian', () {
      final (from, to) = DateFilterPreset.all.resolve(now);
      expect(from, isNull);
      expect(to, isNull);
      expect(DateRange.spanning(from: from, to: to), isNull);
    });

    test('khoảng dựng sẵn luôn phủ trọn ngày cuối', () {
      final (from, to) = DateFilterPreset.thisMonth.resolve(now);
      final range = DateRange.days(from!, to!);
      expect(range.contains(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 1)), isFalse);
    });
  });
}
