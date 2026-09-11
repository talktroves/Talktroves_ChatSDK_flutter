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
            .map(
              (item) => IncomingVisitorActivity.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
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
          activities.add(
            IncomingVisitorActivity.fromJson(Map<String, dynamic>.from(item)),
          );
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

  /// Preserve server cursor format (ISO string or numeric string).
  static String? _readTimestampCursor(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toInt().toString();
    return value.toString();
  }
}
