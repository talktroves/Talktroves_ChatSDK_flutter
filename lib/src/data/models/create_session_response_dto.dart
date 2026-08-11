import '../../domain/entities/visitor_session.dart';

/// Response from `POST|GET /chatscript/visitor/session`.
class CreateSessionResponseDto {
  final bool isSuccess;
  final String? tenantId;
  final String? sessionId;
  final Map<String, dynamic>? script;
  final String? errorMessage;

  const CreateSessionResponseDto({
    required this.isSuccess,
    this.tenantId,
    this.sessionId,
    this.script,
    this.errorMessage,
  });

  factory CreateSessionResponseDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final Map<String, dynamic>? dataMap =
        data is Map<String, dynamic> ? data : null;

    return CreateSessionResponseDto(
      isSuccess: json['isSuccess'] == true ||
          json['success'] == true ||
          dataMap != null,
      tenantId: dataMap?['tenantId']?.toString() ?? json['tenantId']?.toString(),
      sessionId:
          dataMap?['sessionId']?.toString() ?? json['sessionId']?.toString(),
      script: dataMap?['script'] is Map<String, dynamic>
          ? dataMap!['script'] as Map<String, dynamic>
          : null,
      errorMessage: json['message']?.toString() ?? json['error']?.toString(),
    );
  }

  VisitorSession toEntity() {
    return VisitorSession(
      tenantId: tenantId ?? '',
      sessionId: sessionId ?? '',
      script: script,
    );
  }
}
