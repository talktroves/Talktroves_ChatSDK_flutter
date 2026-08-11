import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
      title: 'Support Chat Example',
      home: const SupportChatDemoPage(),
    );
  }
}

class SupportChatDemoPage extends StatefulWidget {
  const SupportChatDemoPage({super.key});

  @override
  State<SupportChatDemoPage> createState() => _SupportChatDemoPageState();
}

class _SupportChatDemoPageState extends State<SupportChatDemoPage> {
  final ImagePicker _imagePicker = ImagePicker();
  int _chatInstance = 0;
  bool _chatCreated = false;
  bool _chatVisible = false;
  bool _startNewSessionOnNextOpen = false;

  /// A new session is created only on the first open or after explicit logout.
  SupportChatConfig get _config {
    return SupportChatConfig(
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

  void _minimizeChat() {
    setState(() {
      _chatVisible = false;
    });
  }

  void _endChatSession() {
    setState(() {
      _chatVisible = false;
      _startNewSessionOnNextOpen = true;
    });
    if (kDebugMode) {
      debugPrint(
        '[TalkTroves] Chat ended — next open will create a new session | '
        'tenant=${TalkTrovesConfig.tenantId}',
      );
    }
  }

  void _openChatPopup() {
    setState(() {
      if (_startNewSessionOnNextOpen) {
        _chatInstance++;
        _startNewSessionOnNextOpen = false;
      }
      _chatCreated = true;
      _chatVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Support Chat Demo'),
        backgroundColor: const Color(0xFF2B5AD9),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tap the chat button to open live support.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ),
          if (_chatCreated)
            Visibility(
              visible: _chatVisible,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: _ChatPopupDialog(
                chatInstance: _chatInstance,
                config: _config,
                onPickAttachment: _pickImageAttachment,
                onMinimized: _minimizeChat,
                onEnded: _endChatSession,
              ),
            ),
        ],
      ),
      floatingActionButton: _chatVisible
          ? null
          : FloatingActionButton.extended(
              onPressed: _openChatPopup,
              backgroundColor: const Color(0xFF2B5AD9),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Support'),
            ),
    );
  }
}

/// Chat overlay that stays mounted while minimized to preserve its session.
class _ChatPopupDialog extends StatefulWidget {
  final int chatInstance;
  final SupportChatConfig config;
  final Future<AttachmentFile?> Function() onPickAttachment;
  final VoidCallback onMinimized;
  final VoidCallback onEnded;

  const _ChatPopupDialog({
    required this.chatInstance,
    required this.config,
    required this.onPickAttachment,
    required this.onMinimized,
    required this.onEnded,
  });

  @override
  State<_ChatPopupDialog> createState() => _ChatPopupDialogState();
}

class _ChatPopupDialogState extends State<_ChatPopupDialog> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _isExpanded
          ? EdgeInsets.only(
              top: padding.top,
              bottom: padding.bottom,
              left: padding.left,
              right: padding.right,
            )
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _isExpanded
            ? media.width - padding.left - padding.right
            : math.min(380.0, media.width - 32),
        height: _isExpanded
            ? media.height - padding.top - padding.bottom
            : math.min(600.0, media.height - 48),
        child: SupportChatWidget(
          key: ValueKey(widget.chatInstance),
          config: widget.config,
          isExpanded: _isExpanded,
          onSessionReady: (tenantId, sessionId) {
            if (kDebugMode) {
              debugPrint(
                '[TalkTroves] Session created → chat with '
                'tid=$tenantId sid=$sessionId',
              );
            }
          },
          onMinimizePressed: widget.onMinimized,
          onExpandPressed: _toggleExpand,
          onExitPressed: widget.onEnded,
          onAttachmentPressed: widget.onPickAttachment,
          onMenuPressed: () {},
        ),
      ),
    );
  }
}
