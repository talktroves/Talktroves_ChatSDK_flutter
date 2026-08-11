import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:talktroves_chatsdk/talktroves_chatsdk.dart';

void main() {
  test('SupportUserData JSON conversion', () {
    const userData = SupportUserData(
      name: 'John Doe',
      email: 'john@example.com',
      metadata: {'tier': 'premium'},
    );

    final json = userData.toJson();
    expect(json['name'], 'John Doe');
    expect(json['email'], 'john@example.com');
    expect(json['tier'], 'premium');
  });

  test('ChatMessage creation helpers with attachments', () {
    final attachment = AttachmentFile(
      name: 'receipt.png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      mimeType: 'image/png',
    );

    final systemMsg = ChatMessage.system('hello');
    expect(systemMsg.sender, MessageSender.system);
    expect(systemMsg.content, 'hello');

    final userMsg = ChatMessage.user('hi', attachment: attachment);
    expect(userMsg.sender, MessageSender.user);
    expect(userMsg.status, MessageStatus.sending);
    expect(userMsg.attachment, isNotNull);
    expect(userMsg.attachment!.name, 'receipt.png');

    final assistantMsg = ChatMessage.assistant('welcome');
    expect(assistantMsg.sender, MessageSender.assistant);
  });
}
