/// Configuration for the JSON visitor SDK backend.
///
/// Mounted under `/chatscript/visitor` on the chatscript server.
class VisitorConfig {
  /// Absolute origin of the chatscript server, e.g. `https://api.example.com`.
  final String baseUrl;

  /// Tenant (site) identifier — required by the visitor API.
  final String tenantId;

  /// Existing session id used when [reconnect] is true.
  final String? sessionId;

  /// When true and [sessionId] is set, the server reuses that session.
  final bool reconnect;

  /// Page / app URL associated with the visitor.
  final String? url;

  /// Page / screen title.
  final String? title;

  /// Timezone offset in hours (e.g. `5` for UTC+5).
  final int? tz;

  /// Browser / device language tag, e.g. `en-US`.
  final String? navigatorLanguage;

  /// Whether the client should be treated as mobile.
  final bool isMobile;

  /// Domain label sent with the session payload.
  final String? domain;

  /// Enables Socket.IO realtime delivery. Polling always runs as fallback.
  final bool enableSocket;

  /// Polling interval when Socket.IO is unavailable or disabled.
  final Duration pollingInterval;

  /// Optional Socket.IO path override (defaults to Socket.IO standard `/socket.io`).
  final String? socketPath;

  /// Extra headers forwarded on HTTP calls (auth tokens, etc.).
  final Map<String, String> headers;

  const VisitorConfig({
    required this.baseUrl,
    required this.tenantId,
    this.sessionId,
    this.reconnect = false,
    this.url,
    this.title,
    this.tz,
    this.navigatorLanguage,
    this.isMobile = false,
    this.domain,
    this.enableSocket = true,
    this.pollingInterval = const Duration(seconds: 3),
    this.socketPath,
    this.headers = const {},
  });

  /// Normalized base URL without a trailing slash.
  String get normalizedBaseUrl {
    if (baseUrl.endsWith('/')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  VisitorConfig copyWith({
    String? baseUrl,
    String? tenantId,
    String? sessionId,
    bool? reconnect,
    String? url,
    String? title,
    int? tz,
    String? navigatorLanguage,
    bool? isMobile,
    String? domain,
    bool? enableSocket,
    Duration? pollingInterval,
    String? socketPath,
    Map<String, String>? headers,
  }) {
    return VisitorConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      tenantId: tenantId ?? this.tenantId,
      sessionId: sessionId ?? this.sessionId,
      reconnect: reconnect ?? this.reconnect,
      url: url ?? this.url,
      title: title ?? this.title,
      tz: tz ?? this.tz,
      navigatorLanguage: navigatorLanguage ?? this.navigatorLanguage,
      isMobile: isMobile ?? this.isMobile,
      domain: domain ?? this.domain,
      enableSocket: enableSocket ?? this.enableSocket,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      socketPath: socketPath ?? this.socketPath,
      headers: headers ?? this.headers,
    );
  }
}
