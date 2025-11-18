# DuoTask

A visually engaging, real-time task-sharing app built with Flutter and Supabase, designed to help two people — such as couples, roommates, or teammates — coordinate daily responsibilities in a fun and effortless way.

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

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- A Supabase account and project (already configured)
- Xcode (for iOS development)
- Android Studio (for Android development)
- Chrome browser (for web testing)

### Quick Start

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the multi-platform test**
   ```bash
   ./test_all_platforms.sh
   ```
   
   This will automatically:
   - Launch the web app in Chrome
   - Start iOS simulator and run the app
   - Start Android emulator and run the app
   - Provide testing instructions for pairing and features

### Manual Platform Setup

**Web:**
```bash
flutter run -d chrome --web-port 5000
```

**iOS:**
```bash
# Ensure iOS simulator is running
open -a Simulator
flutter run -d ios
```

**Android:**
```bash
# Ensure Android emulator is running
$ANDROID_HOME/emulator/emulator -avd <your_avd_name>
flutter run -d android
```

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

### Supabase Setup

1. Create a new Supabase project
2. Run the SQL schema from `supabase/schema.sql`
3. Enable Google OAuth in Authentication settings
4. Add your redirect URLs in Authentication settings
5. Enable real-time for the tables (users, tasks, pairings)

### Google OAuth Setup

1. Create a project in Google Cloud Console
2. Enable Google+ API and Google People API
3. Create OAuth 2.0 credentials (Web, iOS, Android)
4. Add authorized redirect URIs:
   - `http://localhost:5000` (development)
   - `https://your-supabase-url.supabase.co/auth/v1/callback`
5. Update `.env` with your client IDs

### Firebase Setup (Optional - for FCM)

1. Create a Firebase project
2. Add your Flutter app (iOS, Android, Web)
3. Download configuration files
4. Enable Firebase Cloud Messaging
5. Update app configuration files

## 🎮 Usage

### Creating a Pairing

1. User A: Tap the person icon → Generate pairing code
2. User A: Share the 8-character code with User B
3. User B: Tap the person icon → Enter the code
4. Both users are now paired and can see shared tasks

### Adding Tasks

**Quick Add (Natural Language):**
- "Grocery @6pm" → Task due at 6 PM today
- "Call mom tomorrow" → Task due tomorrow at 9 AM
- "Urgent: Fix bug" → High priority task
- "Clean kitchen" → Simple task

**Detailed Add:**
- Long-press a bubble to edit details
- Set priority, recurrence, description

### Task Lifecycle

1. **Unclaimed** (Large bubble, orange)
   - Tap to claim the task
2. **Claimed** (Medium bubble, blue)
   - Tap to mark as complete
3. **Completed** (Small bubble, green, faded)
   - Tap to unclaim (cycle back)

## 📱 Platform Support

- ✅ Web (Chrome, Firefox, Safari, Edge)
- ✅ iOS 12.0+
- ✅ Android 5.0+ (API 21+)
- ✅ macOS 10.14+

## 🧪 Testing

### Automated Multi-Platform Testing
```bash
# Run comprehensive test across all platforms
./test_all_platforms.sh
```

### Individual Platform Testing
```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Testing Workflow
1. **Launch all platforms** using the test script
2. **Create account** on one platform (Web is recommended)
3. **Generate pairing code** 
4. **Join from second platform** using the code
5. **Test task creation, claiming, and completion**
6. **Verify real-time sync** across platforms
7. **Test notifications** and offline functionality

## 🚢 Deployment

### Web

```bash
flutter build web
# Deploy the build/web folder to your hosting provider
```

### iOS

```bash
flutter build ios
# Open Xcode and archive the app
```

### Android

```bash
flutter build appbundle
# Upload to Google Play Console
```

## 🔮 Planned Features

- [ ] Voice input for task creation
- [ ] Calendar integration
- [ ] Smart suggestions based on usage patterns
- [ ] Task templates
- [ ] Multi-language support
- [ ] Dark mode preferences
- [ ] Task categories
- [ ] File attachments
- [ ] In-app messaging
- [ ] Analytics dashboard

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Supabase for the backend infrastructure
- Material Design for the design system
- All contributors and testers

## 📞 Support

For support, email support@duotask.app or join our Discord community.

## 🎉 Author

Created with ❤️ for productive partnerships

---

**Happy Task Sharing! 🎈**
