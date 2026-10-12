/// Вложение к заметке (фото или файл на диске приложения).
class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.mimeType,
  });

  final String id;
  final String fileName;

  /// Относительный путь внутри каталога вложений приложения.
  final String storagePath;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');

  NoteAttachment copyWith({
    String? id,
    String? fileName,
    String? storagePath,
    String? mimeType,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'storagePath': storagePath,
      'mimeType': mimeType,
    };
  }

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      storagePath: json['storagePath'] as String,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteAttachment &&
        other.id == id &&
        other.fileName == fileName &&
        other.storagePath == storagePath &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode => Object.hash(id, fileName, storagePath, mimeType);
}
