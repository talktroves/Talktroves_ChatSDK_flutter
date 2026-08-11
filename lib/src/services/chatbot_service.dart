import '../models/chat_message.dart';
import '../models/user_data.dart';
import 'chat_service_event.dart';

/// Interface for chat backends (visitor SDK or a custom implementation).
abstract class ChatbotService {
  /// Sends a visitor message to the backend.
  ///
  /// Visitor SDK returns `null` and delivers agent replies through [events].
  Future<String?> sendMessage({
    required String content,
    required List<ChatMessage> history,
    required SupportUserData? userData,
    String? deviceId,
  });

  /// Whether replies arrive via [events] instead of [sendMessage]'s return.
  bool get usesRealtimeDelivery => true;

  /// Stream of inbound events (messages, typing, session, connection).
  Stream<ChatServiceEvent> get events => const Stream.empty();

  /// Create session / connect socket / start polling.
  Future<void> start() async {}

  /// Tear down polling / sockets.
  Future<void> stop() async {}

  /// Update visitor name/email via forms activity.
  Future<void> updateVisitorInfo({
    required String name,
    required String email,
  }) async {
    throw UnsupportedError('updateVisitorInfo is not supported by this backend');
  }

  /// End the active session (expire on server when supported, then stop locally).
  Future<void> logout() async {
    await stop();
  }

  /// Release resources.
  Future<void> dispose() async {}
}
