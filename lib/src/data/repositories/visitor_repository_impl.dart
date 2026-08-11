import '../../domain/entities/polling_result.dart';
import '../../domain/entities/visitor_activity.dart';
import '../../domain/entities/visitor_session.dart';
import '../../domain/repositories/visitor_repository.dart';
import '../datasources/visitor_remote_datasource.dart';
import '../models/create_session_request_dto.dart';
import '../models/send_activity_request_dto.dart';

/// Concrete [VisitorRepository] backed by HTTP visitor endpoints.
class VisitorRepositoryImpl implements VisitorRepository {
  final VisitorRemoteDataSource _remote;

  VisitorRepositoryImpl(this._remote);

  @override
  Future<VisitorSession> createSession({
    required String tenantId,
    String? sessionId,
    bool reconnect = false,
    String? url,
    String? title,
    int? tz,
    String? navigatorLanguage,
    bool isMobile = false,
    String? domain,
  }) async {
    final request = CreateSessionRequestDto(
      tenantId: tenantId,
      sessionId: sessionId,
      reconnect: reconnect,
      url: url,
      title: title,
      tz: tz,
      navigatorLanguage: navigatorLanguage,
      isMobile: isMobile,
      domain: domain,
    );

    final response = await _remote.createSession(request);
    final session = response.toEntity();
    return VisitorSession(
      tenantId: session.tenantId.isEmpty ? tenantId : session.tenantId,
      sessionId: session.sessionId,
      script: session.script,
    );
  }

  @override
  Future<void> sendActivity({
    required String tenantId,
    required VisitorActivity activity,
    String queryFrom = 'visitors',
  }) {
    return _remote.sendActivity(
      SendActivityRequestDto(
        tid: tenantId,
        activity: activity,
        queryFrom: queryFrom,
      ),
    );
  }

  @override
  Future<PollingResult> pollActivities({
    required String tenantId,
    required String sessionId,
    required String timestamp,
  }) async {
    final response = await _remote.pollActivities(
      tenantId: tenantId,
      sessionId: sessionId,
      timestamp: timestamp,
    );
    return response.toEntity();
  }
}
