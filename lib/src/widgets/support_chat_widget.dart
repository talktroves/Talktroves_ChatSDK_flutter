import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/config/visitor_config.dart';

import '../models/chat_message.dart';
import '../models/user_data.dart';
import '../models/attachment_file.dart';
import '../services/chat_service_event.dart';
import '../services/chatbot_service.dart';
import '../services/visitor_chat_service.dart';

class SupportChatConfig {
  final SupportUserData? userData;
  final String? deviceId;

  /// Optional custom backend. Defaults to [VisitorChatService] via [visitorConfig].
  final ChatbotService? customService;

  /// Chatscript visitor SDK config (session, activity, polling, Socket.IO).
  final VisitorConfig? visitorConfig;

  final String botName;

  final String headerTitle;
  final String subHeaderTitle;

  final String subHeaderSubtitle;

  const SupportChatConfig({
    this.userData,
    this.deviceId,
    this.customService,
    this.visitorConfig,
    this.botName = 'Support',
    this.headerTitle = 'support',
    this.subHeaderTitle = 'live support',
    this.subHeaderSubtitle = 'Ask us anything',
  }) : assert(
         customService != null || visitorConfig != null,
         'Either visitorConfig or customService must be provided.',
       );
}

// Custom builder type definitions for ultimate flexibility
typedef HeaderBuilder =
    Widget Function(
      BuildContext context,
      SupportChatConfig config,
      bool isOnline,
    );

typedef SubHeaderBuilder =
    Widget Function(BuildContext context, SupportChatConfig config);

typedef MessageBubbleBuilder =
    Widget Function(
      BuildContext context,
      ChatMessage message,
      String formattedTime,
    );

typedef InputAreaBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      bool isTyping,
      AttachmentFile? pendingAttachment,
      VoidCallback onSelectAttachment,
      VoidCallback onRemoveAttachment,
      VoidCallback onSend,
    );

/// The highly customizable Support Chatbot Widget.
class SupportChatWidget extends StatefulWidget {
  final SupportChatConfig config;

  /// Callback when a visitor session is created / reconnected.
  final void Function(String tenantId, String sessionId)? onSessionReady;

  /// Callback when the "Please update your info" action link is pressed.
  final VoidCallback? onUpdateInfoPressed;

  /// Callback when the exit/reset button is pressed.
  final VoidCallback? onExitPressed;

  /// Callback when the header minimize (−) icon is pressed — typically closes the chat.
  final VoidCallback? onMinimizePressed;

  /// Callback when the header expand (□) icon is pressed — typically toggles fullscreen.
  final VoidCallback? onExpandPressed;

  /// Whether the chat is currently shown fullscreen (controls expand icon).
  final bool isExpanded;

  /// Callback when the attachment (paperclip) button is pressed.
  /// Should return an [AttachmentFile] representing the selected image.
  final Future<AttachmentFile?> Function()? onAttachmentPressed;

  /// Callback when the menu (three dots) button is pressed.
  final VoidCallback? onMenuPressed;

  /// Custom builder for the App Bar / Main Header.
  final HeaderBuilder? headerBuilder;

  /// Custom builder for the Subheader Welcome Banner.
  final SubHeaderBuilder? subHeaderBuilder;

  /// Custom builder for individual chat bubbles (user, assistant, system messages).
  final MessageBubbleBuilder? bubbleBuilder;

  /// Custom builder for the input area and send/tool buttons.
  final InputAreaBuilder? inputBuilder;

  /// Theme styling customization.
  final Color primaryColor;
  final Color backgroundColor;

  const SupportChatWidget({
    Key? key,
    required this.config,
    this.onSessionReady,
    this.onUpdateInfoPressed,
    this.onExitPressed,
    this.onMinimizePressed,
    this.onExpandPressed,
    this.isExpanded = false,
    this.onAttachmentPressed,
    this.onMenuPressed,
    this.headerBuilder,
    this.subHeaderBuilder,
    this.bubbleBuilder,
    this.inputBuilder,
    this.primaryColor = const Color(0xFF2B5AD9), // exact bold blue from mockup
    this.backgroundColor = const Color(0xFFF5F7FB),
  }) : super(key: key);

  @override
  State<SupportChatWidget> createState() => _SupportChatWidgetState();
}

class _SupportChatWidgetState extends State<SupportChatWidget> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatbotService _chatbotService;
  StreamSubscription<ChatServiceEvent>? _eventsSubscription;
  bool _isTyping = false;
  bool _isOnline = true;
  bool _sessionReady = false;
  AttachmentFile? _pendingAttachment;
  late final String _activeDeviceId;
  SupportUserData? _localUserData;
  bool _sessionLoggedOut = false;
  bool _isSoundOn = true;
  final LayerLink _menuLayerLink = LayerLink();
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();

    // Resolve dynamic device ID fallback for anonymous users
    _activeDeviceId =
        widget.config.deviceId ??
        'Session-${DateTime.now().millisecondsSinceEpoch}';

    // Visitor SDK by default; optional customService for tests / alternate backends.
    _chatbotService =
        widget.config.customService ??
        VisitorChatService(widget.config.visitorConfig!);

    // Load initial greeting and system state
    _localUserData = widget.config.userData;
    _messages.add(ChatMessage.system('ended the chat'));
    _messages.add(ChatMessage.assistant('Hi! How can I help you today?'));

    _eventsSubscription = _chatbotService.events.listen(_onChatServiceEvent);
    unawaited(_bootstrapService());
  }

  Future<void> _bootstrapService() async {
    try {
      await _chatbotService.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isOnline = false;
        _messages.add(
          ChatMessage.system(
            'Error: Could not start support session. Please try again.',
          ),
        );
      });
    }
  }

  void _onChatServiceEvent(ChatServiceEvent event) {
    if (!mounted) return;

    switch (event) {
      case IncomingMessageEvent(:final message):
        setState(() {
          _messages.add(message);
          _isTyping = false;
        });
        _scrollToBottom();
      case TypingEvent(:final isTyping):
        setState(() => _isTyping = isTyping);
      case ConnectionStatusEvent(:final isOnline):
        setState(() => _isOnline = isOnline);
      case SessionReadyEvent(:final sessionId, :final tenantId):
        setState(() {
          _isOnline = true;
          _sessionReady = true;
          _messages.add(
            ChatMessage.system('Session ready · chat with session $sessionId'),
          );
        });
        widget.onSessionReady?.call(tenantId, sessionId);
        assert(() {
          debugPrint(
            '[SupportChat] session ready tenant=$tenantId session=$sessionId',
          );
          return true;
        }());
      case FormNoticeEvent(:final message):
        setState(() {
          _messages.add(message);
          _isTyping = false;
        });
        _scrollToBottom();
      case SessionEndedEvent():
        setState(() {
          _sessionReady = false;
          _sessionLoggedOut = true;
          _isOnline = false;
          _isTyping = false;
          _messages.add(ChatMessage.system('ended the chat'));
        });
      case ChatServiceErrorEvent(:final message):
        assert(() {
          debugPrint('[SupportChat] service error: $message');
          return true;
        }());
        break;
    }
  }

  @override
  void dispose() {
    _isMenuOpen = false;
    _eventsSubscription?.cancel();
    unawaited(_chatbotService.dispose());
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAttachmentSelection() async {
    if (widget.onAttachmentPressed != null) {
      final file = await widget.onAttachmentPressed!();
      if (file != null) {
        setState(() {
          _pendingAttachment = file;
        });
        await _sendMessage();
      }
    }
  }

  void _handleRemoveAttachment() {
    setState(() {
      _pendingAttachment = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    // Visitor SDK: wait until POST /session finished and sessionId exists.
    if (widget.config.visitorConfig != null &&
        (!_sessionReady || _sessionLoggedOut)) {
      setState(() {
        _messages.add(
          ChatMessage.system(
            _sessionLoggedOut
                ? 'Chat ended. Please start a new session.'
                : 'Please wait — creating visitor session...',
          ),
        );
      });
      return;
    }

    // Use placeholder text if only an image is sent
    final messageText = text.isEmpty ? "Sent an image attachment" : text;

    _inputController.clear();

    // 1. Create and add user message (with attachment if present)
    final userMessage = ChatMessage.user(
      messageText,
      attachment: _pendingAttachment,
    );

    setState(() {
      _messages.add(userMessage);
      _pendingAttachment = null;
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate standard messaging state change to "delivered"
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _messages.indexWhere((msg) => msg.id == userMessage.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.delivered,
        );
      });
    }

    try {
      // 2. Fetch response from Service (passing full message list history including image bytes)
      final reply = await _chatbotService.sendMessage(
        content: messageText,
        history: _messages,
        userData: _localUserData ?? widget.config.userData,
        deviceId: _activeDeviceId,
      );

      // Visitor SDK delivers agent replies via events; keep typing until then.
      if (_chatbotService.usesRealtimeDelivery || reply == null) {
        Future<void>.delayed(const Duration(seconds: 45), () {
          if (mounted && _isTyping) {
            setState(() => _isTyping = false);
          }
        });
      } else {
        setState(() {
          _messages.add(ChatMessage.assistant(reply));
          _isTyping = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            content: e.toString().contains('Internal server error')
                ? 'Error: Server rejected the message (check tenant id / backend).'
                : 'Error: Could not connect to support. Please try again.',
            sender: MessageSender.system,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _handleUpdateInfoPressed() async {
    widget.onUpdateInfoPressed?.call();
    if (widget.config.visitorConfig == null) {
      return;
    }
    await _showUpdateInfoDialog();
  }

  Future<void> _showUpdateInfoDialog() async {
    final result = await showDialog<SupportUserData>(
      context: context,
      builder: (dialogContext) {
        return _UpdateInfoDialog(
          initialName:
              _localUserData?.name ?? widget.config.userData?.name ?? '',
          initialEmail:
              _localUserData?.email ?? widget.config.userData?.email ?? '',
          sessionReady: _sessionReady,
          onSubmit: (name, email) async {
            await _chatbotService.updateVisitorInfo(name: name, email: email);
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _localUserData = result;
    });
  }

  Future<void> _showEmailTranscriptDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _EmailTranscriptDialog(
          initialEmail:
              _localUserData?.email ?? widget.config.userData?.email ?? '',
          sessionReady: _sessionReady,
          onSubmit: (email) async {
            final currentName =
                _localUserData?.name ?? widget.config.userData?.name ?? '';
            await _chatbotService.updateVisitorInfo(
              name: currentName,
              email: email,
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _localUserData = (_localUserData ?? const SupportUserData()).copyWith(
          email: result,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transcript will be sent to $result')),
      );
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _hideMenu() {
    if (!_isMenuOpen) return;
    if (!mounted) {
      _isMenuOpen = false;
      return;
    }
    setState(() {
      _isMenuOpen = false;
    });
  }

  Widget _buildMenuContent() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMenuItem(
                title: 'Sound',
                trailing: Text(
                  _isSoundOn ? 'On' : 'Off',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                onTap: () {
                  setState(() {
                    _isSoundOn = !_isSoundOn;
                  });
                },
              ),
              _buildMenuItem(
                title: 'Email Transcript',
                onTap: () {
                  _hideMenu();
                  _showEmailTranscriptDialog();
                },
              ),
              _buildMenuItem(
                title: 'Edit Contact detail',
                onTap: () {
                  _hideMenu();
                  _showUpdateInfoDialog();
                },
              ),
              _buildMenuItem(
                title: 'End Chat',
                onTap: () {
                  _hideMenu();
                  _handleExitPressed();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1B2538),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _handleExitPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to end this chat session?',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                // backgroundColor: widget.primaryColor,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _chatbotService.logout();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionReady = false;
        _sessionLoggedOut = true;
        _isOnline = false;
        _isTyping = false;
        _messages.add(ChatMessage.system('ended the chat'));
      });
    }

    widget.onExitPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Column(
              children: [
                // 1. Main Header / App Bar
                widget.headerBuilder != null
                    ? widget.headerBuilder!(context, widget.config, _isOnline)
                    : _buildDefaultHeader(),

                // 2. Sub Header Live Support Banner
                widget.subHeaderBuilder != null
                    ? widget.subHeaderBuilder!(context, widget.config)
                    : _buildDefaultSubHeader(),

                // 3. Chat Message Log — Expanded so keyboard shrinks this area.
                Expanded(
                  child: Container(
                    color: widget.backgroundColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final timeStr = DateFormat(
                          'h:mm a',
                        ).format(message.timestamp);

                        // User Custom Bubble Builder support
                        if (widget.bubbleBuilder != null) {
                          return widget.bubbleBuilder!(
                            context,
                            message,
                            timeStr,
                          );
                        }

                        if (message.sender == MessageSender.system) {
                          return _buildDefaultSystemMessage(message);
                        } else if (message.sender == MessageSender.user) {
                          return _buildDefaultUserBubble(message, timeStr);
                        } else {
                          return _buildDefaultAssistantBubble(message, timeStr);
                        }
                      },
                    ),
                  ),
                ),

                if (_isTyping && widget.inputBuilder == null)
                  Container(
                    color: widget.backgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 4.0,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.config.botName} is typing...',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // 4. Chat Input Section
                widget.inputBuilder != null
                    ? widget.inputBuilder!(
                        context,
                        _inputController,
                        _isTyping,
                        _pendingAttachment,
                        _handleAttachmentSelection,
                        _handleRemoveAttachment,
                        _sendMessage,
                      )
                    : _buildDefaultInputSection(),
              ],
            ),
            if (_isMenuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hideMenu,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              CompositedTransformFollower(
                link: _menuLayerLink,
                showWhenUnlinked: false,
                // Button sits on the right; open menu upward + left so it
                // stays fully inside the chatbot popup.
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -8),
                child: _buildMenuContent(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Premium Default Component Builders ---

  Widget _buildDefaultHeader() {
    return Container(
      color: widget.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            width: 42.0,
            height: 42.0,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 22.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.config.headerTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Row(
                  children: [
                    Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? const Color(0xFF34C759)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: widget.isExpanded ? 'Exit fullscreen' : 'Fullscreen',
            icon: Icon(
              widget.isExpanded ? Icons.fullscreen_exit : Icons.crop_square,
              color: Colors.white70,
              size: 20.0,
            ),
            onPressed: widget.onExpandPressed,
          ),
          const SizedBox(width: 12.0),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Close',
            icon: const Icon(Icons.remove, color: Colors.white70, size: 22.0),
            onPressed: widget.onMinimizePressed ?? widget.onExitPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSubHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.room_service_outlined,
              color: Colors.black87,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.config.subHeaderTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                  color: Colors.black87,
                ),
              ),
              Text(
                widget.config.subHeaderSubtitle,
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSystemMessage(ChatMessage message) {
    if (message.style == ChatMessageStyle.centeredNotice) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.0,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }

    if (message.content.contains('ended the chat')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            message.content,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13.0),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDefaultUserBubble(ChatMessage message, String timeStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 260.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F3FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(4.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment Rendering
                  if (message.attachment != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.memory(
                        message.attachment!.bytes,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Color(0xFF2C3E6B),
                      fontSize: 15.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  message.status == MessageStatus.sending
                      ? Icons.done
                      : Icons.done_all,
                  size: 14.0,
                  color:
                      message.status == MessageStatus.seen ||
                          message.status == MessageStatus.delivered
                      ? const Color(0xFF34C759)
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAssistantBubble(ChatMessage message, String timeStr) {
    final hasUpdateInfoLink = message.content.contains(
      'Hi! How can I help you today?',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16.0,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, color: Colors.white, size: 20.0),
            ),
            const SizedBox(width: 8.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.config.botName,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4.0),
                Container(
                  constraints: const BoxConstraints(maxWidth: 240.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFEBEFF5),
                      width: 1.0,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4.0),
                      topRight: Radius.circular(16.0),
                      bottomLeft: Radius.circular(16.0),
                      bottomRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500),
                ),
                if (hasUpdateInfoLink) ...[
                  const SizedBox(height: 12.0),
                  InkWell(
                    onTap: _handleUpdateInfoPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Please update your info',
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultInputSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Image upload thumbnail preview inside bottom field
          if (_pendingAttachment != null) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 12.0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  Container(
                    width: 70.0,
                    height: 70.0,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      _pendingAttachment!.bytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2.0,
                    right: 2.0,
                    child: InkWell(
                      onTap: _handleRemoveAttachment,
                      child: CircleAvatar(
                        radius: 10.0,
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 1.0),
              borderRadius: BorderRadius.circular(16.0),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Type a message here',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15.0),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.black54),
                onPressed: _handleExitPressed,
              ),
              CompositedTransformTarget(
                link: _menuLayerLink,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.black54),
                  onPressed: _toggleMenu,
                ),
              ),
              SizedBox(width: 10),
              // const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                ),
                onPressed: _sendMessage,
                child: const Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateInfoDialog extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final bool sessionReady;
  final Future<void> Function(String name, String email) onSubmit;

  const _UpdateInfoDialog({
    required this.initialName,
    required this.initialEmail,
    required this.sessionReady,
    required this.onSubmit,
  });

  @override
  State<_UpdateInfoDialog> createState() => _UpdateInfoDialogState();
}

class _UpdateInfoDialogState extends State<_UpdateInfoDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and email.')),
      );
      return;
    }

    if (!widget.sessionReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait — visitor session is not ready yet.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(name, email);
      if (!mounted) return;
      Navigator.of(context).pop(SupportUserData(name: name, email: email));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update info: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Text(
                'Edit contact details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B2538),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF384A62),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF384A62),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF384A62),
                          side: const BorderSide(
                            color: Color(0xFFD3DDF6),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2B5AD9),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailTranscriptDialog extends StatefulWidget {
  final String initialEmail;
  final bool sessionReady;
  final Future<void> Function(String email) onSubmit;

  const _EmailTranscriptDialog({
    required this.initialEmail,
    required this.sessionReady,
    required this.onSubmit,
  });

  @override
  State<_EmailTranscriptDialog> createState() => _EmailTranscriptDialogState();
}

class _EmailTranscriptDialogState extends State<_EmailTranscriptDialog> {
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an email.')));
      return;
    }

    if (!widget.sessionReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait — visitor session is not ready yet.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(email);
      if (!mounted) return;
      Navigator.of(context).pop(email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request transcript: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Text(
                'Email chat Transcript',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B2538),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF384A62),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFD3DDF6),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF384A62),
                          side: const BorderSide(
                            color: Color(0xFFD3DDF6),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2B5AD9),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
