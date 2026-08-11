/// Active visitor session returned by the SDK session endpoint.
class VisitorSession {
  final String tenantId;
  final String sessionId;
  final Map<String, dynamic>? script;

  const VisitorSession({
    required this.tenantId,
    required this.sessionId,
    this.script,
  });

  @override
  String toString() =>
      'VisitorSession(tenantId: $tenantId, sessionId: $sessionId)';
}
