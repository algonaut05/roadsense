# Municipality Login Logic - RoadSense

## Current Implementation Status

The `municipality_login_screen.dart` currently has a **mock/placeholder implementation**. This document explains:
1. Current logic flow
2. What needs to be implemented for production
3. Backend requirements
4. Authentication flow with JWT tokens

---

## 1. Current Flow (Mock)

```dart
void _handleLogin() {
    // Step 1: Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Step 2: Set loading state
    setState(() => _isLoading = true);

    // Step 3: Simulate 2-second backend call
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);
      if (mounted) {
        widget.onLoginSuccess();  // Navigate to dashboard
      }
    });
  }
```

**What it does:**
- ✅ Validates that email & password are not empty
- ✅ Shows loading indicator while "processing"
- ✅ Simulates a 2-second delay (real backend call would take time)
- ✅ Calls success callback to navigate away
- ❌ **Does NOT validate credentials**
- ❌ **Does NOT call backend API**
- ❌ **Does NOT manage JWT tokens**
- ❌ **Does NOT check user role**

---

## 2. Production Login Flow (To Be Implemented)

### Architecture
```
Frontend (Flutter)              Backend (Node.js/Cloud Functions)
     |                                      |
     | 1. POST /auth/login              |
     | { email, password }              |
     +------------------------------>    |
     |                                      | 2. Query `municipality_users` collection
     |                                      | 3. Verify password hash
     |                                      | 4. Check if active = true
     |                                      | 5. Generate JWT token
     |                            | 6. Return JWT + user data
     | <------------------------------  |
     | 7. Store JWT in secure storage   |
     | 8. Extract role from token       |
     | 9. Navigate to dashboard         |
     |
```

### Implementation (Pseudocode)

```dart
Future<void> _handleLogin() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    _showError('Please fill in all fields');
    return;
  }

  setState(() => _isLoading = true);

  try {
    // Step 1: Call backend authentication API
    final response = await _makeLoginRequest(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // Step 2: Check for API errors
    if (response.statusCode != 200) {
      _showError(response.body['message'] ?? 'Login failed');
      return;
    }

    // Step 3: Extract JWT token
    final jwtToken = response.body['token'];
    final userRole = response.body['role'];  // SUPER_ADMIN, MUNICIPAL_ADMIN, FIELD_ENGINEER

    // Step 4: Store token securely (use flutter_secure_storage)
    await _secureStorage.write(key: 'auth_token', value: jwtToken);
    await _secureStorage.write(key: 'user_role', value: userRole);

    // Step 5: Validate role is allowed
    if (!_isValidRole(userRole)) {
      _showError('Unauthorized role: $userRole');
      return;
    }

    // Step 6: Navigate to appropriate dashboard
    widget.onLoginSuccess();

  } on SocketException {
    _showError('Network error. Check your connection.');
  } catch (e) {
    _showError('Unexpected error: ${e.toString()}');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

---

## 3. Required Firestore Collections & Schema

### Collection: `municipality_users`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `email` | String | ✅ | Unique, lowercase |
| `password_hash` | String | ✅ | Bcrypt hash (never store plaintext) |
| `role` | String | ✅ | SUPER_ADMIN \| MUNICIPAL_ADMIN \| FIELD_ENGINEER |
| `name` | String | ✅ | Display name |
| `municipality_id` | String | ✅ | Reference to `municipalities` |
| `active` | Boolean | ✅ | Can login if true |
| `created_at` | Timestamp | ✅ | Auto-set on creation |
| `updated_at` | Timestamp | ✅ | Auto-set on update |
| `last_login` | Timestamp | ❌ | Track login patterns |

**Example Document:**
```json
{
  "email": "admin@city.gov",
  "password_hash": "$2b$10$...",  // bcrypt hash
  "role": "MUNICIPAL_ADMIN",
  "name": "John Doe",
  "municipality_id": "doc_id_city_xyz",
  "active": true,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-20T14:22:00Z",
  "last_login": "2025-01-30T09:15:00Z"
}
```

### Collection: `municipalities`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | String | ✅ | City/Municipality name |
| `code` | String | ✅ | Unique code (e.g., "NYC", "LA") |
| `contact_email` | String | ✅ | Primary contact |
| `contact_phone` | String | ❌ | Phone number |
| `address` | String | ❌ | Physical address |
| `verified` | Boolean | ✅ | Can only login if true |
| `created_at` | Timestamp | ✅ | Registration date |
| `updated_at` | Timestamp | ✅ | Last updated |

---

## 4. Backend API Endpoint: `/auth/login`

### Request
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "admin@city.gov",
  "password": "securePassword123"
}
```

### Response (Success - 200)
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user_doc_id",
    "email": "admin@city.gov",
    "name": "John Doe",
    "role": "MUNICIPAL_ADMIN",
    "municipality_id": "city_doc_id"
  },
  "expiresIn": 86400  // seconds (24 hours)
}
```

### Response (Failure - 401)
```json
{
  "success": false,
  "message": "Invalid email or password"
}
```

### Response (Failure - 403)
```json
{
  "success": false,
  "message": "Your account is not active. Contact administrator."
}
```

---

## 5. JWT Token Structure

**Header:**
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

**Payload (Claims):**
```json
{
  "sub": "user_doc_id",
  "email": "admin@city.gov",
  "role": "MUNICIPAL_ADMIN",
  "municipality_id": "city_doc_id",
  "iat": 1675360000,      // issued at
  "exp": 1675446400       // expires at (24 hours later)
}
```

**Signature:**
```
HS256(header.payload, "YOUR_SECRET_KEY")
```

---

## 6. Role-Based Access Control (RBAC)

### Roles & Permissions

#### **SUPER_ADMIN**
- ✅ View all municipalities' issues
- ✅ Manage all users
- ✅ View analytics across all regions
- ✅ Approve municipality registrations

#### **MUNICIPAL_ADMIN**
- ✅ View issues for their municipality
- ✅ Assign issues to field engineers
- ✅ Mark issues as resolved
- ✅ View municipality dashboard & statistics
- ❌ Cannot manage other municipalities

#### **FIELD_ENGINEER**
- ✅ View assigned issues
- ✅ Upload field updates (photos, status)
- ✅ Mark issue as in-progress
- ❌ Cannot change issue status to resolved

### Implementation (Backend Middleware)

```javascript
// Cloud Function middleware
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    try {
      const decoded = admin.auth().verifyIdToken(token);
      const userRole = decoded.role;

      if (!allowedRoles.includes(userRole)) {
        return res.status(403).json({ 
          error: `Role '${userRole}' not authorized for this action` 
        });
      }

      req.user = decoded;
      next();
    } catch (error) {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}

// Usage in endpoints
app.get('/api/v1/issues/:municipality_id', 
  requireRole('SUPER_ADMIN', 'MUNICIPAL_ADMIN'),
  handleGetIssues
);
```

---

## 7. Secure Token Storage (Frontend)

**Install dependency:**
```bash
flutter pub add flutter_secure_storage
```

**Usage:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _secureStorage = const FlutterSecureStorage();

// Save token after login
await _secureStorage.write(
  key: 'auth_token',
  value: jwtToken,
);

// Retrieve token for API calls
final token = await _secureStorage.read(key: 'auth_token');

// Clear token on logout
await _secureStorage.delete(key: 'auth_token');
```

---

## 8. Auto-Login (Restore Session)

On app restart, check if valid token exists:

```dart
Future<void> _restoreSession() async {
  final token = await _secureStorage.read(key: 'auth_token');
  
  if (token != null && _isTokenValid(token)) {
    // Token exists and is not expired
    widget.onLoginSuccess();
  } else {
    // Show login page
    setState(() => _currentScreen = AppScreen.login);
  }
}
```

---

## 9. Password Security Best Practices

### What NOT to do:
- ❌ Store plaintext passwords
- ❌ Send passwords over HTTP (use HTTPS only)
- ❌ Store passwords in SharedPreferences
- ❌ Log passwords anywhere

### What to do:
- ✅ Hash with **bcrypt** (cost factor ≥ 10)
- ✅ Always use HTTPS
- ✅ Implement rate limiting (e.g., 5 attempts → 15-min lockout)
- ✅ Add password reset via email
- ✅ Implement 2FA for SUPER_ADMIN

---

## 10. Error Handling

| Error | Status | Message | Action |
|-------|--------|---------|--------|
| Empty email/password | 400 | "Please fill in all fields" | Prevent submission |
| User not found | 401 | "Invalid email or password" | Show generic message (don't reveal if email exists) |
| Wrong password | 401 | "Invalid email or password" | Increment attempt counter |
| Account inactive | 403 | "Your account is inactive. Contact administrator." | Show error & disable login |
| Municipality unverified | 403 | "Municipality not verified yet." | Contact support message |
| Network error | --- | "Network error. Check your connection." | Show retry button |
| Token expired | 401 | "Session expired. Please login again." | Clear storage & show login |

---

## 11. Implementation Checklist

- [ ] Create Firebase Cloud Function for `/auth/login`
- [ ] Create `municipality_users` collection in Firestore
- [ ] Create `municipalities` collection in Firestore
- [ ] Implement bcrypt password hashing (backend)
- [ ] Implement JWT token generation (backend)
- [ ] Add `flutter_secure_storage` dependency
- [ ] Implement token storage in Flutter
- [ ] Implement role-based route guards
- [ ] Add password reset flow
- [ ] Add rate limiting for login attempts
- [ ] Implement session restoration on app restart
- [ ] Add 2FA for SUPER_ADMIN accounts
- [ ] Log all authentication attempts (audit trail)

---

**Would you like me to implement any of these components?**
