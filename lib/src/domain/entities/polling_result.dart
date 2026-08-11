import 'visitor_activity.dart';

/// Result of a polling request against `/chatscript/visitor/polling`.
class PollingResult {
  final List<IncomingVisitorActivity> activities;

  /// Opaque cursor returned by the server for the next poll (`ts` query).
  /// TalkTroves returns an ISO datetime string; other hosts may return millis.
  final String nextTimestamp;

  const PollingResult({
    required this.activities,
    required this.nextTimestamp,
  });
}
