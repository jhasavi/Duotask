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
   git clone https://github.com/jhasavi/taskbubble.git
   cd taskbubble
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
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

## 🔧 Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── screens/                  # UI screens
├── services/                 # Business logic
│   ├── auth_service.dart     # Authentication with rate limiting
│   ├── task_service.dart     # Task management with caching
│   ├── rate_limit_service.dart # Security rate limiting
│   └── task_cache_service.dart # Performance caching
├── utils/                    # Utilities
└── widgets/                  # Reusable components

test/                         # Unit, widget, and integration tests
docs/                         # Documentation and architecture
.github/workflows/           # CI/CD configuration
```

### Key Services

- `CleanPairingService`: Handles pairing logic with dyad-based architecture
- `TaskService`: Manages task operations with pagination and caching
- `AuthService`: Authentication with rate limiting and security
- `RateLimitService`: Prevents brute force attacks
- `TaskCacheService`: Improves performance with local caching

### Development Workflow

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes and test
flutter test
flutter analyze

# Commit with conventional commits
git add .
git commit -m "feat: add your feature description"

# Push and create pull request
git push -u origin feature/your-feature-name
```

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/services/auth_service_test.dart

# Run integration tests
flutter test integration_test/
```

### Performance

The app includes several performance optimizations:
- **Task Caching**: Local caching reduces API calls
- **Pagination**: Loads tasks in pages for better performance
- **Rate Limiting**: Prevents abuse while maintaining responsiveness
- **Optimized Queries**: Efficient database queries with proper indexing

## 🔒 Security Features

- **Rate Limiting**: Prevents brute force attacks on authentication
- **Input Validation**: Comprehensive validation of all user inputs
- **Secure Authentication**: Uses Supabase Auth with Google OAuth
- **Row Level Security**: Database-level access control
- **Environment Variables**: Sensitive data stored securely

## 📚 Documentation

- [Design Document](DuoTask_Design_Document.md) - Detailed design specifications
- [Pairing System](PAIRING.md) - Pairing architecture and implementation
- [Setup Guide](SETUP_GUIDE.md) - Complete setup instructions
- [API Documentation](API_DOCUMENTATION.md) - Backend API reference
- [Architecture](docs/ARCHITECTURE.md) - System architecture overview

## 🚀 Deployment

### Web (PWA)

```bash
# Build for production
flutter build web --release

# Deploy to your hosting service
# The app is configured as a PWA with service worker support
```

### Mobile

```bash
# Build Android APK
flutter build apk --release

# Build iOS (requires macOS)
flutter build ios --release

# Build iOS with code signing
flutter build ios --release --codesign
```

### CI/CD

The project includes GitHub Actions for automated testing and building:
- **Automated Tests**: Runs on every push and pull request
- **Code Coverage**: Tracks test coverage with Codecov
- **Multi-platform Builds**: Tests Android, iOS, Web, and macOS builds

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and ensure tests pass
4. Commit your changes (`git commit -m 'feat: Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter format` to format code
- Add tests for new functionality
- Update documentation for API changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the docs folder for detailed guides
- **Issues**: Report bugs and feature requests on GitHub
- **Discussions**: Use GitHub Discussions for questions and ideas

## 🗺️ Roadmap

- [x] **Security Enhancements**: Rate limiting, input validation, secure authentication
- [x] **Performance Optimizations**: Caching, pagination, optimized queries
- [x] **Testing Infrastructure**: Unit, widget, and integration tests
- [x] **CI/CD Pipeline**: Automated testing and deployment
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
