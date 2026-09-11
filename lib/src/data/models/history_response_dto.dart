import '../../domain/entities/chat_history.dart';
import '../../domain/entities/visitor_activity.dart';

/// Response from `GET /api/tenant/history`.
class HistoryResponseDto {
  final List<IncomingVisitorActivity> activities;
  final int page;
  final int? totalCount;

  const HistoryResponseDto({
    required this.activities,
    this.page = 1,
    this.totalCount,
  });

  factory HistoryResponseDto.fromJson(
    dynamic json, {
    int page = 1,
    String? sessionId,
    String? keyword,
  }) {
    final rows = _extractRows(json);
    final matched = _filterRows(
      rows,
      sessionId: sessionId,
      keyword: keyword,
    );

    final activities = <IncomingVisitorActivity>[];
    for (final row in matched) {
      activities.addAll(_activitiesFromRow(row));
    }

    return HistoryResponseDto(
      activities: activities,
      page: page,
      totalCount: _readTotalCount(json, rows.length),
    );
  }

  ChatHistoryResult toEntity() {
    return ChatHistoryResult(
      activities: activities,
      page: page,
      totalCount: totalCount,
    );
  }

  static List<Map<String, dynamic>> _extractRows(dynamic json) {
    final rawList = _findList(json);
    return [
      for (final item in rawList)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static List<dynamic> _findList(dynamic json) {
    if (json is List) return json;
    if (json is! Map) return const [];

    final map = Map<String, dynamic>.from(json);
    final data = map['data'];

    for (final candidate in [
      map['data'],
      map['items'],
      map['history'],
      map['chats'],
      map['conversations'],
      map['messages'],
      map['records'],
    ]) {
      if (candidate is List) return candidate;
    }

    if (data is Map) {
      for (final key in [
        'data',
        'items',
        'history',
        'chats',
        'conversations',
        'messages',
        'records',
        'pastChats',
      ]) {
        final nested = data[key];
        if (nested is List) return nested;
      }
    }

    return const [];
  }

  static int? _readTotalCount(dynamic json, int fallback) {
    if (json is! Map) return fallback;
    final map = Map<String, dynamic>.from(json);
    final data = map['data'];
    final raw = map['recordsTotal'] ??
        map['total'] ??
        map['count'] ??
        (data is Map
            ? (data['recordsTotal'] ?? data['total'] ?? data['count'])
            : null);
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return fallback;
  }

  static List<Map<String, dynamic>> _filterRows(
    List<Map<String, dynamic>> rows, {
    String? sessionId,
    String? keyword,
  }) {
    if (rows.isEmpty) return rows;

    final sid = sessionId?.trim();
    final key = keyword?.trim();
    final hasIdentity = rows.any(_hasVisitorIdentity);

    bool matches(Map<String, dynamic> row) {
      if (sid != null &&
          sid.isNotEmpty &&
          _identityValues(row).contains(sid.toLowerCase())) {
        return true;
      }
      if (key != null && key.isNotEmpty) {
        final lower = key.toLowerCase();
        if (_identityValues(row).contains(lower)) return true;
        return _rowText(row).toLowerCase().contains(lower);
      }
      return false;
    }

    final matched = rows.where(matches).toList();
    if (matched.isNotEmpty) return matched;

    // Server already filtered by keyword, or rows have no visitor identity.
    if ((key != null && key.isNotEmpty) || !hasIdentity) {
      return rows;
    }
    return const [];
  }

  static bool _hasVisitorIdentity(Map<String, dynamic> row) {
    return _readIdentity(row, const [
          'visitorId',
          'visitor_id',
          'sessionId',
          'sid',
          'email',
          'visitorEmail',
          'userEmail',
        ]) !=
        null;
  }

  static Set<String> _identityValues(Map<String, dynamic> row) {
    final values = <String>{};
    for (final key in [
      'visitorId',
      'visitor_id',
      'sessionId',
      'sid',
      'connectionId',
      'email',
      'visitorEmail',
      'userEmail',
      'name',
      'visitorName',
      'userName',
    ]) {
      final value = _readIdentity(row, [key]);
      if (value != null) values.add(value);
    }
    return values;
  }

  static String? _readIdentity(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key] ?? (row['visitor'] is Map ? row['visitor'][key] : null);
      final text = value?.toString().trim().toLowerCase();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  static String _rowText(Map<String, dynamic> row) {
    return [
      row['email'],
      row['visitorEmail'],
      row['name'],
      row['visitorName'],
      row['lastMessage'],
      row['message'],
    ].where((value) => value != null).join(' ');
  }

  static List<IncomingVisitorActivity> _activitiesFromRow(
    Map<String, dynamic> row,
  ) {
    for (final key in [
      'messages',
      'activities',
      'chats',
      'history',
      'chatHistory',
    ]) {
      final nested = row[key];
      if (nested is List && nested.isNotEmpty) {
        return [
          for (final item in nested)
            if (item is Map)
              IncomingVisitorActivity.fromJson(
                _withParentIdentity(Map<String, dynamic>.from(item), row),
              ),
        ];
      }
    }

    return [IncomingVisitorActivity.fromJson(row)];
  }

  static Map<String, dynamic> _withParentIdentity(
    Map<String, dynamic> item,
    Map<String, dynamic> parent,
  ) {
    item['visitorId'] ??=
        parent['visitorId'] ?? parent['visitor_id'] ?? parent['sessionId'];
    item['agentId'] ??= parent['agentId'];
    item['agentName'] ??= parent['agentName'];
    return item;
  }
}
