import '../../domain/entities/visitor_activity.dart';

/// Request body for `POST /chatscript/visitor/activity`.
class SendActivityRequestDto {
  final String tid;
  final VisitorActivity activity;
  final String queryFrom;

  const SendActivityRequestDto({
    required this.tid,
    required this.activity,
    this.queryFrom = 'visitors',
  });

  Map<String, dynamic> toJson() {
    // Field order matches the working web/desktop widget payload.
    return {
      'activity': activity.toJson(),
      'tid': tid,
      'queryFrom': queryFrom,
    };
  }
}
