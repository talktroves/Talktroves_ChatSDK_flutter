import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/visitor_api_paths.dart';
import '../../core/errors/visitor_exception.dart';
import '../../core/logging/visitor_api_logger.dart';
import '../models/create_session_request_dto.dart';
import '../models/create_session_response_dto.dart';
import '../models/history_response_dto.dart';
import '../models/polling_response_dto.dart';
import '../models/send_activity_request_dto.dart';

/// HTTP data source for the JSON visitor SDK endpoints.
class VisitorRemoteDataSource {
  final String baseUrl;
  final Map<String, String> headers;
  final http.Client _client;

  VisitorRemoteDataSource({
    required this.baseUrl,
    this.headers = const {},
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...headers,
      };

  Future<CreateSessionResponseDto> createSession(
    CreateSessionRequestDto request, {
    bool useGet = false,
  }) async {
    final uri = useGet
        ? _uri(VisitorApiPaths.session, request.toQueryParameters())
        : _uri(VisitorApiPaths.session);
    final method = useGet ? 'GET' : 'POST';
    final requestBody = useGet ? null : request.toJson();

    try {
      VisitorApiLogger.request(method: method, url: uri, body: requestBody);

      final http.Response response;
      if (useGet) {
        response = await _client.get(uri, headers: _jsonHeaders);
      } else {
        response = await _client.post(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode(requestBody),
        );
      }

      VisitorApiLogger.response(
        method: method,
        url: uri,
        statusCode: response.statusCode,
        body: response.body,
      );

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VisitorSessionException(
          'Failed to create visitor session',
          statusCode: response.statusCode,
          cause: body,
        );
      }

      final dto = CreateSessionResponseDto.fromJson(
        body is Map<String, dynamic> ? body : <String, dynamic>{'data': body},
      );

      if (!dto.isSuccess ||
          dto.sessionId == null ||
          dto.sessionId!.isEmpty) {
        throw VisitorSessionException(
          dto.errorMessage ?? 'Session response missing sessionId',
          statusCode: response.statusCode,
        );
      }

      VisitorApiLogger.info(
        'SESSION OK → tenantId=${dto.tenantId} sessionId=${dto.sessionId}',
      );
      return dto;
    } on VisitorException {
      rethrow;
    } catch (e) {
      VisitorApiLogger.error('createSession failed', e);
      throw VisitorSessionException(
        'Failed to create visitor session',
        cause: e,
      );
    }
  }

  Future<void> sendActivity(SendActivityRequestDto request) async {
    final uri = _uri(VisitorApiPaths.activity);
    final requestBody = request.toJson();

    try {
      VisitorApiLogger.request(method: 'POST', url: uri, body: requestBody);

      final response = await _client.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode(requestBody),
      );

      VisitorApiLogger.response(
        method: 'POST',
        url: uri,
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VisitorActivityException(
          'Failed to send visitor activity',
          statusCode: response.statusCode,
          cause: response.body,
        );
      }

      // TalkTroves may return HTTP 200 with isSuccess:false / isServerError:true.
      final decoded = _decodeBody(response.body);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final isSuccess = map['isSuccess'] == true;
        final isServerError = map['isServerError'] == true;
        final explicitFail = map['isSuccess'] == false || isServerError;

        if (explicitFail && !isSuccess) {
          final serverMessage = map['message']?.toString() ??
              (map['serverError'] is Map
                  ? map['serverError']['message']?.toString()
                  : null) ??
              'Activity rejected by server';
          VisitorApiLogger.error('ACTIVITY REJECTED: $serverMessage');
          throw VisitorActivityException(
            serverMessage,
            statusCode: response.statusCode,
            cause: map,
          );
        }
      }

      VisitorApiLogger.info('ACTIVITY SEND OK');
    } on VisitorException {
      rethrow;
    } catch (e) {
      VisitorApiLogger.error('sendActivity failed', e);
      throw VisitorActivityException(
        'Failed to send visitor activity',
        cause: e,
      );
    }
  }

  Future<PollingResponseDto> pollActivities({
    required String tenantId,
    required String sessionId,
    required String timestamp,
  }) async {
    final uri = _uri(VisitorApiPaths.polling, {
      'tid': tenantId,
      'sid': sessionId,
      'ts': timestamp,
    });

    try {
      // Don't spam console on every empty 3s poll unless verbosePolling=true.
      final quietRequest = !VisitorApiLogger.verbosePolling;
      VisitorApiLogger.request(method: 'GET', url: uri, quiet: quietRequest);

      final response = await _client.get(uri, headers: _jsonHeaders);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        VisitorApiLogger.response(
          method: 'GET',
          url: uri,
          statusCode: response.statusCode,
          body: response.body,
        );
        throw VisitorPollingException(
          'Failed to poll visitor activities',
          statusCode: response.statusCode,
          cause: response.body,
        );
      }

      final body = _decodeBody(response.body);
      final dto = PollingResponseDto.fromJson(
        body,
        fallbackTimestamp: timestamp,
      );

      final hasActivities = dto.activities.isNotEmpty;
      if (hasActivities || VisitorApiLogger.verbosePolling) {
        VisitorApiLogger.response(
          method: 'GET',
          url: uri,
          statusCode: response.statusCode,
          body: response.body,
        );
        VisitorApiLogger.info(
          'POLL OK → activities=${dto.activities.length} '
          'nextTs=${dto.nextTimestamp}',
        );
        for (final activity in dto.activities) {
          VisitorApiLogger.info(
            '  • id=${activity.id} type=${activity.type} '
            'agentId=${activity.agentId} agentName=${activity.agentName} '
            'visitorId=${activity.visitorId} text=${activity.messageText} '
            'fromAgent=${activity.isFromAgent}',
          );
        }
      }

      return dto;
    } on VisitorException {
      rethrow;
    } catch (e) {
      VisitorApiLogger.error('pollActivities failed', e);
      throw VisitorPollingException(
        'Failed to poll visitor activities',
        cause: e,
      );
    }
  }

  Future<HistoryResponseDto> fetchTenantHistory({
    required String tenantId,
    int page = 1,
    int count = 20,
    String sortField = 'createdOn',
    String sortValue = 'desc',
    String keyword = '',
    String filter = 'all',
    String? sessionId,
    String? historyBaseUrl,
  }) async {
    final origin = (historyBaseUrl ?? baseUrl).endsWith('/')
        ? (historyBaseUrl ?? baseUrl).substring(
            0,
            (historyBaseUrl ?? baseUrl).length - 1,
          )
        : (historyBaseUrl ?? baseUrl);
    final uri = Uri.parse('$origin${VisitorApiPaths.tenantHistory}').replace(
      queryParameters: {
        'tenantId': tenantId,
        'page': page.toString(),
        'count': count.toString(),
        'sortField': sortField,
        'sortValue': sortValue,
        'keyword': keyword,
        'filter': filter,
      },
    );

    try {
      VisitorApiLogger.request(method: 'GET', url: uri);

      final response = await _client.get(uri, headers: _jsonHeaders);

      VisitorApiLogger.response(
        method: 'GET',
        url: uri,
        statusCode: response.statusCode,
        body: response.body,
      );

      final body = _decodeBody(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VisitorHistoryException(
          'Failed to load chat history',
          statusCode: response.statusCode,
          cause: body,
        );
      }

      if (body is Map &&
          (body['isSuccess'] == false || body['isServerError'] == true)) {
        throw VisitorHistoryException(
          body['message']?.toString() ??
              body['serverError']?.toString() ??
              'Failed to load chat history',
          statusCode: response.statusCode,
          cause: body,
        );
      }

      final dto = HistoryResponseDto.fromJson(
        body,
        page: page,
        sessionId: sessionId,
        keyword: keyword,
      );
      VisitorApiLogger.info(
        'HISTORY OK → activities=${dto.activities.length} page=$page',
      );
      return dto;
    } on VisitorException {
      rethrow;
    } catch (e) {
      VisitorApiLogger.error('fetchTenantHistory failed', e);
      throw VisitorHistoryException(
        'Failed to load chat history',
        cause: e,
      );
    }
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(body);
  }

  void dispose() {
    _client.close();
  }
}
