# DuoTask - Simple Task Sharing for Two

<div align="center">
  <img src="assets/app_icon.png" alt="DuoTask Logo" width="120" height="120">
  <h1>DuoTask</h1>
  <p><strong>Simple task sharing for two people</strong></p>
  <p>Perfect for spouses, roommates, or co-workers who want to share and manage daily tasks together.</p>
</div>

## 🚀 Features

### ✨ Core Functionality
- **Smart Pairing System**: Easy pairing with unique codes or email invitations
- **Task Management**: Create, claim, and complete tasks with intuitive bubble interface
- **Real-time Sync**: Instant updates across both users' devices
- **Task Reclaiming**: Reclaim tasks from your partner when needed
- **Due Date Support**: Set deadlines and get overdue notifications
- **Urgent Tasks**: Mark tasks as urgent for priority handling

### 🎯 User Experience
- **One-tap Status Changes**: Quick task progression with visual feedback
- **Tap for Details**: Single tap shows task details, double tap changes status
- **Toast Notifications**: Beautiful confirmation messages for all actions
- **Smart Registration**: Pre-fills email and password when switching from login
- **Modern UI**: Clean, minimalist design with smooth animations

### 🔐 Security & Authentication
- **Email/Password**: Traditional authentication
- **Google OAuth**: One-tap sign-in with Google
- **Email Confirmation**: Secure account verification
- **Custom Branding**: Professional DuoTask-branded emails

## 📱 Platforms

- ✅ **iOS** (iPhone & iPad)
- ✅ **Android**
- ✅ **Web** (Progressive Web App)
- ✅ **macOS** (Desktop app)

## 🛠️ Technology Stack

- **Frontend**: Flutter (Cross-platform)
- **Backend**: Supabase (PostgreSQL + Real-time)
- **Authentication**: Supabase Auth + Google OAuth
- **Notifications**: Firebase Cloud Messaging
- **Database**: PostgreSQL with Row Level Security (RLS)

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Supabase account
- Firebase account (for notifications)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/duotask.git
   cd duotask
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   cp env.example .env
   # Edit .env with your Supabase and Firebase credentials
   ```

4. **Set up Supabase**
   ```bash
   # Install Supabase CLI
   npm install -g supabase
   
   # Login to Supabase
   supabase login
   
   # Link your project
   supabase link --project-ref your-project-ref
   
   # Push database schema
   supabase db push
   
   # Deploy functions
   supabase functions deploy
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## 📋 Setup Guide

### 1. Supabase Configuration

1. Create a new Supabase project
2. Get your project URL and anon key
3. Update your `.env` file:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_anon_key_here
   ```

### 2. Database Setup

The app uses a clean dyad-based pairing system. Run the migration:

```bash
supabase db push
```

This creates:
- `usr` table for user profiles
- `pair` table for pairing relationships
- `tasks` table with personal/shared scope
- All necessary indexes and RLS policies

### 3. Email Branding

To customize email templates with DuoTask branding:

1. Deploy the email branding function:
   ```bash
   supabase functions deploy auth-email-branding
   ```

2. Configure Supabase Auth to use custom templates (requires Supabase Pro)

### 4. Firebase Setup (Optional)

For push notifications:

1. Create a Firebase project
2. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Place them in the appropriate directories
4. Update your `.env` file with Firebase credentials

## 🎮 Usage

### Pairing with Someone

1. **Generate Pair Code**: Tap the pairing button to get a unique 8-character code
2. **Share Code**: Send the code to your partner via any method
3. **Enter Code**: Partner enters the code to establish the pairing
4. **Start Sharing**: Both users can now create and manage shared tasks

### Managing Tasks

- **Create Task**: Tap the + button to add a new task
- **View Details**: Single tap any task bubble to see details
- **Change Status**: Double tap to cycle through status (Unclaimed → Claimed → Done)
- **Reclaim Task**: Use the reclaim button in task details if needed
- **Delete Task**: Long press for 2 seconds to delete

### Task Types

- **Personal Tasks**: Only visible to you
- **Shared Tasks**: Visible to both paired users
- **Urgent Tasks**: Marked with red border for priority

## 🔧 Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # Business logic
├── utils/                    # Utilities
└── widgets/                  # Reusable components
```

### Key Services

- `CleanPairingService`: Handles pairing logic
- `TaskService`: Manages task operations
- `AuthService`: Authentication and user management

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

## 📚 Documentation

- [Design Document](DuoTask_Design_Document.md) - Detailed design specifications
- [Pairing System](PAIRING.md) - Pairing architecture and implementation
- [Setup Guide](SETUP_GUIDE.md) - Complete setup instructions
- [API Documentation](API_DOCUMENTATION.md) - Backend API reference

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the docs folder for detailed guides
- **Issues**: Report bugs and feature requests on GitHub
- **Email**: support@duotask.app

## 🗺️ Roadmap

- [ ] Apple Sign-In support
- [ ] Task categories and filtering
- [ ] Task history and analytics
- [ ] Offline support
- [ ] Voice commands
- [ ] Calendar integration
- [ ] Task templates
- [ ] Multi-language support

---

<div align="center">
  <p>Made with ❤️ for couples, roommates, and co-workers everywhere</p>
  <p><a href="https://duotask.app">duotask.app</a></p>
</div>
