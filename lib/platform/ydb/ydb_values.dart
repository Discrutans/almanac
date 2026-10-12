import 'package:ydb_flutter_sdk/ydb_flutter_sdk.dart';

IYdbValue<dynamic>? ydbCell(Map<String, IYdbValue<dynamic>> row, String name) {
  final direct = row[name];
  if (direct != null) return direct;
  final lower = name.toLowerCase();
  for (final entry in row.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

String ydbRowString(Map<String, IYdbValue<dynamic>> row, String name) {
  return ydbString(ydbCell(row, name));
}

DateTime ydbRowTime(Map<String, IYdbValue<dynamic>> row, String name) {
  return ydbTime(ydbCell(row, name));
}

String ydbString(IYdbValue<dynamic>? value) {
  if (value == null) return '';
  if (value is YdbOptional) return ydbString(value.value);
  final raw = value.value;
  if (raw == null) return '';
  if (raw is IYdbValue) return ydbString(raw);
  if (raw is DateTime) return raw.toUtc().toIso8601String();
  return raw.toString();
}

DateTime ydbTime(IYdbValue<dynamic>? value) {
  if (value is YdbTimestamp) return value.value.toUtc();
  if (value is YdbOptional) return ydbTime(value.value);
  final parsed = DateTime.tryParse(ydbString(value));
  return parsed?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
