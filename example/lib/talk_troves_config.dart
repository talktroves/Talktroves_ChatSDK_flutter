/// TalkTroves JSON Visitor SDK demo config.
///
/// Flow:
/// 1. Use [tenantId] from widget / backend
/// 2. POST /chatscript/visitor/session  → server returns `sessionId`
/// 3. Chat with that `sessionId` as visitorId / connectionId / sid
abstract final class TalkTrovesConfig {
  /// Backend origin (no trailing slash).
  static const String baseUrl = 'https://App.talktroves.com';

  /// Real tenant id from working web widget (`tid`).
  static const String tenantId = '6a4ebd2deb5fb50e9862d253';

  static const String domain = 'App.talktroves.com';
  static const String pageUrl = 'https://App.talktroves.com';
  static const String pageTitle = 'Support Chat Demo';

  static const bool enableSocket = true;
  static const Duration pollingInterval = Duration(seconds: 3);
  static const int timezoneOffsetHours = 5;
  static const String navigatorLanguage = 'en-US';
}
