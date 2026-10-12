import 'dart:convert';
import '../../calendar/calendar_types.dart';

/// JSON-сериализация чек-листов для локальной БД.
final class ChecklistCodec {
  ChecklistCodec._();

  static String encode(List<ChecklistItem> items) {
    return jsonEncode(_encodeItems(items));
  }

  static List<ChecklistItem> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return _decodeItems(decoded);
  }

  static List<Map<String, dynamic>> _encodeItems(List<ChecklistItem> items) {
    return items
        .map(
          (item) => {
            'id': item.id,
            'title': item.title,
            'completed': item.completed,
            'children': _encodeItems(item.children),
          },
        )
        .toList();
  }

  static List<ChecklistItem> _decodeItems(List<dynamic> raw) {
    return raw.map((value) {
      final map = value as Map<String, dynamic>;
      return ChecklistItem(
        id: map['id'] as String,
        title: map['title'] as String,
        completed: map['completed'] as bool? ?? false,
        children: _decodeItems(map['children'] as List<dynamic>? ?? const []),
      );
    }).toList();
  }
}
