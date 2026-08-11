import 'attachment_file.dart';

enum MessageSender { user, assistant, system }

enum MessageStatus { sending, sent, delivered, seen, failed }

/// Visual style for how a message is rendered in the chat log.
enum ChatMessageStyle {
  /// Standard bubble layout for the sender type.
  bubble,

  /// Centered banner (e.g. name/email change notices from forms activity).
  centeredNotice,
}

/// Represents a single message in the chat conversation.
class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final AttachmentFile? attachment;
  final ChatMessageStyle style;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.attachment,
    this.style = ChatMessageStyle.bubble,
  });

  /// Helper constructor for system messages.
  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.system,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
  }

  /// Centered notice for visitor info changes (forms displayMessage).
  factory ChatMessage.infoNotice(String content) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.system,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      style: ChatMessageStyle.centeredNotice,
    );
  }

  /// Helper constructor for user messages.
  factory ChatMessage.user(String content, {AttachmentFile? attachment}) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      attachment: attachment,
    );
  }

  /// Helper constructor for assistant messages.
  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      status: MessageStatus.seen,
    );
  }

  /// Creates a copy of this message with customized values.
  ChatMessage copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    AttachmentFile? attachment,
    ChatMessageStyle? style,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      style: style ?? this.style,
    );
  }
}
