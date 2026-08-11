import 'dart:convert';

/// Types of visitor-side activities recognized by the backend.
enum VisitorActivityType {
  message,
  typing,
  pageView,
  forms,
  visitorStatus,
  custom,
}

/// A visitor activity payload forwarded to `/chatscript/visitor/activity`.
///
/// Matches the live web widget body, e.g.:
/// ```json
/// {
///   "activity": {
///     "type": "message",
///     "visitorId": "...",
///     "data": { "message": "...", "agentLanguage": "", "clientSideId": 1, "name": "Visitor ..." },
///     "hidden": false
///   },
///   "tid": "...",
///   "queryFrom": "visitors"
/// }
/// ```
class VisitorActivity {
  final String visitorId;
  final VisitorActivityType type;

  /// Map for messages/typing; list of `{key,value}` items for forms.
  final dynamic data;
  final bool hidden;

  const VisitorActivity({
    required this.visitorId,
    required this.type,
    this.data = const {},
    this.hidden = false,
  });

  String get typeName {
    switch (type) {
      case VisitorActivityType.message:
        return 'message';
      case VisitorActivityType.typing:
        return 'typing';
      case VisitorActivityType.pageView:
        return 'pageView';
      case VisitorActivityType.forms:
        return 'forms';
      case VisitorActivityType.visitorStatus:
        return 'visitorStatus';
      case VisitorActivityType.custom:
        return 'custom';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': typeName,
      'visitorId': visitorId,
      'data': data,
      'hidden': hidden,
    };
  }
}

/// An inbound activity delivered to the visitor via polling or socket.
class IncomingVisitorActivity {
  final String id;
  final String type;

  /// Normalized map; list payloads are stored under `_items`.
  final Map<String, dynamic> data;
  final DateTime? timestamp;
  final String? agentId;
  final String? agentName;
  final String? visitorId;

  const IncomingVisitorActivity({
    required this.id,
    required this.type,
    required this.data,
    this.timestamp,
    this.agentId,
    this.agentName,
    this.visitorId,
  });

  /// TalkTroves `forms` activities use `type: forms` with key/value entries.
  bool get isFormActivity => type.toLowerCase() == 'forms';

  /// Flattened key/value map from forms array or map `data`.
  Map<String, dynamic> get formFieldMap => _normalizeFormData(data);

  String? get displayMessage {
    final value = formFieldMap['displayMessage'] ?? formFieldMap['display_message'];
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static Map<String, dynamic> normalizeActivityData(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List) {
      return {'_items': raw};
    }
    return const {};
  }

  static Map<String, dynamic> _normalizeFormData(Map<String, dynamic> source) {
    final items = source['_items'];
    if (items is List) {
      final map = <String, dynamic>{};
      for (final item in items) {
        if (item is Map) {
          final key = item['key']?.toString();
          if (key == null || key.isEmpty) continue;
          map[key] = item['value'];
        }
      }
      return map;
    }
    return source;
  }

  String? get messageText {
    final raw =
        data['message'] ??
        data['text'] ??
        data['content'] ??
        data['body'] ??
        data['msg'];

    if (raw == null) return null;
    if (raw is String) {
      // Socket sometimes delivers a whole activity JSON as a string.
      // Do not treat status / non-chat payloads as message text.
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = _tryDecodeJsonMap(trimmed);
        if (decoded != null) {
          final nestedType =
              (decoded['type'] ?? decoded['event'] ?? '').toString();
          if (_looksLikeStatusType(nestedType)) return null;
          final nestedData = decoded['data'];
          if (nestedData is Map && nestedData['status'] != null) {
            return null;
          }
          final nestedMsg = nestedData is Map
              ? (nestedData['message'] ??
                  nestedData['text'] ??
                  nestedData['content'] ??
                  nestedData['body'] ??
                  nestedData['msg'])
              : (decoded['message'] ?? decoded['text'] ?? decoded['content']);
          if (nestedMsg != null) return nestedMsg.toString();
          // Encoded activity object without a chat body — not displayable text.
          if (decoded.containsKey('type') && decoded.containsKey('data')) {
            return null;
          }
        }
      }
      return raw;
    }
    if (raw is num || raw is bool) return raw.toString();
    if (raw is Map) {
      final nested = raw['message'] ??
          raw['text'] ??
          raw['content'] ??
          raw['body'] ??
          raw['msg'];
      return nested?.toString();
    }
    return raw.toString();
  }

  bool get isTyping {
    final lower = type.toLowerCase();
    return lower.contains('typing') ||
        data['typing'] == true ||
        data['isTyping'] == true;
  }

  /// System / queue status events (e.g. visitorStatus:incoming) — not chat.
  bool get isStatusEvent {
    if (_looksLikeStatusType(type)) return true;
    if (data.containsKey('status') &&
        !data.containsKey('message') &&
        !data.containsKey('text') &&
        !data.containsKey('content') &&
        !data.containsKey('body') &&
        !data.containsKey('msg')) {
      return true;
    }
    return false;
  }

  bool get isMessage {
    if (isTyping || isStatusEvent || isFormActivity) return false;
    final text = messageText?.trim();
    return text != null && text.isNotEmpty;
  }

  /// True when an agent / bot authored this activity (not the visitor).
  bool get isFromAgent {
    final id = agentId?.trim();
    final name = agentName?.trim();
    final hasAgentId =
        id != null && id.isNotEmpty && id.toLowerCase() != 'null';
    final hasAgentName =
        name != null && name.isNotEmpty && name.toLowerCase() != 'null';
    if (hasAgentId || hasAgentName) return true;

    if (data['isBot'] == true ||
        data['fromBot'] == true ||
        data['isAgent'] == true) {
      return true;
    }

    final lowerType = type.toLowerCase();
    if (lowerType.contains('agent') ||
        lowerType.contains('bot') ||
        lowerType.contains('assistant') ||
        lowerType.contains('chatbot')) {
      return true;
    }

    final from = (data['from'] ??
            data['sender'] ??
            data['source'] ??
            data['role'] ??
            '')
        .toString()
        .toLowerCase();
    return from == 'agent' ||
        from == 'bot' ||
        from == 'assistant' ||
        from == 'chatbot' ||
        from == 'system';
  }

  /// Visitor's own outbound message echoed back by polling/socket.
  bool get isFromVisitor => !isFromAgent && (isMessage || messageText != null);

  static bool _looksLikeStatusType(String type) {
    final lower = type.toLowerCase();
    return lower.contains('status') || lower == 'visitorstatus';
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
