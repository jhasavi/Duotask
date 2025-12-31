# DuoTask

A visually engaging, real-time task-sharing app built with Flutter and Supabase, designed to help two people — such as couples, roommates, or teammates — coordinate daily responsibilities in a fun and effortless way.

## 📚 Documentation

- **[User Guide](USER_GUIDE.md)** - Complete user documentation, getting started, and troubleshooting
- **[Developer Guide](DEVELOPER_GUIDE.md)** - Development setup, project structure, and contribution guidelines
- **[Architecture](ARCHITECTURE.md)** - System architecture, database schema, and technical design
- **[Pairing Test Guide](PAIRING_TEST_GUIDE.md)** - Testing pairing functionality

## 🎯 Features

### ✨ Core Functionality

- **Animated Bubble Interface**: Tasks appear as dynamic, colorful bubbles that change size and color based on status and urgency
- **Real-time Synchronization**: Instant updates between paired users using Supabase real-time features
- **Smart Pairing System**: Unique 8-character codes to securely connect with your partner
- **Natural Language Input**: Add tasks quickly with natural phrases like "Grocery @6pm" or "Call mom tomorrow"
- **Status Cycling**: Tap bubbles to cycle through Unclaimed → Claimed → Completed states
- **Priority Levels**: Normal and Urgent tasks with visual indicators
- **Recurring Tasks**: Support for daily and weekly task repetition

### 🔐 Authentication

- Email/Password registration and login
- Google OAuth sign-in (Web, iOS, Android)
- Magic link authentication (passwordless)
- Persistent sessions with automatic token refresh

### 🔔 Notifications

- Local notifications for task reminders (1 hour before due)
- Partner activity notifications (task claimed/completed)
- Daily summary notifications (configurable time)
- Full FCM integration ready for production

### 🎨 Visual Design

- Material 3 design system
- Smooth animations and transitions
- Confetti celebration when tasks are completed
- Color-coded task status:
  - Light Orange: Unclaimed personal tasks
  - Dark Orange: Unclaimed partner tasks
  - Blue: Claimed tasks
  - Green: Completed tasks
  - Red: Urgent tasks

## 🚀 Quick Start

### For Users

1. Visit the live app: **https://duotask-nxpt77b88-sanjeevs-projects-e08bbbfb.vercel.app**
2. Sign up with email or Google
3. Generate a pairing code to connect with your partner
4. Start adding and managing tasks together!

See the **[User Guide](USER_GUIDE.md)** for detailed instructions.

### For Developers

```bash
# Clone repository
git clone <repository-url>
cd duotask

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome
```

See the **[Developer Guide](DEVELOPER_GUIDE.md)** for full setup instructions.

## 📱 Platform Support

- ✅ **Web** (Chrome, Firefox, Safari, Edge) - Production ready
- ✅ **iOS** 12.0+ - Development ready
- ✅ **Android** 5.0+ (API 21+) - Development ready
- ✅ **macOS** 10.14+ - Development ready

## 🏗️ Tech Stack

- **Frontend**: Flutter 3.38.4 (Dart)
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **Deployment**: Vercel (Web)
- **State Management**: Provider pattern
- **Authentication**: Email + Google OAuth with PKCE

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for technical details.

## 📁 Project Structure

```
duotask/
├── lib/
│   ├── config/           # App configuration and theme
│   │   ├── app_config.dart
│   │   ├── constants.dart
│   │   └── theme.dart
│   ├── models/           # Data models
│   │   ├── user.dart
│   │   ├── task.dart
│   │   └── pairing.dart
│   ├── screens/          # UI screens
│   │   ├── auth_screen.dart
│   │   ├── home_screen.dart
│   │   ├── pairing_screen.dart
│   │   ├── task_detail_screen.dart
│   │   └── settings_screen.dart
│   ├── services/         # Business logic
│   │   ├── auth_service.dart
│   │   ├── task_service.dart
│   │   ├── pairing_service.dart
│   │   └── notification_service.dart
│   ├── widgets/          # Reusable widgets
│   │   └── task_bubble.dart
│   └── main.dart         # App entry point
├── supabase/            # Database schema
│   └── schema.sql
├── web/                 # Web-specific files
├── android/             # Android-specific files
├── ios/                 # iOS-specific files
├── .env                 # Environment variables
├── .env.example         # Environment variables template
└── pubspec.yaml         # Dependencies
```

## 🛠️ Configuration

See **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** for complete setup instructions including:
- Supabase configuration
- Google OAuth setup
- Environment variables
- Database schema deployment

## 🚢 Deployment

### Web (Vercel)

```bash
# Build Flutter web
flutter build web --release

# Deploy to Vercel
npx vercel deploy --prod
```

**Production URL**: https://duotask-nxpt77b88-sanjeevs-projects-e08bbbfb.vercel.app

### Mobile

See **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md#deployment)** for iOS and Android deployment instructions.

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

See **[PAIRING_TEST_GUIDE.md](PAIRING_TEST_GUIDE.md)** for pairing functionality tests.

## 🔮 Roadmap

### Version 1.1 (Q1 2026)
- Push notifications for task reminders
- Native mobile apps (iOS/Android)
- Offline mode with sync
- Task templates

### Version 1.2 (Q2 2026)
- In-app messaging between partners
- File attachments for tasks
- Task analytics and insights
- Export tasks (CSV, PDF)

### Version 2.0 (Q3 2026)
- Multi-partner support (teams)
- Advanced task filtering
- Custom themes
- Calendar integration

## 🤝 Contributing

Contributions are welcome! See **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** for guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Documentation**: See guides in repository root
- **Issues**: Open an issue on GitHub
- **Questions**: Contact maintainer

## 🎉 Author

Created with ❤️ for productive partnerships

---

**Happy Task Sharing! 🎈**
