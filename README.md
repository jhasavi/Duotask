# DuoTask

A visually engaging, real-time task-sharing app built with Flutter and Supabase, designed to help two people — such as couples, roommates, or teammates — coordinate daily responsibilities in a fun and effortless way.

## 📚 Documentation

- **[User Guide](USER_GUIDE.md)** - Complete user documentation, getting started, and troubleshooting
- **[Developer Guide](DEVELOPER_GUIDE.md)** - Development setup, project structure, and contribution guidelines
- **[Architecture](ARCHITECTURE.md)** - System architecture, database schema, and technical design
- **[Project Status](PROJECT_STATUS.md)** - Current state and what blocks release
- **[Security](SECURITY.md)** - Credential handling and automated guards
- **[Release Process](docs/RELEASE.md)** - How deployments work
- **[Testing Guide](TESTING_GUIDE.md)** - The hermetic and integration suites
- **[Production Roadmap](PRODUCTION_ROADMAP.md)** - Shipped work and next steps

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

Merging to `main` builds from that commit, applies migrations, deploys, and
smoke-tests the result. See **[docs/RELEASE.md](docs/RELEASE.md)**.

To build locally:

```bash
scripts/build_web.sh
```

Never run a bare `flutter build web` for anything you intend to publish — it
can bundle `.env` into the served assets. See **[SECURITY.md](SECURITY.md)**.

### Mobile

See **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md#deployment)** for iOS and Android deployment instructions.

## 🧪 Testing

```bash
flutter test                     # hermetic suite, no backend
flutter test --tags integration  # live-backend suite, needs a test project
```

See **[TESTING_GUIDE.md](TESTING_GUIDE.md)**. The pairing flow that used to
require two humans and two browsers is now covered by automated tests.

## 🔮 Roadmap

### Version 1.2 (Current — August 2026)
- ✅ Nudge system UI
- ✅ Email preferences
- ✅ Task search, today filter, undo
- ✅ CI/CD pipeline with automated deploy and post-deploy smoke test
- ✅ Automated pairing and sign-up integration tests
- ✅ Secret scanning; config injected at build time rather than bundled
- ✅ Production documentation

### Version 1.3 (Q3 2026)
- Push notifications for task reminders
- Offline mode with sync
- Task categories/tags
- Monthly recurring tasks

### Version 2.0 (Q4 2026)
- Multi-partner support (teams)
- Task analytics dashboard
- File attachments
- Calendar integration

## 🤝 Contributing

Contributions are welcome! See **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** for guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📱 Mobile builds

- **Android**: `flutter build apk --release`
- **iOS**: `flutter build ios --release` (requires an Apple Developer account)

## 📞 Support

- **Documentation**: See guides in repository root
- **Issues**: Open an issue on GitHub
- **Questions**: Contact maintainer

## 🎉 Author

Created with ❤️ for productive partnerships

---

**Happy Task Sharing! 🎈**
