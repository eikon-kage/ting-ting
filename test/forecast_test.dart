import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/models/models.dart';

MonthForecast forecast({
  required int spent,
  required int day,
  int month = 7,
  int? previous,
}) => MonthForecast.of(
  month: DateTime(2026, month),
  spent: spent,
  now: DateTime(2026, month, day, 20),
  previousTotal: previous,
);

void main() {
  group('Dự báo cuối tháng', () {
    test('kéo dài nhịp chi hiện tại tới hết tháng', () {
      // 3.100.000 trong 10/31 ngày -> khoảng 9.610.000 cả tháng.
      final f = forecast(spent: 3100000, day: 10);
      expect(f.daysInMonth, 31);
      expect(f.daysLeft, 21);
      expect(f.dailyRate, 310000);
      expect(f.projected, 9610000);
    });

    test('tháng 2 có 28 ngày, không cứng 30', () {
      final f = forecast(spent: 1400000, day: 14, month: 2);
      expect(f.daysInMonth, 28);
      expect(f.projected, 2800000);
    });

    test('vài ngày đầu tháng thì chưa nói gì', () {
      expect(forecast(spent: 5000000, day: 1).reliable, isFalse);
      expect(forecast(spent: 5000000, day: 2).reliable, isFalse);
      expect(forecast(spent: 5000000, day: 3).reliable, isTrue);
    });

    test('chưa tiêu đồng nào thì không có gì để đoán', () {
      expect(forecast(spent: 0, day: 15).reliable, isFalse);
    });

    test('tháng đã trôi hết thì dự báo chính là số thật', () {
      final f = forecast(spent: 8000000, day: 31);
      expect(f.isComplete, isTrue);
      expect(f.projected, 8000000);
    });

    test('tháng đã qua thì tính là trọn vẹn, không đoán nữa', () {
      final f = MonthForecast.of(
        month: DateTime(2026, 5),
        spent: 7000000,
        now: DateTime(2026, 7, 15),
      );
      expect(f.isComplete, isTrue);
      expect(f.daysElapsed, 31);
      expect(f.projected, 7000000);
    });

    test('so với tháng trước theo con số dự báo, không theo số đã chi', () {
      final f = forecast(spent: 3100000, day: 10, previous: 8000000);
      // Mới chi 3,1tr, ít hơn 8tr — nhưng đà này sẽ vượt.
      expect(f.diffVsPrevious, 1610000);
    });

    test('không có tháng trước thì không so', () {
      expect(forecast(spent: 3100000, day: 10).diffVsPrevious, isNull);
      expect(forecast(spent: 3100000, day: 10).dailyBudgetLeft, isNull);
    });

    test('chỉ ra được mỗi ngày còn tiêu bao nhiêu để không vượt', () {
      // Còn 21 ngày, còn được tiêu 8tr - 3,1tr = 4,9tr.
      final f = forecast(spent: 3100000, day: 10, previous: 8000000);
      expect(f.dailyBudgetLeft, 233333);
    });

    test('lỡ vượt mức tháng trước thì phần còn lại là số âm', () {
      final f = forecast(spent: 9000000, day: 10, previous: 8000000);
      expect(f.dailyBudgetLeft, lessThan(0));
    });
  });
}
