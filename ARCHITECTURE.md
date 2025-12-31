# DuoTask - System Architecture

## Overview

DuoTask is a Flutter-based cross-platform task management application designed for partner collaboration. The system enables two users to pair together, create tasks, assign them, and track completion in real-time.

## Technology Stack

### Frontend
- **Framework**: Flutter 3.38.4
- **Language**: Dart
- **Platforms**: Web (production), iOS, Android, macOS, Linux, Windows
- **State Management**: Provider pattern
- **UI Components**: Material Design 3

### Backend
- **Database**: PostgreSQL (via Supabase)
- **Authentication**: Supabase Auth with PKCE flow
- **Real-time**: Supabase Realtime subscriptions
- **Storage**: Supabase Storage (for avatars, if needed)

### Deployment
- **Web Hosting**: Vercel
- **Database Hosting**: Supabase Cloud
- **Domain**: duotask.namasteneedham.com (configured)

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Web Application                   │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Auth    │  │  Home    │  │ Pairing  │  │ Settings │   │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │              │          │
│  ┌────┴─────────────┴──────────────┴──────────────┴─────┐  │
│  │              Provider State Management                │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │  │
│  │  │   Auth   │ │   Task   │ │  Pairing │            │  │
│  │  │  Service │ │  Service │ │  Service │            │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘            │  │
│  └───────┼────────────┼─────────────┼──────────────────┘  │
└──────────┼────────────┼─────────────┼─────────────────────┘
           │            │             │
           └────────────┴─────────────┘
                        │
           ┌────────────┴──────────────┐
           │    Supabase Client API     │
           │  (REST + Realtime + Auth)  │
           └────────────┬───────────────┘
                        │
        ┌───────────────┴──────────────────┐
        │     Supabase Cloud Platform      │
        │                                   │
        │  ┌──────────────────────────┐   │
        │  │   PostgreSQL Database    │   │
        │  │  ┌────────┐ ┌─────────┐  │   │
        │  │  │ users  │ │  tasks  │  │   │
        │  │  └────────┘ └─────────┘  │   │
        │  │  ┌──────────┐            │   │
        │  │  │ pairings │            │   │
        │  │  └──────────┘            │   │
        │  └──────────────────────────┘   │
        │                                   │
        │  ┌──────────────────────────┐   │
        │  │   Supabase Auth          │   │
        │  │  - Email/Password        │   │
        │  │  - Google OAuth          │   │
        │  │  - PKCE Flow             │   │
        │  └──────────────────────────┘   │
        │                                   │
        │  ┌──────────────────────────┐   │
        │  │   Realtime Subscriptions │   │
        │  │  - Task updates          │   │
        │  │  - Pairing changes       │   │
        │  └──────────────────────────┘   │
        └───────────────────────────────────┘
```

## Database Schema

### Tables

#### `users`
Stores user profiles and pairing information.

```sql
- id: UUID (PK, FK to auth.users)
- email: TEXT (unique)
- display_name: TEXT
- avatar_url: TEXT
- pairing_code: TEXT (unique, auto-generated)
- paired_with_id: UUID (FK to users)
- paired_with_name: TEXT
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

#### `tasks`
Stores all tasks created by users.

```sql
- id: UUID (PK)
- title: TEXT
- description: TEXT
- created_by_id: UUID (FK to users)
- assigned_to_id: UUID (FK to users)
- claimed_by_id: UUID (FK to users)
- status: TEXT (unclaimed|claimed|completed)
- priority: TEXT (normal|urgent)
- recurrence: TEXT (none|daily|weekly)
- due_date: TIMESTAMPTZ
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
- completed_at: TIMESTAMPTZ
- is_personal: BOOLEAN
```

#### `pairings`
Manages pairing requests and active partnerships.

```sql
- id: UUID (PK)
- requester_id: UUID (FK to users)
- recipient_id: UUID (FK to users, nullable)
- pairing_code: TEXT (8-char alphanumeric)
- status: TEXT (pending|active|rejected|cancelled)
- created_at: TIMESTAMPTZ
- accepted_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### Database Triggers

#### `on_auth_user_created`
Automatically creates a user profile in `public.users` when a new user signs up via Supabase Auth.

**Function**: `create_user_profile()`
- Extracts display_name from user metadata
- Generates unique 8-character pairing code
- Creates user profile with collision-safe code generation

### Row Level Security (RLS)

All tables have RLS enabled with policies:

**Users Table**:
- Users can view all profiles (read-only)
- Users can update only their own profile

**Tasks Table**:
- Users can view tasks they created or are assigned to
- Users can insert tasks as themselves
- Users can update tasks they created or are assigned to
- Users can delete tasks they created

**Pairings Table**:
- Users can view their own pairings OR any pending pairings (for code search)
- Users can create pairing requests as themselves
- Users can update pairings they're involved in
- Recipients can accept pairings by code (special policy)

## Service Layer Architecture

### AuthService
Manages user authentication and session state.

**Responsibilities**:
- Email/password sign-in and sign-up
- Google OAuth authentication
- Magic link authentication
- Session management
- User profile loading
- Auth state change listeners

**Key Features**:
- PKCE flow for web security
- Automatic profile creation via trigger
- Real-time auth state updates
- Error handling with user-friendly messages

### TaskService
Manages task CRUD operations and real-time updates.

**Responsibilities**:
- Create, read, update, delete tasks
- Task assignment and claiming
- Task completion tracking
- Real-time task subscriptions
- Task filtering by status

**Business Logic**:
- Tasks can be unclaimed, claimed, or completed
- Only assigned user can claim a task
- Task creator or claimer can complete it
- Personal tasks (is_personal=true) are single-user
- Shared tasks visible to both paired users

### PairingService
Handles partner pairing workflow.

**Responsibilities**:
- Generate unique pairing codes
- Accept pairing codes
- Manage pairing status
- Load partner information
- Real-time pairing updates
- Unpair functionality

**Pairing Flow**:
1. User A generates a pairing code → Creates pending pairing
2. User B enters User A's code → Queries by code (RLS allows)
3. System validates: code exists, status=pending, not self-pairing
4. System updates: sets recipient_id, status=active, accepted_at
5. Both users receive real-time update → See each other as paired

## Real-time Architecture

### Subscriptions

**Task Updates**:
```dart
channel('tasks:user_id')
  .onPostgresChanges(
    schema: 'public',
    table: 'tasks',
    filter: 'created_by_id=eq.user_id OR assigned_to_id=eq.user_id'
  )
```

**Pairing Updates**:
```dart
channel('pairings:user_id')
  .onPostgresChanges(
    schema: 'public',
    table: 'pairings',
    filter: 'requester_id=eq.user_id OR recipient_id=eq.user_id'
  )
```

### State Management Flow

```
User Action → Service Method → Supabase API
                                    ↓
                              Database Update
                                    ↓
                            Realtime Event Fired
                                    ↓
                          Service Listener Receives
                                    ↓
                        Service Updates Local State
                                    ↓
                            notifyListeners() called
                                    ↓
                        Consumer Widgets Rebuild
                                    ↓
                              UI Updates
```

## Security Model

### Authentication
- **Email verification**: Optional (currently disabled for testing)
- **Password requirements**: Minimum 6 characters
- **OAuth providers**: Google (configured)
- **Session management**: JWT tokens with auto-refresh

### Authorization (RLS Policies)
- Row-level security enforced at database level
- Policies checked on every query
- Users can only access data they own or are paired with
- Special policy for searching pending pairing codes

### Data Privacy
- Users can only see their own data and paired partner's shared data
- Personal tasks (is_personal=true) are never shared
- Pairing codes expire when accepted or cancelled
- No cross-user data leakage via RLS

## Deployment Architecture

### Production Environment

**Web Application**:
- Hosted on: Vercel
- Build: Flutter web --release
- Deploy: Direct upload (no Git integration)
- URL: https://duotask-[hash].vercel.app

**Database**:
- Hosted on: Supabase Cloud
- Region: Auto-selected by Supabase
- Backups: Managed by Supabase
- Connection: PostgreSQL over SSL

**Configuration**:
- Environment variables in `.env` file
- Supabase URL and keys
- Google OAuth credentials (in Supabase dashboard)

### Build Process

```bash
1. flutter build web --release
2. npx vercel deploy --prod --yes
3. Vercel uploads build/web/* to CDN
4. New deployment URL generated
```

### Continuous Deployment

Currently **manual** - deploy script runs locally:
- No GitHub integration
- No auto-deploy on commit
- Developer triggers deployment explicitly

**Future**: Can enable Vercel GitHub integration for auto-deploy.

## Scalability Considerations

### Current Limitations
- Pairing is 1-to-1 only (one partner at a time)
- No team/group support
- Single database instance

### Scaling Strategies (Future)
1. **Database**: Supabase auto-scales, can upgrade plan
2. **Real-time**: Connection pooling handled by Supabase
3. **Frontend**: Vercel CDN handles global distribution
4. **Caching**: Add service worker for offline capability

## Error Handling

### Network Errors
- Catch `SocketException` for offline scenarios
- Display user-friendly "No internet" messages
- Retry logic in services

### Database Errors
- Catch `PostgrestException` for DB errors
- Log detailed errors in debug mode
- Display generic errors to users
- RLS violations show as "not found" (by design)

### Auth Errors
- Catch `AuthException` for login failures
- Map error codes to friendly messages
- Handle email confirmation flow
- Auto sign-in after sign-up when possible

## Performance Optimizations

### Database
- Indexes on foreign keys (requester_id, recipient_id, etc.)
- Indexes on frequently queried columns (status, pairing_code)
- Efficient RLS policies (avoid table scans)

### Frontend
- Provider pattern for minimal rebuilds
- Lazy loading of partner data
- Real-time subscriptions only for active data
- Tree-shaking icons (reduces bundle size by 99%)

### Network
- Connection pooling via Supabase
- JWT token caching
- Minimal API calls (leverage real-time instead)

## Monitoring and Debugging

### Production Monitoring
- Supabase Dashboard: Auth logs, DB queries, API usage
- Vercel Dashboard: Deployment status, function logs
- Browser Console: Flutter debug logs (kDebugMode)

### Debug Tools
- Flutter DevTools for performance profiling
- Supabase SQL Editor for direct DB queries
- PostgreSQL logs for RLS policy debugging

## Future Enhancements

### Planned Features
1. **Notifications**: Push notifications for task assignments
2. **Chat**: In-app messaging between partners
3. **Analytics**: Task completion metrics and insights
4. **Mobile Apps**: Native iOS and Android builds
5. **File Attachments**: Add photos to tasks
6. **Task Templates**: Reusable task patterns
7. **Multi-partner**: Support more than one partner

### Technical Debt
- Add comprehensive error logging service
- Implement offline mode with local storage
- Add E2E test suite (Cypress or Playwright)
- Set up CI/CD pipeline
- Add performance monitoring (Firebase, Sentry)

---

**Version**: 1.0.0  
**Last Updated**: December 23, 2025  
**Maintained By**: Sanjeev Jha
