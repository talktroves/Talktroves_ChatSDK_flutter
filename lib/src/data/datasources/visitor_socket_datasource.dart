import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/logging/visitor_api_logger.dart';
import '../../domain/entities/visitor_activity.dart';

/// Socket.IO client for realtime visitor events.
///
/// Query parameters required by the backend:
/// `tenantId`, `connectionId`, `visitorId`, `type=visitors`
class VisitorSocketDataSource {
  io.Socket? _socket;
  final _messageController =
      StreamController<IncomingVisitorActivity>.broadcast();
  final _typingController = StreamController<bool>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<IncomingVisitorActivity> get messages => _messageController.stream;
  Stream<bool> get typing => _typingController.stream;
  Stream<bool> get connection => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String baseUrl,
    required String tenantId,
    required String sessionId,
    String? socketPath,
    Map<String, dynamic>? extraQuery,
  }) {
    disconnect();

    final query = {
      'tenantId': tenantId,
      'connectionId': sessionId,
      'visitorId': sessionId,
      'type': 'visitors',
      ...?extraQuery,
    };

    VisitorApiLogger.info(
      'SOCKET connect → $baseUrl query=$query path=${socketPath ?? 'default'}',
    );

    final optionBuilder = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableForceNew()
        .enableReconnection()
        .setQuery(query);

    if (socketPath != null && socketPath.isNotEmpty) {
      optionBuilder.setPath(socketPath);
    }

    _socket = io.io(baseUrl, optionBuilder.build());

    _socket!
      ..onConnect((_) {
        VisitorApiLogger.info('SOCKET connected');
        if (!_connectionController.isClosed) {
          _connectionController.add(true);
        }
      })
      ..onDisconnect((reason) {
        VisitorApiLogger.warn('SOCKET disconnected: $reason');
        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
      })
      ..onConnectError((error) {
        VisitorApiLogger.error('SOCKET connect error', error);
        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
      })
      ..on('message_to_client', (data) {
        VisitorApiLogger.info('SOCKET event message_to_client → $data');
        _handleIncomingMessage(data);
      })
      ..on('message-to-client', (data) {
        VisitorApiLogger.info('SOCKET event message-to-client → $data');
        _handleIncomingMessage(data);
      })
      ..on('new message', (data) {
        VisitorApiLogger.info('SOCKET event new message → $data');
        _handleIncomingMessage(data);
      })
      ..on('message', (data) {
        VisitorApiLogger.info('SOCKET event message → $data');
        _handleIncomingMessage(data);
      })
      ..on('message-typing', (data) {
        VisitorApiLogger.info('SOCKET event message-typing → $data');
        if (!_typingController.isClosed) {
          _typingController.add(true);
        }
      })
      ..on('typing', (raw) {
        VisitorApiLogger.info('SOCKET event typing → $raw');
        final typing = raw is Map
            ? (raw['typing'] == true || raw['isTyping'] == true)
            : raw == true;
        if (!_typingController.isClosed) {
          _typingController.add(typing);
        }
      });

    if (kDebugMode) {
      _socket!.onAny((event, data) {
        // Skip events already logged above to reduce noise a bit is hard;
        // log unknown ones only.
        const known = {
          'message_to_client',
          'message-to-client',
          'new message',
          'message',
          'message-typing',
          'typing',
          'connect',
          'disconnect',
          'connect_error',
        };
        if (!known.contains(event)) {
          VisitorApiLogger.info('SOCKET other event "$event" → $data');
        }
      });
    }
  }

  void emitTyping({required bool isTyping}) {
    VisitorApiLogger.info('SOCKET emit typing → $isTyping');
    _socket?.emit('typing', {'typing': isTyping});
  }

  void emitNewMessage(Map<String, dynamic> payload) {
    VisitorApiLogger.info('SOCKET emit new message → $payload');
    _socket?.emit('new message', payload);
  }

  void _handleIncomingMessage(dynamic raw) {
    if (_messageController.isClosed) return;

    if (raw is List) {
      for (final item in raw) {
        _handleIncomingMessage(item);
      }
      return;
    }

    Map<String, dynamic> map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final trimmed = raw.trim();
      // Backend often emits the activity object as a JSON string.
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            map = Map<String, dynamic>.from(decoded);
          } else {
            map = {'message': raw, 'type': 'message'};
          }
        } catch (_) {
          map = {'message': raw, 'type': 'message'};
        }
      } else {
        map = {'message': raw, 'type': 'message'};
      }
    } else {
      VisitorApiLogger.warn('SOCKET ignored non-map payload: $raw');
      return;
    }

    final nestedActivity = map['activity'];
    if (nestedActivity is Map &&
        map['data'] == null &&
        map['message'] == null) {
      map = {
        ...map,
        ...Map<String, dynamic>.from(nestedActivity),
      };
    }

    final dataRaw = map['data'];
    final data = IncomingVisitorActivity.normalizeActivityData(dataRaw);
    if (data.isEmpty) {
      if (map['message'] != null) data['message'] = map['message'];
      if (map['text'] != null) data['text'] = map['text'];
      if (map['content'] != null) data['content'] = map['content'];
      if (map['body'] != null) data['body'] = map['body'];
      if (map['msg'] != null) data['msg'] = map['msg'];
    }

    final activity = IncomingVisitorActivity(
      id: (map['id'] ??
              map['_id'] ??
              DateTime.now().microsecondsSinceEpoch)
          .toString(),
      type: (map['type'] ?? 'message').toString(),
      data: data.isEmpty && map['message'] != null
          ? {'message': map['message']}
          : data,
      timestamp: DateTime.now(),
      agentId: map['agentId']?.toString(),
      agentName: map['agentName']?.toString(),
      visitorId: map['visitorId']?.toString(),
    );

    VisitorApiLogger.info(
      'SOCKET parsed → id=${activity.id} type=${activity.type} '
      'text=${activity.messageText} agentId=${activity.agentId} '
      'fromAgent=${activity.isFromAgent}',
    );

    _messageController.add(activity);
    if (!_typingController.isClosed) {
      _typingController.add(false);
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  Future<void> dispose() async {
    disconnect();
    await _messageController.close();
    await _typingController.close();
    await _connectionController.close();
  }
}
