/// Bản ghi thô của mọi notification đi qua máy — dùng để soi và thêm nguồn mới.
class RawLog {
  RawLog({
    this.id,
    required this.packageName,
    required this.title,
    required this.content,
    required this.postTime,
    required this.parsed,
  });

  factory RawLog.fromMap(Map<String, Object?> map) => RawLog(
    id: map['id'] as int?,
    packageName: map['package_name'] as String,
    title: map['title'] as String? ?? '',
    content: map['content'] as String? ?? '',
    postTime: DateTime.fromMillisecondsSinceEpoch(map['post_time'] as int),
    parsed: (map['parsed'] as int? ?? 0) == 1,
  );

  final int? id;
  final String packageName;
  final String title;
  final String content;
  final DateTime postTime;

  /// Đã bóc tách thành công thành giao dịch hay chưa.
  final bool parsed;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'package_name': packageName,
    'title': title,
    'content': content,
    'post_time': postTime.millisecondsSinceEpoch,
    'parsed': parsed ? 1 : 0,
  };
}
