import 'dart:convert';
import '../../calendar/note_attachment.dart';

/// JSON-сериализация вложений заметок для локальной БД.
final class AttachmentCodec {
  AttachmentCodec._();

  static String encode(List<NoteAttachment> attachments) {
    return jsonEncode(attachments.map((item) => item.toJson()).toList());
  }

  static List<NoteAttachment> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .map((value) => NoteAttachment.fromJson(value as Map<String, dynamic>))
        .toList();
  }
}
