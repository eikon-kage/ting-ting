/// Khoảng thời gian nửa mở `[from, to)`.
///
/// Mọi câu truy vấn theo thời gian đều đi qua kiểu này để không nơi nào phải
/// tự cộng trừ tháng rồi quên mất biên trên là mở hay đóng.
class DateRange {
  const DateRange(this.from, this.to);

  /// Trọn một tháng chứa [month].
  factory DateRange.month(DateTime month) =>
      DateRange(startOfMonth(month), shiftMonth(month, 1));

  /// Trọn tuần chứa [day], tính từ thứ Hai.
  factory DateRange.week(DateTime day) {
    final monday = startOfWeek(day);
    return DateRange(monday, shiftWeek(monday, 1));
  }

  /// [count] tháng liên tiếp, kết thúc ở hết tháng chứa [month].
  factory DateRange.monthsUpTo(DateTime month, int count) =>
      DateRange(shiftMonth(month, -(count - 1)), shiftMonth(month, 1));

  /// Từ đầu ngày [from] đến **hết** ngày [to].
  ///
  /// User chọn ngày trên lịch thì hiểu là trọn cả ngày, nên biên trên phải nhảy
  /// sang ngày kế — nếu để nguyên thì giao dịch lúc 20h của ngày cuối bị rớt.
  factory DateRange.days(DateTime from, DateTime to) =>
      DateRange(startOfDay(from), nextDay(to));

  /// Khoảng ngày hở một đầu: thiếu [from] là "từ trước tới nay", thiếu [to] là
  /// "đến tận bây giờ". Không có đầu nào thì trả `null` để tầng dữ liệu bỏ hẳn
  /// điều kiện thời gian thay vì quét một khoảng vô nghĩa.
  ///
  /// [from] phải không muộn hơn [to]; xếp ngược thì ra khoảng rỗng.
  static DateRange? spanning({DateTime? from, DateTime? to}) {
    if (from == null && to == null) return null;
    return DateRange(
      from == null ? _beginning : startOfDay(from),
      to == null ? _endless : nextDay(to),
    );
  }

  /// Mốc 0 của epoch: không giao dịch nào có `post_time` nhỏ hơn.
  static final DateTime _beginning = DateTime.fromMillisecondsSinceEpoch(0);

  /// Xa hơn mọi giao dịch có thật, kể cả khi đồng hồ máy bị đặt sai.
  static final DateTime _endless = DateTime(9999);

  final DateTime from;
  final DateTime to;

  int get fromMillis => from.millisecondsSinceEpoch;
  int get toMillis => to.millisecondsSinceEpoch;

  bool contains(DateTime moment) =>
      !moment.isBefore(from) && moment.isBefore(to);
}

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ngày cuối cùng của tháng chứa [d]. Ngày 0 của tháng sau chính là ngày cuối
/// tháng này, nên không phải nhớ tháng nào 30 hay 31 ngày.
DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// Đầu ngày hôm sau. Cộng vào trường `day` chứ không cộng 24 giờ, để vẫn đúng
/// khi tràn tháng.
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Như [startOfDay] nhưng cho phép bỏ trống — bộ lọc để ngỏ một đầu là chuyện
/// thường.
DateTime? startOfDayOrNull(DateTime? d) => d == null ? null : startOfDay(d);

/// Thứ Hai của tuần chứa [d]. Tuần bắt đầu từ thứ Hai chứ không phải Chủ Nhật —
/// người Việt nói "tuần này" là tính từ thứ Hai.
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// Cùng thứ trong tuần, cách [delta] tuần. Cộng vào trường `day` chứ không
/// cộng số giờ, để không lệch khi múi giờ đổi.
DateTime shiftWeek(DateTime d, int delta) =>
    DateTime(d.year, d.month, d.day + 7 * delta);

/// Đầu tháng cách [d] đúng [delta] tháng — vẫn đúng khi tràn năm.
DateTime shiftMonth(DateTime d, int delta) =>
    DateTime(d.year, d.month + delta);

DateTime get thisWeek => startOfWeek(DateTime.now());

DateTime get thisMonth => startOfMonth(DateTime.now());

bool isCurrentMonth(DateTime month) => startOfMonth(month) == thisMonth;
