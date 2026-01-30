# Municipality Login Integration Guide

## ✅ Current Status

The Flutter app now has **full HTTP integration** with backend Cloud Functions for municipality authentication. All API calls are real (not mocked).

---

## 🔧 Setup Instructions

### Step 1: Update Firebase Project ID

In [lib/core/services/municipality_auth_service.dart](lib/core/services/municipality_auth_service.dart), find all instances of:

```dart
const projectId = 'your-firebase-project';
```

Replace `'your-firebase-project'` with your actual Firebase project ID (e.g., `'roadsense-3e4b2'`):

```dart
const projectId = 'roadsense-3e4b2'; // Your actual project ID
```

**Locations to update:**
- Line ~153: In `login()` function
- Line ~254: In `verifyToken()` function
- Line ~274: In `logout()` function
- Line ~330: In `restoreSession()` function

---

### Step 2: Deploy Backend Cloud Functions

```bash
cd backend/functions

# Install dependencies (if not done yet)
npm install

# Deploy to Firebase
firebase deploy --only functions
```

**Expected output:**
```
✔  Deploy complete!

Function URL (municipalityLogin): https://us-central1-roadsense-3e4b2.cloudfunctions.net/municipalityLogin
Function URL (verifyToken): https://us-central1-roadsense-3e4b2.cloudfunctions.net/verifyToken
Function URL (municipalityLogout): https://us-central1-roadsense-3e4b2.cloudfunctions.net/municipalityLogout
```

---

### Step 3: Set Environment Variables

In Firebase Cloud Functions, set the JWT secret:

```bash
firebase functions:config:set jwt.secret="your-super-secret-key-min-32-chars"
```

Or in `.env.local` file (if using local emulator):
```
JWT_SECRET=your-super-secret-key-min-32-chars
```

---

### Step 4: Create Firestore Collections

Use the schema from [backend/FIRESTORE_SCHEMA.js](../backend/FIRESTORE_SCHEMA.js):

**1. Create `municipalities` collection:**
```
Document ID: (auto-generated)
Fields:
  - name: string ("New York City")
  - code: string ("NYC") [UNIQUE]
  - contact_email: string ("admin@nyc.gov")
  - contact_phone: string ("+1-212-555-0100")
  - address: string ("100 City Hall...")
  - verified: boolean (true)
  - created_at: timestamp
  - updated_at: timestamp
```

**2. Create `municipality_users` collection:**
```
Document ID: (auto-generated or use email hash)
Fields:
  - email: string ("admin@city.gov") [UNIQUE]
  - password_hash: string (bcrypt hash - use Cloud Function to create users)
  - name: string ("John Doe")
  - role: string ("MUNICIPAL_ADMIN")
  - municipality_id: string (reference to municipalities doc)
  - active: boolean (true)
  - created_at: timestamp
  - updated_at: timestamp
  - last_login: timestamp (null)
```

**3. Create `municipality_issues` collection:**
```
Document ID: (auto-generated)
Fields:
  - detection_id: string
  - status: string ("OPEN")
  - severity: number (1-3)
  - latitude: number
  - longitude: number
  - assigned_to: string (user ID or null)
  - priority: string ("MEDIUM")
  - ... (see FIRESTORE_SCHEMA.js for full details)
```

**4. Create `auth_logs` collection:**
```
Document ID: (auto-generated)
Fields:
  - email: string
  - user_id: string (null for failed logins)
  - action: string ("LOGIN_SUCCESS" | "LOGIN_FAILED" | "LOGOUT")
  - timestamp: timestamp
  - reason: string (error message if failed)
  - ip_address: string
```

---

### Step 5: Create Test Municipality Admin User

Use the Cloud Function to create users. First, you need a SUPER_ADMIN account.

**Option A: Direct Firestore insert (development only):**

1. Go to Firebase Console → Firestore
2. In `municipality_users` collection, create a document:
   ```
   email: test@city.gov
   password_hash: $2b$10$[bcrypt_hash_of_"password123"]
   name: Test Admin
   role: MUNICIPAL_ADMIN
   municipality_id: [copy the NYC municipality doc ID]
   active: true
   created_at: [now]
   updated_at: [now]
   last_login: null
   ```

   To generate bcrypt hash, use Node.js:
   ```bash
   npm install -g bcrypt-cli
   bcrypt password123
   # Output: $2b$10$...
   ```

**Option B: Via Cloud Function (production):**

Once you have a SUPER_ADMIN token, call:
```bash
curl -X POST https://us-central1-roadsense-3e4b2.cloudfunctions.net/createMunicipalityUser \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@city.gov",
    "password": "password123",
    "name": "Test Admin",
    "role": "MUNICIPAL_ADMIN",
    "municipality_id": "[municipality_doc_id]",
    "createdByToken": "[super_admin_jwt_token]"
  }'
```

---

## 🧪 Testing the Login Flow

### 1. Update pubspec.yaml and get dependencies:

```bash
flutter pub get
```

### 2. Run the app:

```bash
flutter run
```

### 3. Navigate to Municipality Login:

- Wait for splash screen (3 seconds)
- Tap "Municipality Dashboard" button
- Enter credentials:
  - **Email:** test@city.gov
  - **Password:** password123

### 4. Expected Behavior:

✅ **Success:**
- Loading spinner appears for ~2 seconds
- Redirects to dashboard (or shows "coming soon" message)
- Token is stored securely in device storage

❌ **Failure (expected errors):**
- Empty fields → "Please fill in all fields"
- Invalid email → "Please enter a valid email"
- Wrong password → "Invalid email or password"
- Inactive account → "Your account is inactive..."
- Municipality unverified → "Municipality not verified yet..."
- Network error → "Network error: [details]"
- Timeout → "Request timed out. Please try again."

---

## 📋 API Response Examples

### Successful Login (200)
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user_doc_id",
    "email": "admin@city.gov",
    "name": "John Doe",
    "role": "MUNICIPAL_ADMIN",
    "municipality_id": "municipality_doc_id"
  },
  "expiresIn": 86400
}
```

### Invalid Credentials (401)
```json
{
  "success": false,
  "message": "Invalid email or password"
}
```

### Inactive Account (403)
```json
{
  "success": false,
  "message": "Your account is inactive. Contact administrator."
}
```

### Verification Token (200)
```json
{
  "success": true,
  "valid": true,
  "decoded": {
    "userId": "user_id",
    "email": "admin@city.gov",
    "role": "MUNICIPAL_ADMIN",
    "expiresAt": 1675446400000
  }
}
```

---

## 🔐 Security Best Practices

### ✅ What's Implemented:

- [x] HTTPS only (Cloud Functions automatically)
- [x] JWT tokens (24-hour expiry)
- [x] Secure token storage (Flutter Secure Storage)
- [x] Bcrypt password hashing (backend only)
- [x] Rate limiting ready (add to backend)
- [x] Audit logging of all auth attempts

### ⚠️ Additional Recommendations:

1. **Enable rate limiting** on Cloud Functions to prevent brute-force attacks:
   ```javascript
   // Add to auth.js
   const rateLimit = require('express-rate-limit');
   const limiter = rateLimit({
     windowMs: 15 * 60 * 1000, // 15 minutes
     max: 5, // 5 attempts
     message: 'Too many login attempts, try again later'
   });
   ```

2. **Implement 2FA** for SUPER_ADMIN accounts

3. **Add password reset flow** with email verification

4. **Encrypt sensitive fields** at rest in Firestore

5. **Monitor auth_logs** collection for suspicious activity

6. **Use VPC Service Controls** to restrict Cloud Functions access

---

## 🐛 Debugging Tips

### View Cloud Function Logs:
```bash
firebase functions:log --limit=50
```

### Check Firestore Rules:
```bash
firebase firestore:describe-indexes
```

### Test Cloud Function Locally:
```bash
firebase emulators:start --only functions
```

Then call locally:
```bash
curl -X POST http://localhost:5001/roadsense-3e4b2/us-central1/municipalityLogin \
  -H "Content-Type: application/json" \
  -d '{"email": "test@city.gov", "password": "password123"}'
```

### View Stored Token (Flutter):
```dart
// In your debug code
final token = await _secureStorage.read(key: 'municipality_auth_token');
print('Stored token: $token');
```

---

## 📱 Code Files Modified

- [lib/core/services/municipality_auth_service.dart](lib/core/services/municipality_auth_service.dart) — HTTP calls implemented
- [lib/features/auth/municipality_login_screen.dart](lib/features/auth/municipality_login_screen.dart) — Real auth service integrated
- [lib/app.dart](lib/app.dart) — Auth service initialization
- [pubspec.yaml](pubspec.yaml) — Added `http: ^1.1.0`
- [backend/functions/auth.js](../backend/functions/auth.js) — Cloud Functions
- [backend/functions/package.json](../backend/functions/package.json) — Dependencies (bcrypt, jwt)

---

## ✨ Next Steps

1. **Deploy Cloud Functions** to your Firebase project
2. **Create test municipality and admin user** in Firestore
3. **Update projectId** in Flutter code
4. **Run and test** the login flow
5. **Add Municipality Dashboard** after login succeeds
6. **Implement role-based access control** for different admin types

Good luck! 🚀
