T enumFromName<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be a string.');
  }

  return values.firstWhere(
    (entry) => entry.name == value,
    orElse: () => throw FormatException('Unknown $field: $value.'),
  );
}

double doubleFromMap(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is num) return value.toDouble();
  throw FormatException('$field must be numeric.');
}

int intFromMap(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is int) return value;
  throw FormatException('$field must be an integer.');
}
