import '../../models/chat_message.dart';
import 'visitor_activity.dart';

/// Paginated tenant history result from `GET /api/tenant/history`.
class ChatHistoryResult {
  final List<IncomingVisitorActivity> activities;
  final int page;
  final int? totalCount;

  const ChatHistoryResult({
    required this.activities,
    this.page = 1,
    this.totalCount,
  });

  List<ChatMessage> toChatMessages() {
    final messages = <ChatMessage>[];
    for (final activity in activities) {
      if (activity.isTyping || activity.isStatusEvent) continue;

      if (activity.isFormActivity) {
        final notice = activity.displayMessage;
        if (notice == null || notice.isEmpty) continue;
        messages.add(
          ChatMessage.infoNotice(notice).copyWith(
            id: activity.id,
            timestamp: activity.timestamp ?? DateTime.now(),
          ),
        );
        continue;
      }

      final text = activity.messageText?.trim();
      if (text == null || text.isEmpty) continue;

      final timestamp = activity.timestamp ?? DateTime.now();
      if (activity.isFromAgent) {
        messages.add(
          ChatMessage.assistant(text).copyWith(
            id: activity.id,
            timestamp: timestamp,
          ),
        );
      } else {
        messages.add(
          ChatMessage.user(text).copyWith(
            id: activity.id,
            timestamp: timestamp,
            status: MessageStatus.seen,
          ),
        );
      }
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }
}
