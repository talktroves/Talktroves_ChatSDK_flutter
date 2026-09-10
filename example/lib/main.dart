import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talktroves_chatsdk/talktroves_chatsdk.dart';

import 'talk_troves_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalkTroves Chat Example',
      home: const TalktrovesChatDemoPage(),
    );
  }
}

class TalktrovesChatDemoPage extends StatefulWidget {
  const TalktrovesChatDemoPage({super.key});

  @override
  State<TalktrovesChatDemoPage> createState() => _TalktrovesChatDemoPageState();
}

class _TalktrovesChatDemoPageState extends State<TalktrovesChatDemoPage> {
  final ImagePicker _imagePicker = ImagePicker();

  /// A new session is created only on the first open or after explicit logout.
  TalktrovesChatConfig get _config {
    return TalktrovesChatConfig(
      visitorConfig: VisitorConfig(
        baseUrl: TalkTrovesConfig.baseUrl,
        tenantId: TalkTrovesConfig.tenantId,
        sessionId: null,
        reconnect: false,
        url: TalkTrovesConfig.pageUrl,
        title: TalkTrovesConfig.pageTitle,
        tz: TalkTrovesConfig.timezoneOffsetHours,
        navigatorLanguage: TalkTrovesConfig.navigatorLanguage,
        isMobile: true,
        domain: TalkTrovesConfig.domain,
        enableSocket: TalkTrovesConfig.enableSocket,
        pollingInterval: TalkTrovesConfig.pollingInterval,
      ),
      userData: const SupportUserData(
        name: 'Flutter Dummy User',
        email: 'flutter-dummy@example.com',
        metadata: {'source': 'flutter_sdk_demo', 'role': 'visitor'},
      ),
      deviceId: 'dummy-sender-device-001',
      botName: 'TalkTroves Bot',
      headerTitle: 'support',
      subHeaderTitle: 'live support',
      subHeaderSubtitle: 'Ask us anything',
      showWelcomeMessage: true,
      highlightText: 'Order #914',
      welcomeMessage:
          'Hi! This is your Order #914.\nWhat would you like to know about this order?',
      quickQuestions: const [
        'Where is my order?',
        'What\'s my order status?',
        'Why is my order delayed?',
        'I have an issue with my order',
      ],
    );
  }

  Future<AttachmentFile?> _pickImageAttachment() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return null;

    final bytes = await pickedFile.readAsBytes();
    return AttachmentFile(
      name: pickedFile.name,
      bytes: bytes,
      mimeType: _imageMimeType(pickedFile.name),
    );
  }

  String _imageMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  void _openChatFullScreen() {
    TalktrovesChatPage.open(
      context,
      config: _config,
      onAttachmentPressed: _pickImageAttachment,
      onOrderTap: (orderId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigating to Order details ($orderId)...'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('TalkTroves Chat Demo'),
        backgroundColor: const Color(0xFF2B5AD9),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tap the chat button to open live support.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChatFullScreen,
        backgroundColor: const Color(0xFF2B5AD9),
        icon: const Icon(Icons.headset_mic),
        label: const Text('Support'),
      ),
    );
  }
}
