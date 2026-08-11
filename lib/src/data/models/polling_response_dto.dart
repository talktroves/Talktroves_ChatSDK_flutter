import '../../domain/entities/polling_result.dart';
import '../../domain/entities/visitor_activity.dart';

/// Response from `GET /chatscript/visitor/polling`.
class PollingResponseDto {
  final List<IncomingVisitorActivity> activities;
  final String nextTimestamp;

  const PollingResponseDto({
    required this.activities,
    required this.nextTimestamp,
  });

  factory PollingResponseDto.fromJson(
    dynamic json, {
    required String fallbackTimestamp,
  }) {
    if (json is List) {
      return PollingResponseDto(
        activities: json
            .whereType<Map>()
            .map((item) => _parseActivity(Map<String, dynamic>.from(item)))
            .toList(),
        nextTimestamp: fallbackTimestamp,
      );
    }

    if (json is! Map) {
      return PollingResponseDto(
        activities: const [],
        nextTimestamp: fallbackTimestamp,
      );
    }

    final map = Map<String, dynamic>.from(json);
    final data = map['data'];
    final activitiesRaw = data is Map
        ? (data['activities'] ?? data['items'] ?? data['messages'])
        : (map['activities'] ?? map['items'] ?? map['messages'] ?? data);

    final List<IncomingVisitorActivity> activities = [];
    if (activitiesRaw is List) {
      for (final item in activitiesRaw) {
        if (item is Map) {
          activities.add(_parseActivity(Map<String, dynamic>.from(item)));
        }
      }
    }

    final nextTs = _readTimestampCursor(
          map['nextTimestamp'] ??
              map['ts'] ??
              map['timestamp'] ??
              (data is Map
                  ? (data['nextTimestamp'] ?? data['ts'] ?? data['timestamp'])
                  : null),
        ) ??
        fallbackTimestamp;

    return PollingResponseDto(
      activities: activities,
      nextTimestamp: nextTs,
    );
  }

  PollingResult toEntity() {
    return PollingResult(
      activities: activities,
      nextTimestamp: nextTimestamp,
    );
  }

  static IncomingVisitorActivity _parseActivity(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final Map<String, dynamic> data =
        IncomingVisitorActivity.normalizeActivityData(dataRaw);
    if (data.isEmpty) {
      if (json['message'] != null) data['message'] = json['message'];
      if (json['text'] != null) data['text'] = json['text'];
      if (json['content'] != null) data['content'] = json['content'];
    }

    final id = (json['id'] ??
            json['_id'] ??
            json['activityId'] ??
            DateTime.now().microsecondsSinceEpoch)
        .toString();

    final type = (json['type'] ?? json['event'] ?? 'message').toString();

    DateTime? timestamp;
    final tsRaw = json['timestamp'] ?? json['createdAt'] ?? json['ts'];
    if (tsRaw is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(
        tsRaw > 9999999999 ? tsRaw : tsRaw * 1000,
      );
    } else if (tsRaw is String) {
      timestamp = DateTime.tryParse(tsRaw);
    }

    return IncomingVisitorActivity(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      agentId: json['agentId']?.toString(),
      agentName: json['agentName']?.toString(),
      visitorId: json['visitorId']?.toString(),
    );
  }

  /// Preserve server cursor format (ISO string or numeric string).
  static String? _readTimestampCursor(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toInt().toString();
    return value.toString();
  }
}
