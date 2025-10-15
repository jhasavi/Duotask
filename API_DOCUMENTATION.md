# DuoTask API Documentation

Comprehensive API reference for DuoTask backend services and database functions.

## 📋 Table of Contents

1. [Authentication](#authentication)
2. [User Management](#user-management)
3. [Pairing System](#pairing-system)
4. [Task Management](#task-management)
5. [Database Functions](#database-functions)
6. [Real-time Subscriptions](#real-time-subscriptions)
7. [Error Handling](#error-handling)

## 🔐 Authentication

### Supabase Auth Integration

DuoTask uses Supabase Auth for all authentication needs.

#### Endpoints
- **Sign Up**: `POST /auth/v1/signup`
- **Sign In**: `POST /auth/v1/token`
- **Sign Out**: `POST /auth/v1/logout`
- **Password Reset**: `POST /auth/v1/recover`
- **Email Confirmation**: `GET /auth/v1/verify`

#### Headers
```http
Authorization: Bearer <jwt_token>
apikey: <supabase_anon_key>
```

## 👤 User Management

### User Profile Operations

#### Get Current User
```sql
-- RPC Function: get_current_user()
SELECT 
  id,
  email,
  name,
  pair_code,
  created_at,
  updated_at
FROM usr 
WHERE id = auth.uid();
```

#### Update User Profile
```sql
-- RPC Function: update_user_profile(name TEXT)
UPDATE usr 
SET 
  name = update_user_profile.name,
  updated_at = NOW()
WHERE id = auth.uid()
RETURNING *;
```

#### Generate Pair Code
```sql
-- RPC Function: generate_pair_code()
UPDATE usr 
SET 
  pair_code = (
    SELECT string_agg(
      substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 
        (random() * 32)::int + 1, 1), ''
    ) FROM generate_series(1, 8)
  ),
  updated_at = NOW()
WHERE id = auth.uid()
RETURNING pair_code;
```

## 🤝 Pairing System

### Pair Management

#### Create Pair
```sql
-- RPC Function: fn_pair_up(pair_code TEXT)
-- Creates a new pair between current user and user with the given pair code
-- Returns pair information or error if invalid
```

**Parameters:**
- `pair_code`: 8-character alphanumeric code

**Returns:**
```json
{
  "success": true,
  "pair": {
    "id": "uuid",
    "user_a": "uuid",
    "user_b": "uuid",
    "status": "active",
    "created_at": "timestamp"
  }
}
```

#### Get Current Pair
```sql
-- RPC Function: fn_get_current_pair()
-- Returns current active pair for authenticated user
```

**Returns:**
```json
{
  "pair_id": "uuid",
  "partner_id": "uuid",
  "partner_name": "string",
  "status": "active",
  "created_at": "timestamp"
}
```

#### Unpair
```sql
-- RPC Function: fn_unpair()
-- Dissolves current pair for authenticated user
```

**Returns:**
```json
{
  "success": true,
  "message": "Successfully unpaired"
}
```

### Pair Validation

#### Check Pair Code
```sql
-- RPC Function: check_pair_code(code TEXT)
-- Validates if a pair code exists and is available
```

**Parameters:**
- `code`: 8-character pair code

**Returns:**
```json
{
  "valid": true,
  "user_name": "string",
  "user_id": "uuid"
}
```

## 📝 Task Management

### Task Operations

#### Create Personal Task
```sql
-- RPC Function: create_personal_task(title TEXT, due_date TIMESTAMPTZ DEFAULT NULL, urgent BOOLEAN DEFAULT FALSE)
-- Creates a personal task for the current user
```

**Parameters:**
- `title`: Task title (required)
- `due_date`: Optional due date
- `urgent`: Priority flag

**Returns:**
```json
{
  "id": "uuid",
  "title": "string",
  "scope": "personal",
  "creator_id": "uuid",
  "owner_id": "uuid",
  "status": "unclaimed",
  "due_date": "timestamp",
  "urgent": false,
  "created_at": "timestamp"
}
```

#### Create Shared Task
```sql
-- RPC Function: fn_create_shared_task(title TEXT, due_date TIMESTAMPTZ DEFAULT NULL, urgent BOOLEAN DEFAULT FALSE)
-- Creates a shared task for the current pair
```

**Parameters:**
- `title`: Task title (required)
- `due_date`: Optional due date
- `urgent`: Priority flag

**Returns:**
```json
{
  "id": "uuid",
  "title": "string",
  "scope": "shared",
  "creator_id": "uuid",
  "owner_id": "uuid",
  "pair_id": "uuid",
  "status": "unclaimed",
  "due_date": "timestamp",
  "urgent": false,
  "created_at": "timestamp"
}
```

#### Update Task Status
```sql
-- RPC Function: update_task_status(task_id UUID, new_status TEXT)
-- Updates task status (unclaimed, claimed, done)
```

**Parameters:**
- `task_id`: Task UUID
- `new_status`: New status value

**Returns:**
```json
{
  "success": true,
  "task": {
    "id": "uuid",
    "status": "claimed",
    "owner_id": "uuid",
    "updated_at": "timestamp"
  }
}
```

#### Claim Task
```sql
-- RPC Function: claim_task(task_id UUID)
-- Claims a task for the current user
```

**Parameters:**
- `task_id`: Task UUID

**Returns:**
```json
{
  "success": true,
  "task": {
    "id": "uuid",
    "status": "claimed",
    "owner_id": "uuid",
    "updated_at": "timestamp"
  }
}
```

#### Reclaim Task
```sql
-- RPC Function: reclaim_task(task_id UUID)
-- Reclaims a task from another user in the same pair
```

**Parameters:**
- `task_id`: Task UUID

**Returns:**
```json
{
  "success": true,
  "task": {
    "id": "uuid",
    "status": "claimed",
    "owner_id": "uuid",
    "updated_at": "timestamp"
  }
}
```

#### Delete Task
```sql
-- RPC Function: delete_task(task_id UUID)
-- Deletes a task (only creator can delete)
```

**Parameters:**
- `task_id`: Task UUID

**Returns:**
```json
{
  "success": true,
  "message": "Task deleted successfully"
}
```

### Task Queries

#### Get Personal Tasks
```sql
-- RPC Function: get_personal_tasks()
-- Returns all personal tasks for current user
```

**Returns:**
```json
[
  {
    "id": "uuid",
    "title": "string",
    "scope": "personal",
    "creator_id": "uuid",
    "owner_id": "uuid",
    "status": "unclaimed",
    "due_date": "timestamp",
    "urgent": false,
    "created_at": "timestamp",
    "updated_at": "timestamp"
  }
]
```

#### Get Shared Tasks
```sql
-- RPC Function: get_shared_tasks()
-- Returns all shared tasks for current pair
```

**Returns:**
```json
[
  {
    "id": "uuid",
    "title": "string",
    "scope": "shared",
    "creator_id": "uuid",
    "owner_id": "uuid",
    "pair_id": "uuid",
    "status": "unclaimed",
    "due_date": "timestamp",
    "urgent": false,
    "created_at": "timestamp",
    "updated_at": "timestamp"
  }
]
```

#### Get Partner Tasks
```sql
-- RPC Function: get_partner_tasks()
-- Returns tasks created by partner in current pair
```

**Returns:**
```json
[
  {
    "id": "uuid",
    "title": "string",
    "scope": "shared",
    "creator_id": "uuid",
    "owner_id": "uuid",
    "pair_id": "uuid",
    "status": "unclaimed",
    "due_date": "timestamp",
    "urgent": false,
    "created_at": "timestamp",
    "updated_at": "timestamp"
  }
]
```

## 🗄️ Database Functions

### Utility Functions

#### Generate Unique Code
```sql
-- Function: generate_unique_code(length INTEGER DEFAULT 8)
-- Generates a unique alphanumeric code
```

**Parameters:**
- `length`: Code length (default: 8)

**Returns:**
```sql
TEXT -- Unique code
```

#### Check User Exists
```sql
-- Function: user_exists(email TEXT)
-- Checks if a user exists with the given email
```

**Parameters:**
- `email`: User email

**Returns:**
```sql
BOOLEAN -- True if user exists
```

### Trigger Functions

#### Update Timestamp
```sql
-- Function: update_updated_at_column()
-- Automatically updates the updated_at column
```

**Usage:**
```sql
CREATE TRIGGER update_usr_updated_at 
  BEFORE UPDATE ON usr 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();
```

## 📡 Real-time Subscriptions

### Task Changes
```javascript
// Subscribe to task changes
const subscription = supabase
  .channel('task_changes')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'tasks',
    filter: 'owner_id=eq.' + userId
  }, (payload) => {
    console.log('Task changed:', payload)
  })
  .subscribe()
```

### Pairing Status
```javascript
// Subscribe to pairing status changes
const subscription = supabase
  .channel('pairing_status')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'pair',
    filter: 'user_a=eq.' + userId + '|user_b=eq.' + userId
  }, (payload) => {
    console.log('Pairing status changed:', payload)
  })
  .subscribe()
```

### User Profile Changes
```javascript
// Subscribe to user profile changes
const subscription = supabase
  .channel('user_profile')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'usr',
    filter: 'id=eq.' + userId
  }, (payload) => {
    console.log('Profile changed:', payload)
  })
  .subscribe()
```

## ⚠️ Error Handling

### Common Error Codes

#### Authentication Errors
```json
{
  "error": "Invalid login credentials",
  "code": "invalid_credentials"
}
```

```json
{
  "error": "Email not confirmed",
  "code": "email_not_confirmed"
}
```

#### Pairing Errors
```json
{
  "error": "Invalid pair code",
  "code": "invalid_pair_code"
}
```

```json
{
  "error": "Already paired",
  "code": "already_paired"
}
```

```json
{
  "error": "No active pair",
  "code": "no_active_pair"
}
```

#### Task Errors
```json
{
  "error": "Task not found",
  "code": "task_not_found"
}
```

```json
{
  "error": "Cannot reclaim task",
  "code": "cannot_reclaim"
}
```

```json
{
  "error": "Permission denied",
  "code": "permission_denied"
}
```

### Error Response Format
```json
{
  "error": "Error message",
  "code": "error_code",
  "details": "Additional error details",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 🔒 Security

### Row Level Security (RLS) Policies

#### User Table
```sql
-- Users can only see their own profile
CREATE POLICY "Users can view own profile" ON usr
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON usr
  FOR UPDATE USING (auth.uid() = id);
```

#### Pair Table
```sql
-- Users can only see pairs they're part of
CREATE POLICY "Users can view own pairs" ON pair
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Users can only create pairs they're part of
CREATE POLICY "Users can create own pairs" ON pair
  FOR INSERT WITH CHECK (auth.uid() = user_a OR auth.uid() = user_b);
```

#### Tasks Table
```sql
-- Users can only see their own tasks or shared tasks in their pair
CREATE POLICY "Users can view own and shared tasks" ON tasks
  FOR SELECT USING (
    auth.uid() = owner_id OR 
    (scope = 'shared' AND pair_id IN (
      SELECT id FROM pair 
      WHERE user_a = auth.uid() OR user_b = auth.uid()
    ))
  );

-- Users can only create tasks they own
CREATE POLICY "Users can create own tasks" ON tasks
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

-- Users can only update tasks they own or shared tasks in their pair
CREATE POLICY "Users can update own and shared tasks" ON tasks
  FOR UPDATE USING (
    auth.uid() = owner_id OR 
    (scope = 'shared' AND pair_id IN (
      SELECT id FROM pair 
      WHERE user_a = auth.uid() OR user_b = auth.uid()
    ))
  );
```

## 📊 Rate Limiting

### API Limits
- **Authentication**: 10 requests per minute per IP
- **Task Operations**: 100 requests per minute per user
- **Pairing Operations**: 20 requests per minute per user
- **Real-time Subscriptions**: 5 concurrent subscriptions per user

### Rate Limit Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## 🧪 Testing

### Test Endpoints
```bash
# Test authentication
curl -X POST "https://your-project.supabase.co/auth/v1/signup" \
  -H "apikey: your_anon_key" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Test pairing
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/fn_pair_up" \
  -H "apikey: your_anon_key" \
  -H "Authorization: Bearer your_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{"pair_code":"ABC12345"}'

# Test task creation
curl -X POST "https://your-project.supabase.co/rest/v1/rpc/create_personal_task" \
  -H "apikey: your_anon_key" \
  -H "Authorization: Bearer your_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test task"}'
```

---

This API documentation provides a comprehensive reference for all backend services and database functions used in DuoTask.
