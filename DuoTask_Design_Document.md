# DuoTask - Design Document & Feature Specification

## 📋 Executive Summary

**DuoTask** is a mobile application designed for sharing and managing simple daily tasks between two people — like spouses, roommates, or co-workers. The app focuses on simplicity, real-time collaboration, and seamless task management through an intuitive bubble-based interface.

### 🎯 Core Mission
To simplify shared task management between two people by providing a clean, distraction-free interface that encourages collaboration and accountability.

---

## 🏗️ Architecture Overview

### Technology Stack
- **Frontend**: Flutter (Cross-platform mobile app)
- **Backend**: Supabase (PostgreSQL + Real-time subscriptions)
- **Authentication**: Supabase Auth + Google OAuth
- **Notifications**: Firebase Cloud Messaging + Local Notifications
- **Database**: PostgreSQL with Row Level Security (RLS)

### Platform Support
- ✅ iOS (iPhone/iPad)
- ✅ Android
- ✅ Web (Progressive Web App)
- ✅ macOS (Desktop app)

---

## 🎨 Design Philosophy

### Visual Design
- **Minimalist Interface**: Clean, uncluttered design inspired by Venmo and modern task managers
- **Bubble Metaphor**: Tasks represented as floating bubbles with dynamic sizing based on status and urgency
- **Color Coding**: Intuitive color system for task status and categories
- **Responsive Layout**: Adapts to different screen sizes and orientations

### User Experience Principles
1. **Simplicity First**: One-tap actions for common tasks
2. **Visual Hierarchy**: Important tasks are larger and more prominent
3. **Real-time Feedback**: Immediate visual updates for all actions
4. **Intuitive Navigation**: Minimal taps to complete any action
5. **Accessibility**: Support for screen readers and high contrast modes

---

## 🔐 Authentication & Security

### Authentication Methods
1. **Email/Password**: Traditional signup and login
2. **Google OAuth**: One-tap sign-in with Google accounts
3. **Apple Sign-In**: iOS-specific authentication (planned)

### Security Features
- **Row Level Security (RLS)**: Database-level access control
- **JWT Tokens**: Secure session management
- **Encrypted Data**: All sensitive data encrypted in transit and at rest
- **Privacy-First**: Minimal data collection, user-controlled sharing

---

## 👥 User Management & Pairing

### User Profile
- **Unique User ID**: UUID-based identification
- **Display Name**: User-friendly name for pairing
- **Pair Code**: Short, shareable code for easy pairing
- **Last Active**: Real-time activity tracking
- **FCM Token**: Push notification delivery

### Pairing System
The app uses a sophisticated pairing mechanism that supports multiple pairing methods:

#### 1. **Code-Based Pairing**
- Users can share their unique pair code
- Supports both short codes (8 characters) and full UUIDs
- Real-time validation and instant pairing

#### 2. **QR Code Pairing**
- Generate QR codes containing user identification
- Scan QR codes to instantly pair with partners
- Camera integration for easy scanning

#### 3. **SMS Invitation**
- Send invitation links via SMS
- Deep linking support for seamless onboarding
- Automatic pairing upon invitation acceptance

#### 4. **Pair Management**
- **Pair Status Display**: Shows current pairing status
- **Partner Activity**: Real-time last active timestamps
- **Unpair Functionality**: Easy separation with task archiving
- **Pair History**: Track previous partnerships (Pro feature)

---

## 📝 Task Management System

### Task Structure
```sql
tasks {
  id: UUID (Primary Key)
  title: String (1-50 characters)
  status: Enum ('unclaimed', 'claimed', 'done')
  owner_id: UUID (Creator)
  pair_id: String (Pair identifier)
  repeat: Boolean (Repeating tasks)
  due_date: DateTime (Optional)
  color: String (Visual category)
  created_at: DateTime
  updated_at: DateTime
}
```

### Task Lifecycle
1. **Creation**: User creates task with title and optional metadata
2. **Unclaimed**: Task available for claiming by either partner
3. **Claimed**: Task taken by one partner, in progress
4. **Completed**: Task marked as done with undo option
5. **Archived**: Completed tasks moved to archive (Pro feature)

### Task Features

#### Core Features
- **Simple Creation**: One-tap task creation with smart defaults
- **Status Management**: Visual status indicators (bubble size/color)
- **Claiming System**: Tap to claim unclaimed tasks
- **Completion Tracking**: Mark tasks as done with undo functionality
- **Repeating Tasks**: Automatic recreation of recurring tasks

#### Advanced Features (Pro)
- **Due Dates**: Set deadlines with visual urgency indicators
- **Task Categories**: Color-coded organization system
- **Private Tasks**: Tasks visible only to creator
- **Task Templates**: Reusable task patterns
- **Bulk Operations**: Multi-select and batch actions

### Visual Task Representation

#### Bubble Design
- **Size Dynamics**: 
  - Unclaimed: Large (100px)
  - Claimed: Medium (70px)
  - Completed: Small (40px)
  - Urgent: +20-40% larger

- **Color System**:
  - Green: Personal tasks
  - Blue: Shared tasks
  - Orange: Urgent tasks
  - Grey: Completed tasks

- **Visual Indicators**:
  - Due date badges
  - Repeat icons
  - Owner indicators
  - Urgency animations

---

## 🔔 Notification System

### Local Notifications
- **Task Reminders**: Scheduled reminders for unclaimed tasks
- **Due Date Alerts**: Notifications for upcoming deadlines
- **Daily Summaries**: End-of-day completion reports
- **Test Notifications**: Development and debugging tools

### Push Notifications
- **Task Completion**: Notify partner when tasks are completed
- **New Task Alerts**: Real-time notifications for new tasks
- **Pairing Requests**: Notifications for pairing invitations
- **Activity Updates**: Partner activity and status changes

### Notification Channels
1. **Task Reminders**: High priority, sound + vibration
2. **Task Completion**: Medium priority, sound only
3. **Daily Summary**: Low priority, silent
4. **System Notifications**: Default priority

---

## 📊 Real-time Features

### Live Updates
- **Task Status Changes**: Instant visual updates across devices
- **Partner Activity**: Real-time last active timestamps
- **Pairing Status**: Live pairing/unpairing notifications
- **Task Creation**: Immediate task visibility for partners

### Supabase Integration
- **PostgreSQL Changes**: Real-time database subscriptions
- **User Presence**: Online/offline status tracking
- **Conflict Resolution**: Optimistic updates with rollback
- **Offline Support**: Local caching with sync on reconnect

---

## ⚙️ Settings & Customization

### User Preferences
- **Notification Settings**: Granular control over notification types
- **Daily Summary Time**: Customizable summary delivery time
- **Theme Options**: Light/dark mode support
- **Language Support**: Multi-language interface (planned)

### App Configuration
- **Task Cleanup**: Automatic cleanup of old completed tasks
- **Data Retention**: Configurable data retention policies
- **Export Options**: Task history export (Pro feature)
- **Backup & Restore**: Cloud backup and restore functionality

---

## 🚀 Current Features (v1.0.0)

### ✅ Implemented Features

#### Authentication
- [x] Email/password authentication
- [x] Google OAuth integration
- [x] User profile management
- [x] Session persistence

#### Pairing System
- [x] Code-based pairing
- [x] QR code generation and scanning
- [x] SMS invitation system
- [x] Real-time pairing status
- [x] Partner activity tracking

#### Task Management
- [x] Simple task creation
- [x] Task claiming system
- [x] Status management (unclaimed/claimed/done)
- [x] Repeating tasks
- [x] Visual bubble interface
- [x] Pull-to-refresh functionality
- [x] Task cleanup system

#### Notifications
- [x] Local notification system
- [x] Push notification integration
- [x] Task reminder scheduling
- [x] Daily summary notifications
- [x] Test notification tools

#### Real-time Features
- [x] Live task updates
- [x] Partner activity tracking
- [x] Real-time pairing status
- [x] Offline support with sync

#### UI/UX
- [x] Responsive design
- [x] Material Design 3 components
- [x] Error handling and recovery
- [x] Loading states and animations
- [x] Accessibility support

---

## 🎯 Next Target Features (v1.1.0 - v2.0.0)

### Phase 1: Enhanced Task Management (v1.1.0)

#### Due Date System
- [ ] Task due date setting
- [ ] Visual urgency indicators
- [ ] Overdue task highlighting
- [ ] Due date notifications

#### Task Categories
- [ ] Color-coded task categories
- [ ] Category filtering
- [ ] Category-based analytics
- [ ] Custom category creation

#### Improved UI
- [ ] Dark mode support
- [ ] Customizable themes
- [ ] Enhanced animations
- [ ] Better accessibility

### Phase 2: Pro Features (v2.0.0)

#### Multi-Pairing Support
- [ ] Multiple partner management
- [ ] Pair switching interface
- [ ] Pair-specific task views
- [ ] Pair history tracking

#### Private Tasks
- [ ] Task visibility controls
- [ ] Private task creation
- [ ] Visibility toggles
- [ ] Private task analytics

#### Task Archiving
- [ ] Completed task archiving
- [ ] Archive management UI
- [ ] Task restoration
- [ ] Archive analytics

#### Advanced Analytics
- [ ] Task completion statistics
- [ ] Partner contribution tracking
- [ ] Productivity insights
- [ ] Historical data visualization

### Phase 3: Enterprise Features (v2.1.0+)

#### Team Management
- [ ] Group task management
- [ ] Role-based permissions
- [ ] Team analytics
- [ ] Admin controls

#### Integration Support
- [ ] Calendar integration
- [ ] Email integration
- [ ] Third-party app connections
- [ ] API access

#### Advanced Automation
- [ ] Smart task suggestions
- [ ] Automated task creation
- [ ] Workflow automation
- [ ] AI-powered insights

---

## 📱 Platform-Specific Features

### iOS Features
- [x] Apple Sign-In integration
- [x] iOS-specific notifications
- [x] Haptic feedback
- [x] iOS design guidelines compliance

### Android Features
- [x] Material Design 3
- [x] Android-specific notifications
- [x] Adaptive icons
- [x] Android navigation patterns

### Web Features
- [x] Progressive Web App (PWA)
- [x] Offline functionality
- [x] Cross-browser compatibility
- [x] Desktop-optimized interface

### macOS Features
- [x] Native macOS app
- [x] Menu bar integration
- [x] Keyboard shortcuts
- [x] macOS design guidelines

---

## 🔧 Technical Implementation

### Database Schema
```sql
-- Users table
usr {
  id: UUID (Primary Key)
  name: String
  email: String
  pair_code: String
  paired_with: UUID (Foreign Key)
  last_active: DateTime
  fcm_token: String
  subscription_tier: String (Default: 'free')
  created_at: DateTime
  updated_at: DateTime
}

-- Tasks table
tasks {
  id: UUID (Primary Key)
  title: String
  status: Enum ('unclaimed', 'claimed', 'done')
  owner_id: UUID (Foreign Key)
  pair_id: String
  repeat: Boolean
  due_date: DateTime
  color: String
  visibility_type: String (Default: 'shared')
  archived_at: DateTime
  created_at: DateTime
  updated_at: DateTime
}
```

### Security Policies
- **Row Level Security (RLS)**: Users can only access their own data and paired partner data
- **Authentication Required**: All operations require valid authentication
- **Data Validation**: Server-side validation for all inputs
- **Rate Limiting**: API rate limiting to prevent abuse

### Performance Optimizations
- **Indexing**: Strategic database indexes for common queries
- **Caching**: Local caching for frequently accessed data
- **Lazy Loading**: Progressive data loading for large datasets
- **Optimistic Updates**: Immediate UI updates with background sync

---

## 🧪 Testing Strategy

### Unit Testing
- [x] Authentication logic
- [x] Task management functions
- [x] Pairing system validation
- [x] Notification service testing

### Integration Testing
- [x] Supabase integration
- [x] Firebase notification testing
- [x] OAuth flow testing
- [x] Real-time subscription testing

### UI Testing
- [x] Widget testing
- [x] User flow testing
- [x] Cross-platform compatibility
- [x] Accessibility testing

### Performance Testing
- [x] Load testing
- [x] Memory usage optimization
- [x] Battery consumption testing
- [x] Network efficiency testing

---

## 📈 Analytics & Metrics

### User Engagement
- Daily/Monthly Active Users
- Task completion rates
- Pairing success rates
- Feature adoption rates

### Performance Metrics
- App launch time
- Task creation/update latency
- Notification delivery rates
- Crash rates and error tracking

### Business Metrics
- User retention rates
- Subscription conversion (Pro features)
- User feedback scores
- Platform distribution

---

## 🔮 Future Vision

### Long-term Goals (3-5 years)
1. **AI-Powered Task Management**: Smart task suggestions and automation
2. **Enterprise Solutions**: Team and organization management
3. **Ecosystem Integration**: Deep integration with productivity tools
4. **Global Expansion**: Multi-language and cultural adaptation
5. **Advanced Analytics**: Predictive insights and productivity optimization

### Technology Evolution
- **Machine Learning**: Task pattern recognition and optimization
- **Blockchain**: Decentralized task verification (if applicable)
- **AR/VR**: Immersive task management interfaces
- **Voice Integration**: Voice-controlled task management

---

## 📞 Support & Documentation

### User Support
- In-app help system
- FAQ and troubleshooting guides
- Video tutorials and demos
- Community forums and feedback channels

### Developer Documentation
- API documentation
- Integration guides
- Customization tutorials
- Best practices and guidelines

---

## 📄 Legal & Compliance

### Privacy Policy
- GDPR compliance
- Data retention policies
- User data rights
- Third-party data sharing

### Terms of Service
- Usage guidelines
- Intellectual property rights
- Liability limitations
- Dispute resolution

---

*This document is a living specification that will be updated as the app evolves. Last updated: December 2024* 