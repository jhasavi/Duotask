# DuoTask - Task Management for Couples

A Flutter-based task management application designed specifically for couples and partners. The app enables users to create, share, and manage tasks together, fostering collaboration and accountability in relationships.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Supabase account
- Google Cloud Console account (for OAuth)

### Setup

1. **Clone and install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure environment variables:**
   The `.env` file is already configured with the necessary credentials.

3. **Run the app:**
   ```bash
   flutter run -d chrome --web-port 5000
   ```

## 📱 Features

### ✅ Implemented Features
- **Google OAuth Integration:** Seamless sign-in with Google accounts
- **Email/Password Authentication:** Traditional email-based registration and login
- **User Profiles:** Basic user information storage
- **Task Management:** Create, view, and manage tasks
- **Clean UI:** Material Design 3 interface with custom app icon

### 🚧 Planned Features
- **Partner Pairing:** Unique pairing codes to connect partners
- **Real-time Updates:** Live task synchronization between partners
- **Task Categories:** Organize tasks by type
- **Push Notifications:** Reminders for upcoming deadlines

## 🏗️ Architecture

- **Frontend:** Flutter with Material Design 3
- **Backend:** Supabase (PostgreSQL + Real-time)
- **Authentication:** Supabase Auth with Google OAuth
- **Database:** PostgreSQL with Row Level Security (RLS)

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── screens/
│   ├── auth_screen.dart   # Authentication UI
│   └── task_screen.dart   # Task management screen
├── services/
│   ├── auth_service.dart  # Authentication logic
│   └── task_service.dart  # Task management logic
└── models/
    ├── task.dart          # Task data model
    └── user.dart          # User data model
```

## 🔧 Configuration

The app is pre-configured with:
- Supabase project connection
- Google OAuth setup
- Database schema
- Security policies

## 🚀 Deployment

### Web Deployment
```bash
flutter build web
```

### Mobile Deployment
```bash
flutter build ios     # iOS
flutter build apk     # Android
```

## 📝 Notes

- This is a simplified version focused on core functionality
- The app uses the custom `icon.png` as the app logo
- OAuth redirect URLs are configured for `localhost:5000`
- Database tables and RLS policies are set up in Supabase

## 📞 Support

For detailed documentation, see `DUOTASK_COMPREHENSIVE_DOCUMENTATION.md`
For project status, see `PROJECT_SUMMARY.md` 