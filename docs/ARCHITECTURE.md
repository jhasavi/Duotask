# DuoTask Architecture

## System Overview

DuoTask follows a clean architecture approach with clear separation of concerns. The application is built using Flutter for the frontend and Supabase for the backend services.

## Directory Structure

```
lib/
├── models/          # Data models and entities
├── services/        # Business logic and service layer
├── screens/         # UI screens
├── widgets/         # Reusable UI components
├── utils/           # Utility classes and helpers
└── main.dart        # Application entry point
```

## Key Components

### 1. Authentication
- Handles user sign-in, sign-up, and session management
- Integrates with Supabase Auth and Google OAuth
- Manages user sessions and tokens

### 2. Task Management
- Manages task creation, updates, and deletion
- Handles task assignment and status changes
- Implements real-time sync between users

### 3. Pairing System
- Manages user pairing logic
- Handles pair code generation and validation
- Manages pair relationships and status

### 4. Data Layer
- Handles all data operations
- Manages local caching and offline support
- Interfaces with Supabase database

## Data Flow

1. **UI Layer**: User interacts with widgets
2. **BLoC/Provider**: Handles business logic and state management
3. **Service Layer**: Contains business logic and data operations
4. **Repository**: Manages data sources (local/remote)
5. **Data Sources**: Supabase, local database, etc.

## Dependencies

- **State Management**: Provider/Riverpod
- **Networking**: Dio/HTTP for API calls
- **Local Storage**: Hive/SharedPreferences
- **Analytics**: Firebase Analytics
- **Testing**: Mockito, Test, Flutter Test

## Security Considerations

- All API calls use HTTPS
- Sensitive data is encrypted
- Row-level security in Supabase
- Secure token storage

## Performance Considerations

- Efficient state management
- Lazy loading for lists
- Image caching
- Optimized database queries
