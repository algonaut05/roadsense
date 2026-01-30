// Firestore Collections Schema for RoadSense Municipality Module

// ============================================================================
// Collection: municipality_users
// Description: Stores municipality admin, staff, and field engineer accounts
// ============================================================================

// Example document in municipality_users collection:
{
  "email": "admin@city.gov",
  "password_hash": "$2b$10$abcdef1234567890...",  // Bcrypt hashed password
  "name": "John Doe",
  "role": "MUNICIPAL_ADMIN",  // SUPER_ADMIN | MUNICIPAL_ADMIN | FIELD_ENGINEER
  "municipality_id": "doc_id_of_municipality",
  "active": true,
  "created_at": Timestamp("2025-01-15T10:30:00Z"),
  "updated_at": Timestamp("2025-01-20T14:22:00Z"),
  "last_login": Timestamp("2025-01-30T09:15:00Z")
}

// Field Descriptions:
// - email (string, required): User's email, must be unique and lowercase
// - password_hash (string, required): Bcrypt-hashed password (never store plaintext)
// - name (string, required): Display name of the user
// - role (string, required): User's role determining permissions
// - municipality_id (string, required): Reference to the municipalities collection
// - active (boolean, required): Can only login if true
// - created_at (timestamp, required): When account was created
// - updated_at (timestamp, required): When account was last updated
// - last_login (timestamp, optional): Last successful login timestamp

// Indexes needed:
// - Composite: email (Ascending) + active (Ascending) for login queries
// - Single: municipality_id (Ascending) for querying users by municipality
// - Single: role (Ascending) for role-based queries

// ============================================================================
// Collection: municipalities
// Description: Stores municipality/city information
// ============================================================================

{
  "name": "New York City",
  "code": "NYC",
  "contact_email": "admin@nyc.gov",
  "contact_phone": "+1-212-555-0100",
  "address": "100 City Hall, New York, NY 10007",
  "verified": true,
  "created_at": Timestamp("2024-06-01T00:00:00Z"),
  "updated_at": Timestamp("2025-01-20T14:22:00Z")
}

// Field Descriptions:
// - name (string, required): Full name of municipality
// - code (string, required): Unique code (e.g., "NYC", "LA"), must be unique
// - contact_email (string, required): Primary contact email
// - contact_phone (string, optional): Contact phone number
// - address (string, optional): Physical address
// - verified (boolean, required): Can only login if true; must be verified by SUPER_ADMIN
// - created_at (timestamp, required): Registration date
// - updated_at (timestamp, required): Last updated date

// Indexes needed:
// - Single: code (Ascending) for unique code lookups
// - Single: verified (Ascending) for filtering verified municipalities

// ============================================================================
// Collection: municipality_issues
// Description: Issues reported/verified for each municipality
// ============================================================================

{
  "detection_id": "doc_id_from_detections_collection",
  "status": "OPEN",  // OPEN | IN_PROGRESS | RESOLVED | CLOSED | DISMISSED
  "severity": 2,  // 1 (LOW) | 2 (MEDIUM) | 3 (HIGH)
  "latitude": 40.7128,
  "longitude": -74.0060,
  "address": "5th Avenue, Manhattan, NY",
  "assigned_to": "user_doc_id_of_field_engineer",  // null if unassigned
  "priority": "MEDIUM",  // LOW | MEDIUM | HIGH
  "notes": "Large pothole ~1m diameter on main road",
  "description": "Report from crowdsourced detection",
  "reporter_id": "anonymous_user_id",
  "verification_count": 3,
  "created_at": Timestamp("2025-01-25T08:30:00Z"),
  "updated_at": Timestamp("2025-01-30T14:22:00Z"),
  "resolved_at": null,  // Set when status = RESOLVED
  "assigned_at": Timestamp("2025-01-26T10:00:00Z"),
  "field_updates": [
    {
      "timestamp": Timestamp("2025-01-28T09:30:00Z"),
      "status": "IN_PROGRESS",
      "engineer_id": "user_doc_id",
      "message": "Repair crew on site",
      "photos": ["gs://bucket/image1.jpg", "gs://bucket/image2.jpg"]
    }
  ]
}

// Field Descriptions:
// - detection_id (string, required): Reference to verified_potholes or detections
// - status (string, required): Current status of the issue
// - severity (number, required): 1 (LOW) | 2 (MEDIUM) | 3 (HIGH)
// - latitude (number, required): Latitude of issue location
// - longitude (number, required): Longitude of issue location
// - address (string, optional): Human-readable address
// - assigned_to (string, optional): user_id of assigned field engineer
// - priority (string, required): LOW | MEDIUM | HIGH (impacts repair timeline)
// - notes (string, optional): Additional notes from municipality
// - description (string, optional): Description of the issue
// - reporter_id (string, optional): ID of user who reported it
// - verification_count (number, required): Number of users who verified this issue
// - created_at (timestamp, required): When issue was created in system
// - updated_at (timestamp, required): When issue was last updated
// - resolved_at (timestamp, optional): When issue was marked RESOLVED
// - assigned_at (timestamp, optional): When assigned to engineer
// - field_updates (array, optional): Array of update objects with photos/status

// Indexes needed:
// - Single: municipality_id (Ascending) - added via subcollection or explicit field
// - Single: status (Ascending) for filtering by status
// - Single: assigned_to (Ascending) for finding issues assigned to a user
// - Composite: status (Asc) + priority (Desc) + created_at (Desc) for dashboard queries
// - Single: created_at (Descending) for recent issues

// ============================================================================
// Collection: auth_logs
// Description: Audit trail of all authentication attempts
// ============================================================================

{
  "email": "admin@city.gov",
  "user_id": "doc_id_of_user",  // null for failed attempts
  "municipality_id": "doc_id_of_municipality",
  "action": "LOGIN_SUCCESS",  // LOGIN_SUCCESS | LOGIN_FAILED | LOGOUT
  "reason": null,  // Error message if LOGIN_FAILED
  "timestamp": Timestamp("2025-01-30T09:15:00Z"),
  "ip_address": "192.168.1.1"
}

// Field Descriptions:
// - email (string, required): Email attempting to login
// - user_id (string, optional): User ID if successful
// - municipality_id (string, optional): Municipality ID if successful
// - action (string, required): LOGIN_SUCCESS | LOGIN_FAILED | LOGOUT
// - reason (string, optional): Error reason if action = LOGIN_FAILED
// - timestamp (timestamp, required): When action occurred
// - ip_address (string, optional): IP address of requester

// Indexes needed:
// - Single: user_id (Ascending) for user activity history
// - Single: email (Ascending) for email-based lookups
// - Single: timestamp (Descending) for recent logs
// - Composite: action (Asc) + timestamp (Desc) for audit dashboard

// ============================================================================
// Collection: verified_potholes
// Description: Aggregated and verified pothole detections (from mobile app)
// ============================================================================

{
  "location": GeoPoint(40.7128, -74.0060),
  "geohash": "dr5reg",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "severity": 2,  // 1 (LOW) | 2 (MEDIUM) | 3 (HIGH)
  "confidence": 0.87,
  "verification_count": 5,
  "verified_user_ids": ["user1", "user2", "user3", "user4", "user5"],
  "detection_ids": ["detection1", "detection2", "detection3"],
  "first_reported": Timestamp("2025-01-20T08:30:00Z"),
  "last_updated": Timestamp("2025-01-30T09:15:00Z"),
  "municipality_issue_id": "municipality_issue_doc_id"  // Reference to municipality_issues
}

// Field Descriptions:
// - location (GeoPoint, required): Geographic coordinates for map queries
// - geohash (string, required): Geohash for clustering
// - latitude (number, required): Latitude
// - longitude (number, required): Longitude
// - severity (number, required): Aggregated severity (1=LOW, 2=MED, 3=HIGH)
// - confidence (number, required): Average confidence score
// - verification_count (number, required): Number of users who verified
// - verified_user_ids (array, required): Array of unique user IDs
// - detection_ids (array, required): Array of source detection IDs
// - first_reported (timestamp, required): When first detected
// - last_updated (timestamp, required): When last updated
// - municipality_issue_id (string, optional): Reference to municipality_issues doc

// Indexes needed:
// - Geo: location for nearby pothole queries
// - Single: geohash (Ascending) for clustering
// - Single: severity (Descending) for filtering by severity
// - Composite: severity (Desc) + verification_count (Desc) for priority sorting

// ============================================================================
// Firestore Rules (Example)
// ============================================================================

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow public read/write for user detections
    match /detections/{document=**} {
      allow create: if true;  // Anyone can submit detections
      allow read, update, delete: if false;  // Cannot modify after creation
    }

    // Protect municipality collections
    match /municipality_users/{document=**} {
      allow read: if isAuthenticated && request.auth.token.role in ['SUPER_ADMIN', 'MUNICIPAL_ADMIN'];
      allow create: if isAuthenticated && request.auth.token.role == 'SUPER_ADMIN';
      allow update: if isAuthenticated && (
        request.auth.token.role == 'SUPER_ADMIN' ||
        (request.auth.token.role == 'MUNICIPAL_ADMIN' && 
         request.auth.token.municipality_id == get(/databases/(default)/documents/municipality_users/{document}).data.municipality_id)
      );
      allow delete: if isAuthenticated && request.auth.token.role == 'SUPER_ADMIN';
    }

    match /municipalities/{document=**} {
      allow read: if isAuthenticated && request.auth.token.role in ['SUPER_ADMIN', 'MUNICIPAL_ADMIN'];
      allow write: if isAuthenticated && request.auth.token.role == 'SUPER_ADMIN';
    }

    match /municipality_issues/{document=**} {
      allow read: if isAuthenticated && canAccessMunicipality();
      allow create: if isAuthenticated && request.auth.token.role == 'SUPER_ADMIN';
      allow update: if isAuthenticated && (
        request.auth.token.role == 'SUPER_ADMIN' ||
        (request.auth.token.role == 'MUNICIPAL_ADMIN' && canAccessMunicipality()) ||
        (request.auth.token.role == 'FIELD_ENGINEER' && isAssignedToIssue())
      );
      allow delete: if isAuthenticated && request.auth.token.role == 'SUPER_ADMIN';
    }

    match /auth_logs/{document=**} {
      allow read: if isAuthenticated && request.auth.token.role in ['SUPER_ADMIN', 'MUNICIPAL_ADMIN'];
      allow create: if true;  // Created only by backend
      allow update, delete: if false;
    }

    match /verified_potholes/{document=**} {
      allow read: if true;  // Public read for map
      allow write: if false;  // Only backend can write
    }

    function isAuthenticated() {
      return request.auth != null;
    }

    function canAccessMunicipality() {
      return request.auth.token.municipality_id == resource.data.municipality_id ||
             request.auth.token.role == 'SUPER_ADMIN';
    }

    function isAssignedToIssue() {
      return request.auth.token.sub == resource.data.assigned_to;
    }
  }
}
