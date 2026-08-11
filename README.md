# TalkTroves Chat Widget

The TalkTroves Chat Widget enables businesses to integrate live customer support into websites, mobile applications, and desktop applications with minimal setup.

It provides real-time messaging, AI-powered assistance, conversation history, and team collaboration while offering a fully customizable chat experience that matches your brand.

---

# Features

- Live Chat
- AI-powered Customer Support
- Multi-Agent Support
- Conversation History
- Team Collaboration
- Real-time Messaging
- Typing Indicators
- Read Receipts
- Offline Messaging
- File Sharing
- Visitor Tracking
- Business Hours
- Multi-language Support
- Custom Branding
- Analytics Dashboard
- Mobile & Desktop Support
- Secure Communication

---

# Getting Started

## Create a TalkTroves Account

1. Visit **https://app.talktroves.com**
2. Click **Sign Up**
3. Register using your business email address.
4. Verify your email.
5. Log in to your account.

---

## Create a Workspace

After logging in:

1. Create a new Workspace.
2. Enter your business information.
3. Invite team members (optional).

A workspace can contain multiple projects.

---

## Create a Project

Inside your workspace:

1. Click **Create Project**.
2. Enter a project name.
3. Select the integration type.
4. Save the project.

Each project has its own configuration and Widget Key.

---

# Getting Your Widget Key

Every TalkTroves project is assigned a unique **Widget Key**.

To obtain your Widget Key:

1. Log in to **https://app.talktroves.com**
2. Open your Workspace.
3. Select the desired Project.
4. Navigate to **Widget Settings** or **Integration Settings**.
5. Copy the generated **Widget Key**.

Example:

```text
YOUR_WIDGET_KEY
```

This key uniquely identifies your TalkTroves project and is required when initializing the widget.

---

# User Identification

For the best experience, provide a stable unique identifier for every authenticated user.

Recommended identifiers include:

- Customer ID
- Database ID
- UUID
- Firebase UID
- Authentication Provider ID

Using the same identifier across sessions allows TalkTroves to:

- Restore previous conversations
- Maintain conversation history
- Identify returning users
- Route conversations correctly

---

# Optional User Information

Providing additional user information helps support agents deliver better customer service.

Supported information may include:

- Name
- Email Address
- Phone Number
- Company
- Profile Image
- Custom Metadata

---

# Widget Customization

The TalkTroves Widget is fully customizable to match your brand.

Common customization options include:

- Primary Color
- Accent Color
- Company Logo
- Chat Launcher Icon
- Welcome Message
- Widget Position
- Theme (Light / Dark)
- Language
- Business Hours
- Launcher Visibility

Most appearance settings can be managed directly from the TalkTroves Dashboard.

---

# Conversation Management

TalkTroves automatically manages:

- Conversation History
- Active Sessions
- Agent Assignment
- Unread Messages
- Offline Messages
- Visitor Tracking
- Message Delivery Status
- Read Receipts

---

# Dashboard Features

The TalkTroves Dashboard allows administrators to:

- Manage Conversations
- Manage Agents
- Configure AI Assistants
- Customize the Chat Widget
- View Analytics
- Create Teams
- Configure Business Hours
- Manage Projects
- Configure Automation Rules

Dashboard:

https://app.talktroves.com

---

# Security

Every project is isolated using its own Widget Key.

For security:

- Keep your Widget Key secure.
- Use production keys only in production environments.
- Avoid exposing sensitive credentials publicly.
- Rotate your keys if compromise is suspected.

---

# Best Practices

- Use a stable user identifier.
- Provide user information whenever available.
- Configure branding before deployment.
- Test integrations in a staging environment.
- Keep your SDK or integration updated to the latest version.

---

# Frequently Asked Questions

## Can I use the widget on multiple platforms?

Yes. TalkTroves provides integrations for multiple platforms and technologies. Each project uses the same Widget Key regardless of the client platform.

---

## Can I customize the widget?

Yes. The widget supports branding, colors, launcher customization, themes, welcome messages, positioning, and more.

---

## Will conversations persist?

Yes. Conversations are automatically restored when the same user identifier is provided.

---

## Can multiple agents handle conversations?

Yes. Multiple support agents can collaborate within the same workspace.

---

# Support

**Website**

https://talktroves.com

**Dashboard**

https://app.talktroves.com

**Documentation**

https://talktroves.com

**Support Email**

support@talktroves.com

---

## Package Installation

Add this package to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  chat_support_widget: ^0.0.1
```

Run package resolution:

```bash
flutter pub get
```

---

## Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:chat_support_widget/chat_support_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 380,
            height: 600,
            child: SupportChatWidget(
              config: SupportChatConfig(
                visitorConfig: VisitorConfig(
                  baseUrl: 'https://your-chatscript-host',
                  tenantId: 'your-tenant-id',
                  url: 'https://example.com',
                  title: 'Home',
                  isMobile: true,
                  domain: 'example.com',
                ),
                userData: const SupportUserData(
                  name: 'Example',
                  email: 'example@example.com',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Advanced Customization: Overriding UI Components

### 1. Custom AppBar / Header Builder

```dart
SupportChatWidget(
  config: config,
  headerBuilder: (context, config, isOnline) {
    return Container(
      color: Colors.red,
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Custom App Bar - ${config.headerTitle}',
        style: const TextStyle(color: Colors.white, fontSize: 18.0),
      ),
    );
  },
)
```

### 2. Custom Welcome Sub-header Builder

```dart
SupportChatWidget(
  config: config,
  subHeaderBuilder: (context, config) {
    return Container(
      color: Colors.amber,
      padding: const EdgeInsets.all(8.0),
      child: Text('Custom Help Text: ${config.subHeaderSubtitle}'),
    );
  },
)
```

### 3. Custom Chat Bubbles Builder

```dart
SupportChatWidget(
  config: config,
  bubbleBuilder: (context, message, formattedTime) {
    if (message.sender == MessageSender.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Card(
          color: Colors.green[100],
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(message.content),
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(message.content),
          ),
        ),
      );
    }
  },
)
```

### 4. Custom Bottom Input Field & Toolbar Builder

```dart
SupportChatWidget(
  config: config,
  inputBuilder: (context, controller, isTyping, onSend) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter text...'),
            ),
          ),
          ElevatedButton(
            onPressed: onSend,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  },
)
```