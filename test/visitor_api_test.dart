import 'package:flutter_test/flutter_test.dart';
import 'package:talktroves_chatsdk/src/data/models/create_session_request_dto.dart';
import 'package:talktroves_chatsdk/src/data/models/create_session_response_dto.dart';
import 'package:talktroves_chatsdk/src/data/models/polling_response_dto.dart';
import 'package:talktroves_chatsdk/src/domain/entities/visitor_activity.dart';

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
}
