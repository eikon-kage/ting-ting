/// Một app được coi là nguồn dữ liệu ngân hàng.
class Source {
  Source({
    required this.packageName,
    required this.displayName,
    required this.enabled,
  });

  factory Source.fromMap(Map<String, Object?> map) => Source(
    packageName: map['package_name'] as String,
    displayName: map['display_name'] as String,
    enabled: (map['enabled'] as int? ?? 0) == 1,
  );

  final String packageName;
  final String displayName;
  final bool enabled;

  Map<String, Object?> toMap() => {
    'package_name': packageName,
    'display_name': displayName,
    'enabled': enabled ? 1 : 0,
  };
}
