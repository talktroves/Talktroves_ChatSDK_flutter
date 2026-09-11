import 'package:flutter_test/flutter_test.dart';
import 'package:talktroves_chatsdk/src/data/models/create_session_request_dto.dart';
import 'package:talktroves_chatsdk/src/data/models/create_session_response_dto.dart';
import 'package:talktroves_chatsdk/src/data/models/history_response_dto.dart';
import 'package:talktroves_chatsdk/src/data/models/polling_response_dto.dart';
import 'package:talktroves_chatsdk/src/domain/entities/visitor_activity.dart';
import 'package:talktroves_chatsdk/src/models/chat_message.dart';

void main() {
  group('CreateSessionRequestDto', () {
    test('serializes JSON payload for session create', () {
      const dto = CreateSessionRequestDto(
        tenantId: 'tenant-1',
        sessionId: 'sid-1',
        reconnect: true,
        url: 'https://example.com',
        title: 'Home',
        tz: 5,
        navigatorLanguage: 'en-US',
        isMobile: true,
        domain: 'example.com',
      );

      expect(dto.toJson(), {
        'tenantId': 'tenant-1',
        'sessionId': 'sid-1',
        'reconnect': true,
        'url': 'https://example.com',
        'title': 'Home',
        'tz': 5,
        'navigatorLanguage': 'en-US',
        'isMobile': true,
        'domain': 'example.com',
      });
    });
  });

  group('CreateSessionResponseDto', () {
    test('parses success envelope', () {
      final dto = CreateSessionResponseDto.fromJson({
        'isSuccess': true,
        'data': {
          'tenantId': 'tenant-1',
          'sessionId': 'visitor-session-id',
          'script': {'foo': 'bar'},
        },
      });

      expect(dto.isSuccess, isTrue);
      expect(dto.sessionId, 'visitor-session-id');
      expect(dto.toEntity().sessionId, 'visitor-session-id');
    });
  });

  group('PollingResponseDto', () {
    test('parses activities and next timestamp', () {
      final dto = PollingResponseDto.fromJson({
        'data': {
          'activities': [
            {
              'id': 'a1',
              'type': 'message',
              'agentId': 'agent-1',
              'agentName': 'Bot',
              'data': {'message': 'Hello from agent'},
            },
            {
              'id': 'a2',
              'type': 'message',
              'agentId': null,
              'visitorId': 'sid-1',
              'data': {'message': 'Hello echo from visitor'},
            },
          ],
          'timestamp': '2026-07-15T13:05:15.564Z',
        },
      }, fallbackTimestamp: '0');

      expect(dto.activities, hasLength(2));
      expect(dto.activities.first.isFromAgent, isTrue);
      expect(dto.activities.last.isFromVisitor, isTrue);
      expect(dto.activities.first.messageText, 'Hello from agent');
      expect(dto.nextTimestamp, '2026-07-15T13:05:15.564Z');
    });
  });

  group('IncomingVisitorActivity', () {
    test('treats visitorStatus as a status event, not a chat message', () {
      const activity = IncomingVisitorActivity(
        id: '6a579cc68111b29d0f8c0dcd',
        type: 'visitorStatus',
        data: {'status': 'incoming'},
        agentId: null,
        agentName: null,
        visitorId: 'wzBPKR7slsABa048Ma7Z',
      );

      expect(activity.isStatusEvent, isTrue);
      expect(activity.isMessage, isFalse);
      expect(activity.messageText, isNull);
    });

    test('does not treat stringified visitorStatus JSON as message text', () {
      const statusJson =
          '{"type":"visitorStatus","forAgentsOnly":false,'
          '"data":{"status":"incoming"},"hidden":false,'
          '"id":"6a579cc68111b29d0f8c0dcd"}';

      const activity = IncomingVisitorActivity(
        id: 'misparsed',
        type: 'message',
        data: {'message': statusJson},
      );

      expect(activity.messageText, isNull);
      expect(activity.isMessage, isFalse);
    });

    test('still extracts real chat text from stringified message JSON', () {
      const messageJson =
          '{"type":"message","data":{"message":"Hello from agent"},'
          '"agentId":"a1"}';

      const activity = IncomingVisitorActivity(
        id: 'ok',
        type: 'message',
        data: {'message': messageJson},
      );

      expect(activity.messageText, 'Hello from agent');
      expect(activity.isMessage, isTrue);
    });

    test('parses forms activity displayMessage from key/value array', () {
      final activity = IncomingVisitorActivity(
        id: '6a587ddf889bd40012d6bdbe',
        type: 'forms',
        data: IncomingVisitorActivity.normalizeActivityData([
          {
            'key': 'displayMessage',
            'value':
                'Visitor ffjok2avlRpISTz1tkEU has changed their name to test.',
          },
          {'key': 'agentId', 'value': null},
          {'key': 'name', 'value': 'test'},
        ]),
      );

      expect(activity.isFormActivity, isTrue);
      expect(activity.isMessage, isFalse);
      expect(
        activity.displayMessage,
        'Visitor ffjok2avlRpISTz1tkEU has changed their name to test.',
      );
      expect(activity.formFieldMap['name'], 'test');
    });

    test('PollingResponseDto parses forms activities from polling envelope', () {
      final dto = PollingResponseDto.fromJson({
        'data': {
          'activities': [
            {
              'id': 'form-email',
              'type': 'forms',
              'data': [
                {
                  'key': 'displayMessage',
                  'value':
                      'Visitor ffjok2avlRpISTz1tkEU has changed their email to imran@example.com.',
                },
                {'key': 'email', 'value': 'imran@example.com'},
              ],
            },
          ],
        },
      }, fallbackTimestamp: '0');

      expect(dto.activities, hasLength(1));
      expect(dto.activities.first.isFormActivity, isTrue);
      expect(
        dto.activities.first.displayMessage,
        contains('changed their email'),
      );
    });
  });

  group('VisitorActivity forms payload', () {
    test('serializes forms activity with key/value list data', () {
      const activity = VisitorActivity(
        visitorId: 'ffjok2avlRpISTz1tkEU',
        type: VisitorActivityType.forms,
        hidden: false,
        data: [
          {'key': 'name', 'value': 'test'},
        ],
      );

      expect(activity.toJson(), {
        'type': 'forms',
        'visitorId': 'ffjok2avlRpISTz1tkEU',
        'data': [
          {'key': 'name', 'value': 'test'},
        ],
        'hidden': false,
      });
    });

    test('serializes visitorStatus ended activity for logout', () {
      const activity = VisitorActivity(
        visitorId: 'ffjok2avlRpISTz1tkEU',
        type: VisitorActivityType.visitorStatus,
        hidden: false,
        data: {'status': 'ended'},
      );

      expect(activity.toJson(), {
        'type': 'visitorStatus',
        'visitorId': 'ffjok2avlRpISTz1tkEU',
        'data': {'status': 'ended'},
        'hidden': false,
      });
    });
  });

  group('HistoryResponseDto', () {
    test('parses nested conversation activities in chronological order', () {
      final dto = HistoryResponseDto.fromJson({
        'isSuccess': true,
        'data': {
          'data': [
            {
              '_id': 'conv1',
              'visitorId': 'sid-1',
              'email': 'flutter-dummy@example.com',
              'createdOn': '2026-09-01T10:00:00.000Z',
              'activities': [
                {
                  'id': 'm2',
                  'type': 'message',
                  'agentId': 'agent-1',
                  'agentName': 'Bot',
                  'createdOn': '2026-09-01T10:00:05.000Z',
                  'data': {'message': 'Your order is on the way.'},
                },
                {
                  'id': 'm1',
                  'type': 'message',
                  'visitorId': 'sid-1',
                  'createdOn': '2026-09-01T10:00:01.000Z',
                  'data': {'message': 'Where is my order?'},
                },
              ],
            },
          ],
          'recordsTotal': 1,
        },
      }, sessionId: 'sid-1');

      expect(dto.activities, hasLength(2));
      final messages = dto.toEntity().toChatMessages();
      expect(messages, hasLength(2));
      expect(messages.first.content, 'Where is my order?');
      expect(messages.first.sender, MessageSender.user);
      expect(messages.last.content, 'Your order is on the way.');
      expect(messages.last.sender, MessageSender.assistant);
    });

    test('keeps only conversations matching visitor email keyword', () {
      final dto = HistoryResponseDto.fromJson({
        'data': [
          {
            'visitorId': 'other-visitor',
            'email': 'someone@example.com',
            'messages': [
              {
                'id': 'skip',
                'type': 'message',
                'createdOn': '2026-09-01T10:00:00.000Z',
                'data': {'message': 'Other visitor'},
              },
            ],
          },
          {
            'visitorId': 'sid-9',
            'email': 'flutter-dummy@example.com',
            'messages': [
              {
                'id': 'keep',
                'type': 'message',
                'agentId': 'bot',
                'createdOn': '2026-09-01T11:00:00.000Z',
                'data': {'message': 'Welcome back'},
              },
            ],
          },
        ],
      }, keyword: 'flutter-dummy@example.com');

      final messages = dto.toEntity().toChatMessages();
      expect(messages, hasLength(1));
      expect(messages.single.content, 'Welcome back');
      expect(messages.single.sender, MessageSender.assistant);
    });
  });
}
