# Changelog

All notable changes to DuoTask will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-06-25

### Added
- Nudge UI: long-press menu, send dialog, inbox screen, unread badge
- Real-time nudge notification snackbar
- Email digest preferences toggle in Settings
- Task owner initials badge on claimed bubbles
- Undo snackbar after task completion
- Today view filter chip
- Task search by title
- Pull-to-refresh on home screen
- Group task creation confirmation dialog
- Remember last Personal/Group visibility preference
- Smart task sorting (urgent → due date → recent)
- Offline banner Retry button
- GitHub Actions CI pipeline
- Email preferences service with Supabase integration
- `revertCompletion()` for undo support
- Unit tests for task sort/search utilities

### Fixed
- Test infrastructure: `.env.example` as asset, `assets/icons/` directory
- Widget test updated for current app structure
- Service error messages displayed to users

### Changed
- App version bumped to 1.2.0
- Long-press on tasks opens action sheet (Details / Nudge)

## [1.0.0] - 2025-10-28

### Added - Initial Release

#### Authentication
- Email/password authentication with Supabase
- Google OAuth integration (Web, iOS, Android)
- Magic link authentication (passwordless sign-in)
- Persistent sessions with automatic token refresh
- Password reset functionality
- Profile management (display name, avatar)

#### Task Management
- Create tasks with natural language input
  - Time parsing: "Grocery @6pm"
  - Date parsing: "Call mom tomorrow", "Clean tonight"
  - Urgency detection: "Urgent: Fix bug"
- Task status cycle: Unclaimed → Claimed → Completed
- Task priorities: Normal and Urgent
- Task recurrence: Daily and Weekly
- Due date and time scheduling
- Task descriptions and notes
- Personal and shared task types

#### Pairing System
- Generate unique 8-character pairing codes
- Accept pairing codes to connect with partner
- Real-time pairing status updates
- View partner profile information
- Unpair functionality with confirmation
- Automatic bi-directional pairing

#### User Interface
- Animated bubble task representation
  - Size changes based on status
  - Color coding for ownership and status
  - Smooth animations and transitions
- Material 3 design system
- Light and dark theme support (system preference)
- Responsive layout for all screen sizes
- Confetti celebration for completed tasks
- Segmented tab navigation (All, Active, Done)
- Quick task input with send button
- Long-press for task details

#### Notifications
- Local notifications setup
- Task reminders (1 hour before due)
- Partner activity notifications
- Daily summary notifications
- Configurable notification preferences
- FCM integration ready

#### Real-time Features
- WebSocket-based real-time synchronization
- Instant task updates across devices
- Live pairing status changes
- Automatic reconnection handling
- Offline support with sync on reconnect

#### Technical Features
- Provider state management
- Supabase backend integration
- PostgreSQL database with RLS
- Comprehensive error handling
- Environment-based configuration
- Cross-platform support (Web, iOS, Android, macOS)

#### Documentation
- Comprehensive README with feature overview
- Detailed SETUP guide with step-by-step instructions
- API documentation with code examples
- Inline code documentation
- Architecture documentation
- Contributing guidelines

#### Testing
- Unit tests for models
- Service layer tests
- Widget tests foundation
- Test coverage setup

### Technical Stack

- **Frontend**: Flutter 3.0+, Dart 3.0+
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage)
- **State Management**: Provider
- **Authentication**: Supabase Auth + Google OAuth
- **Notifications**: Flutter Local Notifications + FCM
- **UI**: Material 3 Design
- **Fonts**: Google Fonts (Inter)

### Security

- Row Level Security (RLS) policies on all tables
- Secure JWT token management
- OAuth 2.0 with PKCE flow
- Encrypted data transmission
- Input validation and sanitization

### Performance

- Optimized real-time subscriptions
- Efficient state management
- Lazy loading where appropriate
- Image caching
- Bundle size optimization

### Known Limitations

- Voice input not yet implemented (planned for v1.1)
- Calendar integration not yet implemented (planned for v1.1)
- Smart suggestions not yet implemented (planned for v1.2)
- Multi-user pairing (>2 users) not supported
- File attachments not yet supported
- In-app messaging not yet implemented

### Browser/Platform Support

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+
- ✅ iOS 12.0+
- ✅ Android 5.0+ (API 21+)
- ✅ macOS 10.14+

## [Unreleased]

### Planned for v1.1.0

- Voice input for task creation
- Calendar integration
- Task templates
- Enhanced task categories
- Emoji reactions to tasks
- Task comments

### Planned for v1.2.0

- Smart suggestions and nudges
- Advanced analytics
- Goal tracking
- Achievement system
- Multi-language support
- Enhanced dark mode

### Planned for v2.0.0

- Multi-user pairing (team mode)
- File attachments
- In-app messaging
- Advanced task filtering
- Export/import functionality
- API for third-party integrations

---

## Version History

- **1.0.0** - Initial release with core features
- **0.9.0** - Beta release for testing
- **0.5.0** - Alpha release with basic functionality
- **0.1.0** - Initial development version

---

**Note**: This project follows semantic versioning:
- **Major** version for incompatible API changes
- **Minor** version for new functionality in a backwards compatible manner
- **Patch** version for backwards compatible bug fixes
