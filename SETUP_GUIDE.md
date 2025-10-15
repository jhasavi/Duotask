# DuoTask Setup Guide

Complete setup instructions for DuoTask - from development to production deployment.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Development Setup](#development-setup)
3. [Supabase Configuration](#supabase-configuration)
4. [Firebase Setup](#firebase-setup)
5. [Email Branding](#email-branding)
6. [Database Schema](#database-schema)
7. [Environment Configuration](#environment-configuration)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)
10. [Troubleshooting](#troubleshooting)

## 🔧 Prerequisites

### Required Software
- **Flutter SDK** (3.0.0 or higher)
- **Dart SDK** (3.0.0 or higher)
- **Node.js** (16.0 or higher) - for Supabase CLI
- **Git** (latest version)

### Required Accounts
- **Supabase** account (free tier available)
- **Firebase** account (free tier available)
- **Google Cloud Console** (for OAuth)

### Platform-Specific Requirements
- **iOS**: Xcode 14+ (macOS only)
- **Android**: Android Studio + Android SDK
- **Web**: Chrome/Edge for development
- **macOS**: Xcode command line tools

## 🚀 Development Setup

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/duotask.git
cd duotask
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Install Supabase CLI
```bash
npm install -g supabase
```

### 4. Verify Flutter Installation
```bash
flutter doctor
```

## 🔐 Supabase Configuration

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Choose your organization
4. Enter project details:
   - **Name**: `duotask`
   - **Database Password**: Generate a strong password
   - **Region**: Choose closest to your users
5. Click "Create new project"

### 2. Get Project Credentials

1. Go to **Settings** > **API**
2. Copy the following values:
   - **Project URL** (e.g., `https://your-project.supabase.co`)
   - **Anon public key** (starts with `eyJ...`)

### 3. Link Local Project
```bash
# Login to Supabase
supabase login

# Link your project (replace with your project ref)
supabase link --project-ref your-project-ref
```

### 4. Deploy Database Schema
```bash
# Push the complete schema
supabase db push
```

This creates:
- `usr` table for user profiles
- `pair` table for pairing relationships  
- `tasks` table with personal/shared scope
- All necessary indexes and RLS policies
- Required functions and triggers

### 5. Configure Authentication

1. Go to **Authentication** > **Settings**
2. Configure **Site URL**: `http://localhost:3000` (for development)
3. Add **Redirect URLs**:
   - `http://localhost:3000/auth/callback`
   - `http://localhost:3000/`
   - `com.duotask.app://login-callback` (for mobile)

### 6. Enable Google OAuth

1. Go to **Authentication** > **Providers**
2. Enable **Google**
3. Add your Google OAuth credentials (see Google Cloud setup below)

## 🔥 Firebase Setup

### 1. Create Firebase Project

1. Go to [firebase.google.com](https://firebase.google.com)
2. Click "Create a project"
3. Enter project name: `duotask`
4. Enable Google Analytics (optional)
5. Choose analytics account
6. Click "Create project"

### 2. Add Android App

1. Click "Add app" > "Android"
2. Package name: `com.duotask.app`
3. App nickname: `DuoTask Android`
4. Download `google-services.json`
5. Place in `android/app/google-services.json`

### 3. Add iOS App

1. Click "Add app" > "iOS"
2. Bundle ID: `com.duotask.app`
3. App nickname: `DuoTask iOS`
4. Download `GoogleService-Info.plist`
5. Place in `ios/Runner/GoogleService-Info.plist`

### 4. Add Web App

1. Click "Add app" > "Web"
2. App nickname: `DuoTask Web`
3. Copy the Firebase config object

### 5. Configure Cloud Messaging

1. Go to **Project Settings** > **Cloud Messaging**
2. Generate a new server key
3. Copy the server key for Supabase configuration

## 📧 Email Branding

### 1. Deploy Email Function
```bash
supabase functions deploy auth-email-branding
```

### 2. Configure Custom Templates (Supabase Pro Required)

1. Go to **Authentication** > **Email Templates**
2. For each template type:
   - **Confirm signup**
   - **Reset password**
   - **Magic link**
3. Use the custom HTML from the function

### 3. Test Email Templates
```bash
# Test the function locally
supabase functions serve auth-email-branding

# Test with curl
curl -X POST http://localhost:54321/functions/v1/auth-email-branding \
  -H "Content-Type: application/json" \
  -d '{"type":"confirm_signup","data":{"confirmation_url":"https://example.com"}}'
```

## 🗄️ Database Schema

The app uses a clean dyad-based pairing system:

### Core Tables

#### `usr` - User Profiles
```sql
CREATE TABLE usr (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  pair_code TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `pair` - Pairing Relationships
```sql
CREATE TABLE pair (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID REFERENCES usr(id),
  user_b UUID REFERENCES usr(id),
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `tasks` - Task Management
```sql
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  scope TEXT DEFAULT 'personal', -- 'personal' or 'shared'
  creator_id UUID REFERENCES usr(id),
  owner_id UUID REFERENCES usr(id),
  pair_id UUID REFERENCES pair(id),
  status TEXT DEFAULT 'unclaimed',
  due_date TIMESTAMP WITH TIME ZONE,
  urgent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Key Features
- **Row Level Security (RLS)**: Ensures users only see their own data
- **Real-time subscriptions**: Live updates across devices
- **Automatic timestamps**: Created/updated tracking
- **Foreign key constraints**: Data integrity

## ⚙️ Environment Configuration

### 1. Create Environment File
```bash
cp env.example .env
```

### 2. Configure Variables
```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here

# Firebase Configuration
FIREBASE_PROJECT_ID=your_firebase_project_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id

# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# App Configuration
APP_ENV=development
DEBUG_MODE=true
LOG_LEVEL=debug

# Feature Flags
ENABLE_PUSH_NOTIFICATIONS=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

### 3. Platform-Specific Configuration

#### Android (`android/app/build.gradle`)
```gradle
android {
    defaultConfig {
        applicationId "com.duotask.app"
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.duotask.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.duotask.app</string>
        </array>
    </dict>
</array>
```

## 🧪 Testing

### 1. Run All Tests
```bash
flutter test
```

### 2. Run Specific Tests
```bash
# Widget tests
flutter test test/widgets/

# Integration tests
flutter test test/integration/

# Unit tests
flutter test test/unit/
```

### 3. Test Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 4. Manual Testing Checklist

- [ ] User registration and login
- [ ] Google OAuth sign-in
- [ ] Email confirmation flow
- [ ] Pairing with another user
- [ ] Creating personal tasks
- [ ] Creating shared tasks
- [ ] Task status changes
- [ ] Task reclaiming
- [ ] Real-time updates
- [ ] Push notifications
- [ ] Offline functionality

## 🚀 Production Deployment

### 1. Environment Preparation
```bash
# Update environment for production
APP_ENV=production
DEBUG_MODE=false
LOG_LEVEL=info
```

### 2. Build Applications

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

#### macOS
```bash
flutter build macos --release
```

### 3. Deploy to Stores

#### Google Play Store
1. Create developer account
2. Upload AAB file
3. Configure store listing
4. Submit for review

#### Apple App Store
1. Create developer account
2. Upload IPA file via Xcode
3. Configure App Store Connect
4. Submit for review

### 4. Web Deployment

#### Vercel
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel --prod
```

#### Netlify
```bash
# Build for web
flutter build web

# Deploy build/web folder
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Supabase Connection Errors
```bash
# Check environment variables
echo $SUPABASE_URL
echo $SUPABASE_ANON_KEY

# Test connection
curl -X GET "$SUPABASE_URL/rest/v1/" \
  -H "apikey: $SUPABASE_ANON_KEY"
```

#### 2. Flutter Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

#### 3. Authentication Issues
- Verify OAuth redirect URLs
- Check Supabase Auth settings
- Ensure email templates are configured

#### 4. Real-time Issues
- Verify RLS policies
- Check Supabase real-time settings
- Test with simple subscription

### Debug Commands

```bash
# Check Flutter installation
flutter doctor -v

# Check Supabase status
supabase status

# Check Firebase configuration
firebase projects:list

# Analyze code
flutter analyze

# Run with verbose logging
flutter run --verbose
```

### Getting Help

1. **Check logs**: Look for error messages in console
2. **Verify configuration**: Ensure all environment variables are set
3. **Test incrementally**: Start with basic auth, then add features
4. **Community support**: Check GitHub issues and discussions

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Supabase Documentation](https://supabase.com/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [DuoTask Design Document](DuoTask_Design_Document.md)
- [Pairing System Guide](PAIRING.md)

---

**Need help?** Contact support at support@duotask.app or create an issue on GitHub.
