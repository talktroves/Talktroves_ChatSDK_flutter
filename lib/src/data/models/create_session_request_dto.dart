/// Request body for `POST /chatscript/visitor/session`.
class CreateSessionRequestDto {
  final String tenantId;
  final String? sessionId;
  final bool reconnect;
  final String? url;
  final String? title;
  final int? tz;
  final String? navigatorLanguage;
  final bool isMobile;
  final String? domain;

  const CreateSessionRequestDto({
    required this.tenantId,
    this.sessionId,
    this.reconnect = false,
    this.url,
    this.title,
    this.tz,
    this.navigatorLanguage,
    this.isMobile = false,
    this.domain,
  });

  Map<String, dynamic> toJson() {
    return {
      'tenantId': tenantId,
      'sessionId': ?sessionId,
      'reconnect': reconnect,
      'url': ?url,
      'title': ?title,
      'tz': ?tz,
      'navigatorLanguage': ?navigatorLanguage,
      'isMobile': isMobile,
      'domain': ?domain,
    };
  }

  Map<String, String> toQueryParameters() {
    return {
      'tenantId': tenantId,
      'sessionId': ?sessionId,
      'reconnect': reconnect.toString(),
      'url': ?url,
      'title': ?title,
      'tz': ?tz?.toString(),
      'navigatorLanguage': ?navigatorLanguage,
      'isMobile': isMobile.toString(),
      'domain': ?domain,
    };
  }
}
