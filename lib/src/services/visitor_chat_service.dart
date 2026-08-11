import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/visitor_config.dart';
import '../core/logging/visitor_api_logger.dart';
import '../data/datasources/visitor_remote_datasource.dart';
import '../data/datasources/visitor_socket_datasource.dart';
import '../data/repositories/visitor_repository_impl.dart';
import '../domain/entities/visitor_activity.dart';
import '../domain/entities/visitor_session.dart';
import '../domain/repositories/visitor_repository.dart';
import '../models/chat_message.dart';
import '../models/user_data.dart';
import 'chat_service_event.dart';
import 'chatbot_service.dart';
import 'visitor_polling_service.dart';

/// Visitor SDK orchestrator implementing [ChatbotService].
///
/// Flow:
/// 1. Create / reconnect session via `/chatscript/visitor/session`
/// 2. Optionally open Socket.IO with visitor query params
/// 3. Always run polling as fallback / secondary channel
/// 4. Send messages via `/chatscript/visitor/activity`
///
/// Inbound agent messages arrive through [events] (not as `sendMessage` return).
class VisitorChatService extends ChatbotService {
  final VisitorConfig config;
  final VisitorRepository _repository;
  final VisitorRemoteDataSource _remote;
  final VisitorSocketDataSource _socket;
  final VisitorPollingService _polling;
  final bool _ownsRemote;

  final StreamController<ChatServiceEvent> _eventsController =
      StreamController<ChatServiceEvent>.broadcast();

  final Set<String> _seenActivityIds = <String>{};
  final List<String> _pendingOutboundTexts = <String>[];

  VisitorSession? _session;
  StreamSubscription<List<IncomingVisitorActivity>>? _pollSub;
  StreamSubscription<IncomingVisitorActivity>? _socketMessageSub;
  StreamSubscription<bool>? _socketTypingSub;
  StreamSubscription<bool>? _socketConnectionSub;
  StreamSubscription<Object>? _pollErrorSub;
  bool _started = false;

  VisitorChatService._({
    required this.config,
    required this._repository,
    required this._remote,
    required this._socket,
    required this._polling,
    required this._ownsRemote,
  });

  /// Preferred constructor — builds a shared HTTP + repository graph.
  factory VisitorChatService(VisitorConfig config) {
    final remote = VisitorRemoteDataSource(
      baseUrl: config.normalizedBaseUrl,
      headers: config.headers,
    );
    final repository = VisitorRepositoryImpl(remote);
    return VisitorChatService._(
      config: config,
      remote: remote,
      repository: repository,
      socket: VisitorSocketDataSource(),
      polling: VisitorPollingService(
        repository: repository,
        interval: config.pollingInterval,
      ),
      ownsRemote: true,
    );
  }

  /// For tests or advanced DI.
  factory VisitorChatService.forTesting({
    required VisitorConfig config,
    required VisitorRepository repository,
    required VisitorRemoteDataSource remote,
    VisitorSocketDataSource? socket,
    VisitorPollingService? polling,
  }) {
    return VisitorChatService._(
      config: config,
      repository: repository,
      remote: remote,
      socket: socket ?? VisitorSocketDataSource(),
      polling:
          polling ??
          VisitorPollingService(
            repository: repository,
            interval: config.pollingInterval,
          ),
      ownsRemote: false,
    );
  }

  VisitorSession? get session => _session;

  @override
  bool get usesRealtimeDelivery => true;

  @override
  Stream<ChatServiceEvent> get events => _eventsController.stream;

  @override
  Future<void> start() async {
    if (_started && _session != null) return;
    _started = true;

    try {
      // Step 1 — create session against tenantId (dummy or real).
      // Do not invent sessionId; server returns it.
      final session = await _repository.createSession(
        tenantId: config.tenantId,
        sessionId: config.sessionId,
        reconnect: config.reconnect,
        url: config.url,
        title: config.title,
        tz: config.tz,
        navigatorLanguage: config.navigatorLanguage,
        isMobile: config.isMobile,
        domain: config.domain,
      );
      _session = session;

      _emit(
        SessionReadyEvent(
          tenantId: session.tenantId,
          sessionId: session.sessionId,
        ),
      );

      if (kDebugMode) {
        debugPrint(
          '[VisitorChatService] Step 1 OK — session created\n'
          '  tenantId  = ${session.tenantId}\n'
          '  sessionId = ${session.sessionId}  ← use this for chat\n'
          '  visitorId = ${session.sessionId}\n'
          '  connectionId = ${session.sessionId}',
        );
      }

      // Step 2 — poll + socket against that sessionId.
      _attachPolling(session);
      if (config.enableSocket) {
        _attachSocket(session);
      }
    } catch (e, st) {
      _started = false;
      _emit(ChatServiceErrorEvent('Failed to create visitor session', cause: e));
      if (kDebugMode) {
        debugPrint('[VisitorChatService] session create failed: $e\n$st');
      }
      rethrow;
    }
  }

  void _attachPolling(VisitorSession session) {
    _pollSub?.cancel();
    _pollErrorSub?.cancel();

    _polling.start(tenantId: session.tenantId, sessionId: session.sessionId);

    _pollSub = _polling.activities.listen(_handleIncomingActivities);
    _pollErrorSub = _polling.errors.listen((error) {
      _emit(ChatServiceErrorEvent('Polling failed', cause: error));
    });
  }

  void _attachSocket(VisitorSession session) {
    _socketMessageSub?.cancel();
    _socketTypingSub?.cancel();
    _socketConnectionSub?.cancel();

    _socket.connect(
      baseUrl: config.normalizedBaseUrl,
      tenantId: session.tenantId,
      sessionId: session.sessionId,
      socketPath: config.socketPath,
    );

    _socketMessageSub = _socket.messages.listen((activity) {
      _handleIncomingActivities([activity]);
    });
    _socketTypingSub = _socket.typing.listen((isTyping) {
      _emit(TypingEvent(isTyping));
    });
    _socketConnectionSub = _socket.connection.listen((online) {
      _emit(ConnectionStatusEvent(online));
    });
  }

  void _handleIncomingActivities(List<IncomingVisitorActivity> activities) {
    for (final activity in activities) {
      if (_seenActivityIds.contains(activity.id)) {
        VisitorApiLogger.info(
          'SKIP duplicate activity id=${activity.id}',
        );
        continue;
      }
      _seenActivityIds.add(activity.id);

      VisitorApiLogger.info(
        'INBOUND activity id=${activity.id} type=${activity.type} '
        'agentId=${activity.agentId} agentName=${activity.agentName} '
        'visitorId=${activity.visitorId} text=${activity.messageText} '
        'fromAgent=${activity.isFromAgent} isMessage=${activity.isMessage}',
      );

      if (activity.isTyping) {
        if (activity.isFromAgent) {
          VisitorApiLogger.info('UI ← agent typing');
          _emit(const TypingEvent(true));
        } else {
          VisitorApiLogger.info('SKIP typing (not from agent)');
        }
        continue;
      }

      if (activity.isStatusEvent) {
        VisitorApiLogger.info(
          'SKIP status event type=${activity.type} '
          'status=${activity.data['status']}',
        );
        continue;
      }

      if (activity.isFormActivity) {
        final notice = activity.displayMessage;
        if (notice != null && notice.isNotEmpty) {
          VisitorApiLogger.info('UI ← show form notice: "$notice"');
          _emit(
            FormNoticeEvent(
              ChatMessage.infoNotice(notice).copyWith(
                id: activity.id,
                timestamp: activity.timestamp ?? DateTime.now(),
              ),
            ),
          );
        } else {
          VisitorApiLogger.info(
            'SKIP forms activity without displayMessage id=${activity.id}',
          );
        }
        continue;
      }

      if (!_shouldDisplayAsInboundMessage(activity)) {
        VisitorApiLogger.warn(
          'SKIP show in UI (echo/filter) text=${activity.messageText}',
        );
        continue;
      }

      final text = activity.messageText?.trim();
      if (text == null || text.isEmpty) {
        VisitorApiLogger.warn('SKIP empty message text id=${activity.id}');
        continue;
      }

      VisitorApiLogger.info('UI ← show assistant message: "$text"');
      _emit(const TypingEvent(false));
      _emit(
        IncomingMessageEvent(
          ChatMessage.assistant(text).copyWith(
            id: activity.id,
            timestamp: activity.timestamp ?? DateTime.now(),
          ),
        ),
      );
    }
  }

  /// Shows agent/bot messages; skips the visitor's own echoed outbound texts.
  bool _shouldDisplayAsInboundMessage(IncomingVisitorActivity activity) {
    if (activity.isStatusEvent || activity.isTyping) return false;
    final text = activity.messageText?.trim();
    if (text == null || text.isEmpty) return false;
    if (!activity.isMessage && !activity.isFromAgent) return false;

    // Explicit agent / bot authorship → always show.
    if (activity.isFromAgent) return true;

    // TalkTroves echoes visitor messages with agentId=null.
    // Drop those by matching recently sent texts (not by agentId alone,
    // because some bots also reply with agentId=null).
    final outboundIndex = _pendingOutboundTexts.indexOf(text);
    if (outboundIndex != -1) {
      _pendingOutboundTexts.removeAt(outboundIndex);
      return false;
    }

    // Inbound message that we did not just send — treat as bot/agent reply.
    return true;
  }

  @override
  Future<String?> sendMessage({
    required String content,
    required List<ChatMessage> history,
    required SupportUserData? userData,
    String? deviceId,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError(
        'Visitor session not ready. Call start() first '
        '(POST /chatscript/visitor/session).',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[VisitorChatService] Step 2 — send activity\n'
        '  tid=${session.tenantId}\n'
        '  visitorId=${session.sessionId}\n'
        '  message=$content',
      );
    }

    final trimmed = content.trim();
    if (trimmed.isNotEmpty) {
      _pendingOutboundTexts.add(trimmed);
      if (_pendingOutboundTexts.length > 50) {
        _pendingOutboundTexts.removeAt(0);
      }
    }

    final visitorName = userData?.name?.trim().isNotEmpty == true
        ? userData!.name!.trim()
        : 'Visitor ${DateTime.now().millisecondsSinceEpoch}';
    final clientSideId = DateTime.now().millisecondsSinceEpoch;

    // Live widget shape from TalkTroves desktop/web client.
    final activity = VisitorActivity(
      visitorId: session.sessionId,
      type: VisitorActivityType.message,
      hidden: false,
      data: {
        'message': content,
        'agentLanguage': '',
        'clientSideId': clientSideId,
        'name': visitorName,
      },
    );

    await _repository.sendActivity(
      tenantId: session.tenantId,
      activity: activity,
    );

    if (_socket.isConnected) {
      _socket.emitNewMessage({
        'visitorId': session.sessionId,
        'message': content,
        'name': visitorName,
        'clientSideId': clientSideId,
      });
    }

    // Reply arrives asynchronously via [events].
    return null;
  }

  @override
  Future<void> updateVisitorInfo({
    required String name,
    required String email,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError(
        'Visitor session not ready. Call start() first '
        '(POST /chatscript/visitor/session).',
      );
    }

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    if (trimmedName.isEmpty && trimmedEmail.isEmpty) {
      throw ArgumentError('Name or email must be provided.');
    }

    if (kDebugMode) {
      debugPrint(
        '[VisitorChatService] update visitor info\n'
        '  tid=${session.tenantId}\n'
        '  visitorId=${session.sessionId}\n'
        '  name=$trimmedName\n'
        '  email=$trimmedEmail',
      );
    }

    // TalkTroves emits separate forms activities per field changed.
    if (trimmedName.isNotEmpty) {
      await _sendFormField(session: session, key: 'name', value: trimmedName);
    }
    if (trimmedEmail.isNotEmpty) {
      await _sendFormField(session: session, key: 'email', value: trimmedEmail);
    }
  }

  Future<void> _sendFormField({
    required VisitorSession session,
    required String key,
    required String value,
  }) async {
    final activity = VisitorActivity(
      visitorId: session.sessionId,
      type: VisitorActivityType.forms,
      hidden: false,
      data: [
        {'key': key, 'value': value},
      ],
    );

    await _repository.sendActivity(
      tenantId: session.tenantId,
      activity: activity,
    );
  }

  /// Sends a typing activity to the backend / socket.
  Future<void> sendTyping(bool isTyping) async {
    final session = _session;
    if (session == null) return;

    if (_socket.isConnected) {
      _socket.emitTyping(isTyping: isTyping);
    }

    await _repository.sendActivity(
      tenantId: session.tenantId,
      activity: VisitorActivity(
        visitorId: session.sessionId,
        type: VisitorActivityType.typing,
        hidden: false,
        data: {
          'typing': isTyping,
          'agentLanguage': '',
          'clientSideId': DateTime.now().millisecondsSinceEpoch,
          'name': 'Visitor',
        },
      ),
    );
  }

  void _emit(ChatServiceEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  @override
  Future<void> logout() async {
    final session = _session;
    if (session != null) {
      try {
        await _repository.sendActivity(
          tenantId: session.tenantId,
          activity: VisitorActivity(
            visitorId: session.sessionId,
            type: VisitorActivityType.visitorStatus,
            hidden: false,
            data: const {'status': 'ended'},
          ),
        );
        VisitorApiLogger.info(
          'SESSION EXPIRED → visitorId=${session.sessionId}',
        );
      } catch (e) {
        VisitorApiLogger.error('expire session activity failed', e);
      }
    }

    await stop();

    _session = null;
    _seenActivityIds.clear();
    _pendingOutboundTexts.clear();
    _emit(const SessionEndedEvent());
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _pollSub?.cancel();
    await _pollErrorSub?.cancel();
    await _socketMessageSub?.cancel();
    await _socketTypingSub?.cancel();
    await _socketConnectionSub?.cancel();
    _pollSub = null;
    _pollErrorSub = null;
    _socketMessageSub = null;
    _socketTypingSub = null;
    _socketConnectionSub = null;

    _polling.stop();
    _socket.disconnect();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _polling.dispose();
    await _socket.dispose();
    if (_ownsRemote) {
      _remote.dispose();
    }
    await _eventsController.close();
  }
}
