# DuoTask - Developer Guide

## Development Setup

### Prerequisites

- **Flutter SDK**: 3.38.4 or higher
- **Dart SDK**: (included with Flutter)
- **IDE**: VS Code with Flutter/Dart extensions (recommended)
- **Node.js**: 20+ (for Vercel CLI)
- **PostgreSQL Client**: For database management (optional)
- **Git**: For version control

### Clone and Setup

```bash
# Clone repository (if using Git)
git clone <repository-url>
cd duotask

# Install Flutter dependencies
flutter pub get

# Copy environment template
cp .env.example .env

# Edit .env with your Supabase credentials
nano .env
```

### Environment Variables

Create a `.env` file in the project root:

```env
SUPABASE_URL=https://xqhlnuvpogiolzkucupt.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
GOOGLE_CLIENT_ID=931322985925-no55j5aq0hnuc1afeqn2sjhb1ib03up4.apps.googleusercontent.com
```

⚠️ **Never commit `.env` to version control!**

---

## Project Structure

```
duotask/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── config/
│   │   ├── app_config.dart       # Environment configuration
│   │   ├── theme.dart            # App theme and colors
│   │   └── constants.dart        # App constants
│   ├── models/
│   │   ├── user.dart             # User model
│   │   ├── task.dart             # Task model
│   │   └── pairing.dart          # Pairing model
│   ├── services/
│   │   ├── auth_service.dart     # Authentication logic
│   │   ├── task_service.dart     # Task CRUD operations
│   │   ├── pairing_service.dart  # Pairing workflow
│   │   ├── notification_service.dart
│   │   ├── preferences_service.dart
│   │   └── connectivity_service.dart
│   ├── screens/
│   │   ├── auth_screen.dart      # Login/Signup
│   │   ├── home_screen.dart      # Main dashboard
│   │   ├── pairing_screen.dart   # Partner pairing
│   │   ├── task_detail_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   └── (reusable UI components)
│   └── utils/
│       └── haptic_helper.dart    # Haptic feedback
├── assets/
│   ├── images/                   # Image assets
│   ├── fonts/                    # Custom fonts
│   └── docs/                     # Privacy policy, terms
├── test/
│   ├── unit/                     # Unit tests
│   └── services/                 # Service tests
├── supabase/
│   └── schema.sql                # Database schema
├── pubspec.yaml                  # Flutter dependencies
└── vercel.json                   # Vercel configuration
```

---

## Running the App

### Web (Development)

```bash
# Run in Chrome
flutter run -d chrome

# Run with hot reload
flutter run -d web-server --web-port 8080
```

### Web (Production Build)

```bash
# Build optimized web bundle
flutter build web --release

# Output: build/web/
```

### Mobile (iOS - requires macOS)

```bash
flutter run -d ios
```

### Mobile (Android)

```bash
flutter run -d android
```

---

## Database Development

### Setup Supabase

1. Create a Supabase project at https://supabase.com
2. Navigate to SQL Editor
3. Run the schema from `supabase/schema.sql`

### Schema Changes

When modifying the database:

1. **Update `supabase/schema.sql`**
2. **Run SQL in Supabase SQL Editor**
3. **Update Dart models** in `lib/models/`
4. **Update services** if query logic changes

### Testing Database Locally

```bash
# Connect to Supabase database
PGPASSWORD=<your-db-password> psql "postgresql://postgres@db.<project-ref>.supabase.co:5432/postgres"

# Run queries
SELECT * FROM users;
SELECT * FROM tasks WHERE status = 'unclaimed';
```

### Common Database Tasks

```sql
-- Check RLS policies
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public';

-- View trigger functions
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public';

-- Test pairing code generation
SELECT public.generate_pairing_code();
```

---

## Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/task-tags

# Make changes
# ... code ...

# Test locally
flutter run -d chrome

# Build and test
flutter build web --release

# Commit changes
git add .
git commit -m "Add task tags feature"

# Push branch
git push origin feature/task-tags
```

### 2. Code Style

**Dart Linting**: Configured in `analysis_options.yaml`

```bash
# Run analyzer
flutter analyze

# Format code
dart format lib/

# Fix linting issues
dart fix --apply
```

**Best Practices**:
- Use `const` constructors where possible
- Prefer `final` over `var`
- Add comments for complex logic
- Use meaningful variable names
- Follow Flutter widget naming conventions

### 3. State Management

**Provider Pattern**:

```dart
// 1. Service extends ChangeNotifier
class TaskService extends ChangeNotifier {
  List<Task> _tasks = [];
  
  void updateTask(Task task) {
    // ... update logic
    notifyListeners();  // Trigger UI rebuild
  }
}

// 2. Wrap app with Provider
MultiProvider(
  providers: [
    ChangeNotifierProvider<TaskService>(
      create: (_) => TaskService(...),
    ),
  ],
  child: MyApp(),
)

// 3. Consume in widgets
Consumer<TaskService>(
  builder: (context, taskService, child) {
    return Text('Tasks: ${taskService.tasks.length}');
  },
)
```

---

## Testing

### Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/auth_service_test.dart

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Writing Tests

```dart
// test/services/task_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('TaskService', () {
    test('creates task successfully', () async {
      // Arrange
      final service = TaskService(mockSupabase);
      
      // Act
      final result = await service.createTask(...);
      
      // Assert
      expect(result, isTrue);
    });
  });
}
```

### Integration Tests

```bash
# Run integration tests (not yet implemented)
flutter test integration_test/
```

---

## Deployment

### Deploy to Vercel

```bash
# Install Vercel CLI (once)
npm install -g vercel

# Login to Vercel (once)
vercel login

# Build Flutter web
flutter build web --release

# Deploy to production
npx vercel deploy --prod --yes

# Output: https://duotask-[hash].vercel.app
```

### Automated Deployment Script

```bash
# Use the convenience script
./deploy_production.sh
```

Script does:
1. Builds Flutter web release
2. Deploys to Vercel production
3. Shows deployment URL

---

## Debugging

### Flutter DevTools

```bash
# Run app
flutter run -d chrome

# Open DevTools (shown in terminal output)
# Provides: Widget Inspector, Performance, Network, Debugger
```

### Console Logging

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug message: $variable');
}
```

### Supabase Logs

View real-time logs:
1. Supabase Dashboard → Logs
2. Filter by: Auth, Database, Realtime
3. Check for errors, slow queries

### Browser Console

Web app debugging:
1. Open DevTools (F12)
2. Console tab shows Flutter print statements
3. Network tab shows API calls
4. Application tab shows local storage

---

## Common Issues

### Issue: "Error while trying to use icon"
**Cause**: Missing icon files  
**Fix**: Ensure `assets/icons/` contains all required icons

### Issue: "_flutter is not defined"
**Cause**: Flutter bootstrap error  
**Fix**: Clear browser cache and rebuild

### Issue: "Invalid login credentials"
**Cause**: Wrong email/password or database issue  
**Fix**: Check Supabase dashboard → Authentication → Users

### Issue: RLS policy violation
**Cause**: User doesn't have permission to access data  
**Fix**: Check RLS policies in database, ensure user is authenticated

### Issue: Real-time not working
**Cause**: Subscription not set up or channel conflict  
**Fix**: Check Supabase Dashboard → Realtime for active connections

---

## Performance Optimization

### Build Optimization

```bash
# Web build with optimization flags
flutter build web --release --web-renderer html

# Analyze bundle size
flutter build web --release --analyze-size

# Skip tree-shaking (if icons missing)
flutter build web --release --no-tree-shake-icons
```

### Code Optimization

**Lazy Loading**:
```dart
// Don't load partner data until needed
if (needsPartnerData) {
  await _loadPartner();
}
```

**Efficient Queries**:
```dart
// Bad: Load all tasks then filter
final allTasks = await supabase.from('tasks').select();
final myTasks = allTasks.where((t) => t.assignedTo == userId);

// Good: Filter in database
final myTasks = await supabase
  .from('tasks')
  .select()
  .eq('assigned_to_id', userId);
```

**Minimize Rebuilds**:
```dart
// Use const constructors
const Text('Hello');

// Use keys for list items
ListView.builder(
  itemBuilder: (context, index) {
    return TaskCard(key: ValueKey(task.id), task: task);
  },
)
```

---

## Security Best Practices

### Never Expose Secrets

```dart
// ❌ BAD: Hardcoded keys
final supabaseUrl = 'https://xxx.supabase.co';

// ✅ GOOD: Use environment variables
final supabaseUrl = AppConfig.supabaseUrl;
```

### Validate User Input

```dart
// Validate email format
if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
  throw 'Invalid email';
}

// Sanitize user content (prevent XSS)
final sanitized = HtmlEscape().convert(userInput);
```

### Use HTTPS Only

```dart
// Supabase and Vercel provide HTTPS by default
// Never downgrade to HTTP in production
```

### Row Level Security (RLS)

Always enable RLS and test policies:

```sql
-- Enable RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Test policy as user
SET ROLE authenticated;
SET request.jwt.claim.sub = 'user-uuid';
SELECT * FROM tasks;  -- Should only show their tasks
```

---

## Contributing Guidelines

### Code Review Checklist

Before submitting code:

- [ ] Code follows Dart style guide
- [ ] No console.log or print statements in production
- [ ] All tests pass
- [ ] No linting errors
- [ ] Meaningful commit messages
- [ ] Updated documentation (if API changed)
- [ ] Tested on web and mobile (if applicable)

### Commit Message Format

```
type(scope): short description

Longer description if needed.

Fixes: #123
```

**Types**: feat, fix, docs, style, refactor, test, chore

**Example**:
```
feat(tasks): add task tags feature

- Add tags field to Task model
- Update task creation UI
- Add tag filtering

Fixes: #45
```

---

## Resources

### Official Documentation
- **Flutter**: https://docs.flutter.dev
- **Dart**: https://dart.dev/guides
- **Supabase**: https://supabase.com/docs
- **Provider**: https://pub.dev/packages/provider

### Community
- **Flutter Discord**: https://discord.gg/flutter
- **Stack Overflow**: Tag `flutter`
- **Flutter Dev**: https://groups.google.com/g/flutter-dev

### Tools
- **Dart Pad**: https://dartpad.dev (online Dart editor)
- **FlutterFire**: https://firebase.flutter.dev (if using Firebase)
- **DevTools**: Built into Flutter SDK

---

## Roadmap

### Version 1.1 (Q1 2026)
- [ ] Push notifications
- [ ] Mobile apps (iOS/Android)
- [ ] Offline mode
- [ ] Task templates

### Version 1.2 (Q2 2026)
- [ ] In-app messaging
- [ ] File attachments
- [ ] Task analytics
- [ ] Export tasks

### Version 2.0 (Q3 2026)
- [ ] Multi-partner support
- [ ] Team features
- [ ] Advanced filtering
- [ ] Custom themes

---

**Questions?** Open an issue or contact the maintainer.

**Version**: 1.0.0  
**Last Updated**: December 23, 2025
