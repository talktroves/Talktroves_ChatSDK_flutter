import '../models/chat_message.dart';

/// Events emitted by chat backends that deliver messages asynchronously.
sealed class ChatServiceEvent {
  const ChatServiceEvent();
}

/// An assistant (or agent) message arrived.
class IncomingMessageEvent extends ChatServiceEvent {
  final ChatMessage message;

  const IncomingMessageEvent(this.message);
}

/// Typing indicator from the remote side.
class TypingEvent extends ChatServiceEvent {
  final bool isTyping;

  const TypingEvent(this.isTyping);
}

/// Connection / online status changed.
class ConnectionStatusEvent extends ChatServiceEvent {
  final bool isOnline;

  const ConnectionStatusEvent(this.isOnline);
}

/// Visitor session established successfully.
class SessionReadyEvent extends ChatServiceEvent {
  final String tenantId;
  final String sessionId;

  const SessionReadyEvent({
    required this.tenantId,
    required this.sessionId,
  });
}

/// A forms activity notice (e.g. name/email change displayMessage).
class FormNoticeEvent extends ChatServiceEvent {
  final ChatMessage message;

  const FormNoticeEvent(this.message);
}

/// Visitor session ended (logout / expire).
class SessionEndedEvent extends ChatServiceEvent {
  const SessionEndedEvent();
}

/// A recoverable or fatal backend error.
class ChatServiceErrorEvent extends ChatServiceEvent {
  final String message;
  final Object? cause;

  const ChatServiceErrorEvent(this.message, {this.cause});
}
