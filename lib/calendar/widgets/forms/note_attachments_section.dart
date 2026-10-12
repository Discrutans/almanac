import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../../data/attachments/attachment_storage.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../note_attachment.dart';

/// Секция вложений для формы заметки.
class NoteAttachmentsSection extends StatelessWidget {
  const NoteAttachmentsSection({
    super.key,
    required this.eventId,
    required this.attachments,
    required this.onChanged,
    this.onError,
    this.readOnly = false,
  });

  final String eventId;
  final List<NoteAttachment> attachments;
  final ValueChanged<List<NoteAttachment>> onChanged;
  final ValueChanged<String>? onError;
  final bool readOnly;

  Future<void> _importAttachment({
    required BuildContext context,
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final attachment = await AttachmentStorage.importFile(
        eventId: eventId,
        sourcePath: sourcePath,
        fileName: fileName,
        mimeType: mimeType,
      );
      if (!context.mounted) return;
      onChanged([...attachments, attachment]);
    } catch (_) {
      if (!context.mounted) return;
      onError?.call(AppLocalizations.of(context).attachmentPickError);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !context.mounted) return;
    await _importAttachment(
      context: context,
      sourcePath: image.path,
      fileName: image.name,
      mimeType: 'image/${_imageMimeExtension(image.path)}',
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null || !context.mounted) return;
    await _importAttachment(
      context: context,
      sourcePath: image.path,
      fileName: image.name,
      mimeType: 'image/${_imageMimeExtension(image.path)}',
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withReadStream: false);
    if (result == null || result.files.isEmpty || !context.mounted) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      onError?.call(AppLocalizations.of(context).attachmentPickError);
      return;
    }
    await _importAttachment(
      context: context,
      sourcePath: path,
      fileName: file.name,
      mimeType: _mimeTypeForFile(file.name, file.extension),
    );
  }

  Future<void> _removeAttachment(NoteAttachment attachment) async {
    await AttachmentStorage.deleteAttachment(attachment);
    onChanged(attachments.where((item) => item.id != attachment.id).toList());
  }

  Future<void> _openAttachment(
    BuildContext context,
    NoteAttachment attachment,
  ) async {
    if (attachment.isImage) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AttachmentImageDialog(attachment: attachment),
      );
      return;
    }

    final file = await AttachmentStorage.resolveFile(attachment);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      onError?.call(AppLocalizations.of(context).openAttachmentError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (readOnly && attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.noteAttachmentsLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (!readOnly) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          Wrap(
            spacing: AlmanacSpacing.xs,
            runSpacing: AlmanacSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickFromGallery(context),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(l10n.addPhotoFromGallery),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickFromCamera(context),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.addPhotoFromCamera),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickFile(context),
                icon: const Icon(Icons.attach_file_outlined, size: 18),
                label: Text(l10n.addFile),
              ),
            ],
          ),
        ],
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          Wrap(
            spacing: AlmanacSpacing.xs,
            runSpacing: AlmanacSpacing.xs,
            children: attachments.map((attachment) {
              return _AttachmentTile(
                attachment: attachment,
                onOpen: () => _openAttachment(context, attachment),
                onRemove: readOnly ? null : () => _removeAttachment(attachment),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onOpen,
    this.onRemove,
  });

  final NoteAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: AlmanacRadius.control,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            borderRadius: AlmanacRadius.control,
            child: SizedBox(
              width: attachment.isImage ? 72 : 120,
              height: 72,
              child: attachment.isImage
                  ? FutureBuilder<File>(
                      future: AttachmentStorage.resolveFile(attachment),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.existsSync()) {
                          return const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          );
                        }
                        return Image.file(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          cacheWidth: 144,
                          cacheHeight: 144,
                          filterQuality: FilterQuality.low,
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AlmanacSpacing.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attachment.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -8,
            right: -8,
            child: IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }
}

class _AttachmentImageDialog extends StatelessWidget {
  const _AttachmentImageDialog({required this.attachment});

  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AlmanacSpacing.md),
      child: FutureBuilder<File>(
        future: AttachmentStorage.resolveFile(attachment),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.existsSync()) {
            return const SizedBox(
              width: 240,
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return InteractiveViewer(
            child: Image.file(
              snapshot.data!,
              cacheWidth: 1200,
              filterQuality: FilterQuality.medium,
            ),
          );
        },
      ),
    );
  }
}

String _imageMimeExtension(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.webp')) return 'webp';
  if (lower.endsWith('.gif')) return 'gif';
  return 'jpeg';
}

String _mimeTypeForFile(String fileName, String? extension) {
  final ext = (extension ?? fileName.split('.').last).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return 'application/octet-stream';
  }
}
