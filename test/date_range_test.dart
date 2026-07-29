import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/core/date_range.dart';

void main() {
  group('DateRange.days', () {
    test('lấy trọn cả ngày cuối, không cắt lúc 0h', () {
      final range = DateRange.days(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      expect(range.from, DateTime(2026, 7, 1));
      expect(range.to, DateTime(2026, 8, 1));
      expect(range.contains(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 1)), isFalse);
    });

    test('bỏ qua phần giờ phút của ngày được chọn', () {
      final range = DateRange.days(
        DateTime(2026, 7, 10, 15, 30),
        DateTime(2026, 7, 10, 8),
      );
      expect(range.contains(DateTime(2026, 7, 10)), isTrue);
      expect(range.contains(DateTime(2026, 7, 9, 23, 59)), isFalse);
    });

    test('chọn một ngày duy nhất vẫn ra khoảng dài đúng một ngày', () {
      final range = DateRange.days(
        DateTime(2026, 7, 28),
        DateTime(2026, 7, 28),
      );
      expect(range.contains(DateTime(2026, 7, 28, 12)), isTrue);
      expect(range.contains(DateTime(2026, 7, 27, 23, 59)), isFalse);
      expect(range.contains(DateTime(2026, 7, 29)), isFalse);
    });
  });

  group('endOfMonth', () {
    test('trả ngày cuối đúng cho tháng 30 và 31 ngày', () {
      expect(endOfMonth(DateTime(2026, 4, 15)), DateTime(2026, 4, 30));
      expect(endOfMonth(DateTime(2026, 7, 1)), DateTime(2026, 7, 31));
    });

    test('tháng 2 năm nhuận vẫn ra 29', () {
      expect(endOfMonth(DateTime(2024, 2, 10)), DateTime(2024, 2, 29));
      expect(endOfMonth(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
    });

    test('tháng 12 nhảy sang năm sau mà không lệch', () {
      expect(endOfMonth(DateTime(2026, 12, 5)), DateTime(2026, 12, 31));
    });
  });

  group('DateRange.spanning', () {
    test('không có đầu nào thì không lọc theo thời gian', () {
      expect(DateRange.spanning(), isNull);
    });

    test('chỉ có ngày bắt đầu thì mở về phía tương lai', () {
      final range = DateRange.spanning(from: DateTime(2026, 7, 1))!;
      expect(range.contains(DateTime(2026, 7, 1)), isTrue);
      expect(range.contains(DateTime(2030, 1, 1)), isTrue);
      expect(range.contains(DateTime(2026, 6, 30, 23, 59)), isFalse);
    });

    test('chỉ có ngày kết thúc thì mở về phía quá khứ', () {
      final range = DateRange.spanning(to: DateTime(2026, 7, 31))!;
      expect(range.fromMillis, 0);
      expect(range.contains(DateTime(2020, 1, 1)), isTrue);
      expect(range.contains(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 1)), isFalse);
    });

    test('có cả hai đầu thì giống DateRange.days', () {
      final spanning = DateRange.spanning(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 15),
      )!;
      final days = DateRange.days(DateTime(2026, 7, 1), DateTime(2026, 7, 15));
      expect(spanning.fromMillis, days.fromMillis);
      expect(spanning.toMillis, days.toMillis);
    });
  });
}
