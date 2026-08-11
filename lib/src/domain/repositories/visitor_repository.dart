import '../entities/polling_result.dart';
import '../entities/visitor_activity.dart';
import '../entities/visitor_session.dart';

/// Contract for visitor session / activity / polling operations.
abstract class VisitorRepository {
  /// Creates or reconnects a visitor session.
  Future<VisitorSession> createSession({
    required String tenantId,
    String? sessionId,
    bool reconnect = false,
    String? url,
    String? title,
    int? tz,
    String? navigatorLanguage,
    bool isMobile = false,
    String? domain,
  });

  /// Sends a visitor activity (message, typing, etc.).
  Future<void> sendActivity({
    required String tenantId,
    required VisitorActivity activity,
    String queryFrom = 'visitors',
  });

  /// Polls for new visitor activities since [timestamp].
  Future<PollingResult> pollActivities({
    required String tenantId,
    required String sessionId,
    required String timestamp,
  });
}
