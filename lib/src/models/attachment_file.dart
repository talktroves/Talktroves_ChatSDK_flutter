import 'dart:typed_data';

/// Model representing an attachment (such as an image) to be sent in the chat.
class AttachmentFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const AttachmentFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}
