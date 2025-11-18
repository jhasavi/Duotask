# DuoTask Setup Guide# DuoTask Setup Guide



## Quick SetupThis guide will walk you through setting up DuoTask from scratch.



The project is already configured and ready to run. All environment variables are set in `.env` and the database schema is ready.## Table of Contents

1. [Prerequisites](#prerequisites)

### 1. Install Dependencies2. [Supabase Setup](#supabase-setup)

```bash3. [Google OAuth Setup](#google-oauth-setup)

flutter pub get4. [Local Development Setup](#local-development-setup)

```5. [Testing](#testing)

6. [Deployment](#deployment)

### 2. Test All Platforms

```bash## Prerequisites

./test_all_platforms.sh

```Before you begin, ensure you have the following installed:



That's it! The script will handle launching all platforms and provide testing instructions.- **Flutter SDK** 3.0.0 or higher

  ```bash

## Manual Setup (if needed)  flutter --version

  ```

### Environment Configuration

The `.env` file contains all necessary configuration:- **Dart SDK** 3.0.0 or higher (comes with Flutter)

- ✅ Supabase URL and API key

- ✅ Google OAuth client IDs for all platforms- **Git**

- ✅ App configuration  ```bash

  git --version

### Database Setup  ```

- ✅ Supabase project is configured

- ✅ Database schema is applied- **VS Code or Android Studio** (recommended IDEs)

- ✅ Row Level Security (RLS) policies are set

- ✅ Real-time subscriptions are enabled- **Chrome** (for web development)



### Authentication Setup- **Xcode** (for iOS development, macOS only)

- ✅ Google OAuth is configured for Web, iOS, and Android

- ✅ Email/password authentication is enabled- **Android Studio** (for Android development)

- ✅ Magic link authentication is available

## Supabase Setup

## Platform Requirements

### 1. Create a Supabase Project

### Web

- Chrome browser (recommended)1. Go to [supabase.com](https://supabase.com) and sign up/sign in

- No additional setup required2. Click "New Project"

3. Fill in the project details:

### iOS   - **Name**: DuoTask

- macOS with Xcode installed   - **Database Password**: Choose a strong password

- iOS Simulator or physical device   - **Region**: Select the closest region to you

- Apple Developer account (for device testing)4. Click "Create new project" and wait for it to initialize (2-3 minutes)



### Android### 2. Get Your API Keys

- Android Studio installed

- Android SDK and emulator configured1. In your Supabase project dashboard, go to **Settings** → **API**

- Or physical Android device with USB debugging enabled2. Copy the following:

   - **Project URL**: `https://xxxxx.supabase.co`

## Testing Checklist   - **Anon (public) key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`



1. **Authentication**### 3. Set Up the Database Schema

   - [ ] Register new account

   - [ ] Sign in with Google1. Go to **SQL Editor** in your Supabase dashboard

   - [ ] Sign in with email/password2. Click "New Query"

3. Copy the contents of `supabase/schema.sql` from the project

2. **Pairing**4. Paste it into the SQL editor

   - [ ] Generate pairing code5. Click "Run" to execute the schema

   - [ ] Join using pairing code

   - [ ] Verify both users see shared tasksThis will create:

- `users` table

3. **Task Management**- `tasks` table

   - [ ] Create new tasks- `pairings` table

   - [ ] Claim tasks (tap to cycle: unclaimed → claimed → completed)- All necessary indexes

   - [ ] Set task priority (normal/urgent)- Row Level Security (RLS) policies

   - [ ] Set due dates- Real-time subscriptions

   - [ ] Create recurring tasks- Triggers for automatic updates



4. **Real-time Sync**### 4. Configure Authentication

   - [ ] Task changes appear instantly on partner's device

   - [ ] Status changes sync across platforms1. Go to **Authentication** → **Settings**

   - [ ] Notifications work properly2. Under **Site URL**, add:

   - Development: `http://localhost:5000`

5. **Multi-Platform**   - Production: `https://your-domain.com`

   - [ ] Web app works in Chrome

   - [ ] iOS app runs on simulator/device3. Under **Redirect URLs**, add:

   - [ ] Android app runs on emulator/device   - `http://localhost:5000`

   - [ ] All platforms sync properly   - `http://localhost:5000/`

   - `https://your-domain.com` (production)

## Troubleshooting

### 5. Enable Google OAuth

### Flutter Issues

```bash1. In Supabase, go to **Authentication** → **Providers**

# Clean and rebuild2. Find **Google** and enable it

flutter clean3. Leave it for now - we'll add the credentials after setting up Google Cloud

flutter pub get

```## Google OAuth Setup



### iOS Issues### 1. Create a Google Cloud Project

```bash

# Clean iOS build1. Go to [Google Cloud Console](https://console.cloud.google.com)

cd ios2. Click "Select a project" → "New Project"

rm -rf Pods Podfile.lock3. **Project name**: DuoTask

cd ..4. Click "Create"

flutter clean

flutter pub get### 2. Enable Required APIs

cd ios

pod install1. In the search bar, search for "Google+ API"

cd ..2. Click "Enable"

```3. Repeat for "Google People API"



### Android Issues### 3. Configure OAuth Consent Screen

```bash

# Clean Android build1. Go to **APIs & Services** → **OAuth consent screen**

cd android2. Select **External** user type

./gradlew clean3. Click "Create"

cd ..4. Fill in the required information:

flutter clean   - **App name**: DuoTask

flutter pub get   - **User support email**: your-email@example.com

```   - **Developer contact**: your-email@example.com

5. Click "Save and Continue"

### Database Issues6. Click "Add or Remove Scopes"

The database schema is at `supabase/schema.sql`. If you need to reset, run this in your Supabase SQL Editor.   - Add: `email`, `profile`, `openid`

7. Click "Save and Continue"

## Support8. Add test users if needed

9. Click "Save and Continue"

- Check the main README.md for detailed feature documentation

- Run `./test_all_platforms.sh` for guided testing### 4. Create OAuth Credentials

- Review error logs for specific issues
#### Web Application

1. Go to **APIs & Services** → **Credentials**
2. Click "Create Credentials" → "OAuth client ID"
3. **Application type**: Web application
4. **Name**: DuoTask Web
5. **Authorized JavaScript origins**:
   - `http://localhost:5000`
   - `https://your-supabase-url.supabase.co`
6. **Authorized redirect URIs**:
   - `http://localhost:5000`
   - `https://your-supabase-url.supabase.co/auth/v1/callback`
7. Click "Create"
8. **Copy the Client ID and Client Secret**

#### iOS Application (if deploying to iOS)

1. Create another OAuth client ID
2. **Application type**: iOS
3. **Name**: DuoTask iOS
4. **Bundle ID**: com.yourcompany.duotask
5. Click "Create"
6. **Copy the Client ID**

#### Android Application (if deploying to Android)

1. Create another OAuth client ID
2. **Application type**: Android
3. **Name**: DuoTask Android
4. **Package name**: com.yourcompany.duotask
5. **SHA-1 certificate fingerprint**: Get from your keystore
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
6. Click "Create"
7. **Copy the Client ID**

### 5. Add Google Credentials to Supabase

1. Go back to Supabase **Authentication** → **Providers** → **Google**
2. Paste your **Web Client ID** and **Web Client Secret**
3. Save

## Local Development Setup

### 1. Clone the Project

```bash
cd duotask
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your credentials:
   ```env
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=your_anon_key_here
   GOOGLE_WEB_CLIENT_ID=your_web_client_id
   GOOGLE_IOS_CLIENT_ID=your_ios_client_id
   GOOGLE_ANDROID_CLIENT_ID=your_android_client_id
   APP_NAME=DuoTask
   APP_VERSION=1.0.0
   DEBUG_MODE=true
   ```

### 4. Run the App

#### Web
```bash
flutter run -d chrome --web-port 5000
```

#### iOS Simulator
```bash
flutter run -d ios
```

#### Android Emulator
```bash
flutter run -d android
```

## Testing

### Run All Tests

```bash
flutter test
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### View Coverage Report

```bash
# Install lcov (macOS)
brew install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

## Deployment

### Web Deployment (Vercel)

1. **Build the web app**:
   ```bash
   flutter build web
   ```

2. **Install Vercel CLI**:
   ```bash
   npm i -g vercel
   ```

3. **Deploy**:
   ```bash
   cd build/web
   vercel --prod
   ```

4. **Update redirect URLs**:
   - Add your Vercel domain to Supabase redirect URLs
   - Add your Vercel domain to Google OAuth authorized origins

### iOS Deployment

1. **Update bundle identifier** in `ios/Runner.xcodeproj`

2. **Build for release**:
   ```bash
   flutter build ios --release
   ```

3. **Open in Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```

4. **Archive and upload** using Xcode Organizer

### Android Deployment

1. **Create a keystore**:
   ```bash
   keytool -genkey -v -keystore ~/duotask-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias duotask
   ```

2. **Configure signing** in `android/app/build.gradle`

3. **Build app bundle**:
   ```bash
   flutter build appbundle --release
   ```

4. **Upload to Google Play Console**

## Troubleshooting

### Common Issues

1. **"No Firebase App" error**
   - Make sure you've added `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

2. **OAuth redirect not working**
   - Verify all redirect URLs are correctly configured
   - Check browser console for errors
   - Ensure Supabase project URL matches

3. **Database permission errors**
   - Check RLS policies in Supabase
   - Verify user is authenticated
   - Check table permissions

4. **Build errors**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Check Flutter and Dart SDK versions

### Getting Help

- Check the [README](README.md) for more information
- Review Supabase documentation
- Check Flutter documentation
- Open an issue on GitHub

## Next Steps

After setup is complete:

1. ✅ Test authentication (email/password and Google OAuth)
2. ✅ Create a pairing with another user
3. ✅ Add some tasks and test the bubble interface
4. ✅ Test real-time synchronization
5. ✅ Enable notifications and test reminders
6. ✅ Customize theme colors in `lib/config/theme.dart`
7. ✅ Deploy to your preferred platform

**Congratulations! Your DuoTask app is now set up and ready to use!** 🎉
