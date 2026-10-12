import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../calendar/note_attachment.dart';

/// Хранение файлов вложений заметок в каталоге приложения.
final class AttachmentStorage {
  AttachmentStorage._();

  static const _rootFolderName = 'almanac_attachments';
  static const _uuid = Uuid();

  static Future<Directory> _rootDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, _rootFolderName));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
  }

  static Future<File> resolveFile(NoteAttachment attachment) async {
    final root = await _rootDirectory();
    return File(p.join(root.path, attachment.storagePath));
  }

  static Future<NoteAttachment> importFile({
    required String eventId,
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final root = await _rootDirectory();
    final extension = p.extension(fileName);
    final attachmentId = _uuid.v4();
    final relativePath = p.join(eventId, '$attachmentId$extension');
    final target = File(p.join(root.path, relativePath));
    target.parent.createSync(recursive: true);

    await File(sourcePath).copy(target.path);

    return NoteAttachment(
      id: attachmentId,
      fileName: fileName,
      storagePath: relativePath.replaceAll('\\', '/'),
      mimeType: mimeType,
    );
  }

  static Future<void> deleteAttachment(NoteAttachment attachment) async {
    final file = await resolveFile(attachment);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  static Future<void> deleteEventAttachments(String eventId) async {
    final root = await _rootDirectory();
    final eventDir = Directory(p.join(root.path, eventId));
    if (eventDir.existsSync()) {
      await eventDir.delete(recursive: true);
    }
  }

  static Future<void> deleteRemovedAttachments({
    required List<NoteAttachment> previous,
    required List<NoteAttachment> current,
  }) async {
    final currentIds = current.map((item) => item.id).toSet();
    for (final attachment in previous) {
      if (!currentIds.contains(attachment.id)) {
        await deleteAttachment(attachment);
      }
    }
  }
}
