# Municipality Login & Dashboard Flow

## Overview
Complete end-to-end flow for municipality admin authentication and dashboard access.

---

## Flow Diagram

```
┌─────────────────────────┐
│  Login Landing Page     │
│  (2 Buttons)            │
│ - User Mode             │
│ - Municipality Login     │
└────────┬────────────────┘
         │
         └─► Municipality Login Screen
             │
             ├─ Email input field
             ├─ Password input field
             ├─ Login button
             │
             └─► HTTP POST to Cloud Function: municipalityLogin
                 │
                 ├─ Success (200) ──────────► onLoginSuccess() called
                 │                            │
                 │                            └─► AppScreen.municipalityDashboard
                 │                                 │
                 │                                 └─► MunicipalityDashboardScreen
                 │                                      │
                 │                                      ├─ Load statistics
                 │                                      ├─ Load municipality issues
                 │                                      ├─ Display dashboard widgets
                 │                                      └─ Provide filtering & logout
                 │
                 └─ Failure (401/400/etc) ──► Show error message
```

---

## Detailed Steps

### Step 1: Login Form Submission
**File:** `lib/features/auth/municipality_login_screen.dart`

```dart
// User enters email and password
// onPressed for Login button:
1. Validate form (email, password not empty)
2. Call: widget.authService.login(email, password)
3. Set _isLoading = true
4. HTTP POST sent to Cloud Function
```

### Step 2: Authentication Service
**File:** `lib/core/services/municipality_auth_service.dart`

```dart
// Method: login(String email, String password)
1. Validate inputs (email format, password length)
2. HTTP POST to: 
   https://asia-south1-roadsense-3e4b2.cloudfunctions.net/municipalityLogin
3. Body: { email, password }
4. Parse response:
   - Success (200): Extract JWT token + user data
   - Store token in secure storage
   - Create MunicipalityUser object (id, email, role, municipality_id)
   - Update authState with user data
5. Return success boolean
```

### Step 3: Callback to App Level
**File:** `lib/app.dart`

```dart
// In MunicipalityLoginScreen instantiation:
onLoginSuccess: () {
  setState(() {
    _currentScreen = AppScreen.municipalityDashboard;
  });
}
```

**Result:** Screen changes from municipalityLogin to municipalityDashboard

### Step 4: Dashboard Initialization
**File:** `lib/features/dashboard/municipality_dashboard_screen.dart`

```dart
// In initState():
1. Get Firestore instance: FirebaseFirestore.instanceFor(databaseId: 'roadse')
2. Call _loadDashboardData()

// In _loadDashboardData():
1. Get current user: widget.authService.currentUser
2. Extract municipality_id from user
3. Query Firestore:
   db.collection('municipality_issues')
     .where('municipality_id', isEqualTo: user.municipalityId)
     .get()
4. Count issues by status and priority:
   - _totalPotholes: All issues count
   - _openIssues: Where status == 'OPEN'
   - _resolvedIssues: Where status == 'RESOLVED'
   - _highPriorityIssues: Where priority == 'HIGH'
5. Build list of IssueData objects
6. Update UI with setState()
```

### Step 5: Dashboard Display
**Dashboard Features:**

1. **Welcome Section**
   - Display user email
   - Show municipality info
   - Display total pothole count

2. **Statistics Cards** (4 cards)
   - Total Potholes
   - Open Issues
   - Resolved Issues
   - High Priority Issues

3. **Issue Filtering**
   - All
   - Open
   - Resolved
   - High Priority

4. **Issue List**
   - Display each issue as card
   - Show: Location, Severity, Status, Priority
   - Color-coded badges:
     - Severity: Red (High), Orange (Medium), Yellow (Low)
     - Status: Orange (Open), Green (Resolved)
   - Tap to view details (TODO: Implement detail view)

5. **Logout Button**
   - Show confirmation dialog
   - Clear JWT token from secure storage
   - Navigate back to login screen

---

## Data Models

### MunicipalityUser
```dart
class MunicipalityUser {
  final String id;               // User doc ID
  final String email;
  final String name;
  final String role;             // MUNICIPAL_ADMIN, SUPER_ADMIN, FIELD_ENGINEER
  final String municipalityId;   // Municipality doc ID
  final bool active;
}
```

### AuthState
```dart
class AuthState {
  final MunicipalityUser? user;
  final String? token;           // JWT token (24-hour expiry)
  final String? error;
  final bool isLoading;
}
```

### IssueData
```dart
class IssueData {
  final String id;               // Document ID
  final String status;           // OPEN, IN_PROGRESS, RESOLVED, CLOSED
  final int severity;            // 1 (LOW), 2 (MEDIUM), 3 (HIGH)
  final String priority;         // LOW, MEDIUM, HIGH
  final double latitude;
  final double longitude;
  final String? assignedTo;      // User ID (null if unassigned)
  final DateTime? createdAt;
  final String detectionId;      // Link to detection document
}
```

---

## Firestore Collections

### municipality_issues
```
Document: {issue_doc_id}
{
  "detection_id": "string",
  "municipality_id": "string",   // User's municipality
  "status": "OPEN" | "IN_PROGRESS" | "RESOLVED",
  "severity": 1 | 2 | 3,
  "priority": "LOW" | "MEDIUM" | "HIGH",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "assigned_to": "user_doc_id",  // null if unassigned
  "notes": "string",
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

### municipality_users
```
Document: {user_doc_id}
{
  "email": "admin@city.gov",
  "password_hash": "bcrypt_hash",
  "name": "John Doe",
  "role": "MUNICIPAL_ADMIN",
  "municipality_id": "city_doc_id",
  "active": true,
  "created_at": Timestamp,
  "last_login": Timestamp
}
```

---

## Error Handling

### Login Screen Errors
- **Empty email/password:** Form validation error
- **Invalid email format:** Form validation error
- **Network timeout:** "Network error. Please try again."
- **HTTP 400:** Bad request (invalid credentials)
- **HTTP 401:** "Invalid email or password"
- **HTTP 403:** "Access denied"
- **Other:** "Login failed. Please try again."

### Dashboard Load Errors
- **Municipality ID not found:** "Error: Municipality ID not found"
- **Firestore query fails:** "Error loading dashboard: {error message}"
- **User session expired:** Handled by JWT verification

---

## Security

### JWT Token Management
- **Issued by:** Cloud Function (municipalityLogin)
- **Expiry:** 24 hours from issue time
- **Storage:** flutter_secure_storage (encrypted)
- **Usage:** Sent in Authorization header for API calls
- **Verification:** Token verified before accessing protected resources

### Role-Based Access Control (RBAC)
- **SUPER_ADMIN:** Access all municipalities
- **MUNICIPAL_ADMIN:** Access own municipality only
- **FIELD_ENGINEER:** Access assigned issues only

### Password Security
- **Hashing:** bcrypt (backend, in Cloud Functions)
- **Storage:** Never stored in app
- **Transmission:** HTTPS only

---

## Navigation Flow

```
App Level (lib/app.dart)
├── AppScreen enum: splash, login, userMode, municipalityLogin, municipalityDashboard, liveMap, routeComparison
│
├── LoginLandingPage
│   ├── onUserLoginPressed → _navigateToUserMode()
│   └── onMunicipalityLoginPressed → _navigateToMunicipalityLogin()
│
├── MunicipalityLoginScreen
│   ├── onLoginSuccess → setState(AppScreen.municipalityDashboard)
│   └── onBackPressed → _backToLogin()
│
└── MunicipalityDashboardScreen
    ├── onLogout → setState(AppScreen.login)
    └── Shows: Statistics, Issue List, Filtering
```

---

## Testing Checklist

- [ ] User can navigate to Municipality Login screen
- [ ] User can enter email and password
- [ ] Login button sends HTTP request to Cloud Function
- [ ] Successful login (200) shows dashboard
- [ ] Failed login (401) shows error message
- [ ] Dashboard loads statistics from Firestore
- [ ] Dashboard queries only municipality-specific issues
- [ ] Filtering works (All/Open/Resolved/High Priority)
- [ ] Logout button shows confirmation dialog
- [ ] Logout clears token and returns to login
- [ ] Statistics cards match Firestore data
- [ ] Issue cards display correctly with colors and badges
- [ ] Pull-to-refresh reloads dashboard
- [ ] Token persists across app restarts
- [ ] Expired token triggers re-authentication

---

## Deployment Status

- ✅ **Frontend:** All screens implemented and wired
- ✅ **Navigation:** Complete flow from login to dashboard
- ✅ **Firestore:** Integration with municipality_issues collection
- ⏳ **Backend:** Cloud Functions ready for deployment
- ⏳ **Test Data:** Need to populate sample issues in Firestore

---

## Next Steps

1. **Implement Issue Detail View**
   - Click issue card → show full details
   - Display: location on map, full description, assignment status

2. **Implement Issue Assignment**
   - Dashboard: Assign issue to field engineer
   - Update: municipality_issues document

3. **Implement Status Updates**
   - Dashboard: Change issue status (Open → In Progress → Resolved)
   - Update: municipality_issues document

4. **Add Dashboard Map**
   - Display issue locations on map
   - Color code by priority/severity

5. **Deploy Cloud Functions**
   - Run: `firebase deploy --only functions`
   - Requires: firebase login

6. **Populate Test Data**
   - Create sample issues in Firestore
   - Create test municipality user account
