# RoadSense — Backend Architecture (LOCKED)

The backend is responsible for verification, aggregation,
analytics, and municipality workflows.

The backend never performs raw sensor detection.

---

## Core Responsibilities

1. Accept raw pothole detections from mobile app
2. Perform crowdsourced verification
3. Aggregate severity and confidence
4. Serve verified potholes to users
5. Power municipality dashboards and workflows

---

## Backend Stack (Final)

- Firebase Firestore (database)
- Firebase Cloud Functions (logic)
- Firebase Auth (roles)
- GeoHash-based clustering

---

## Separation of Concerns

Mobile App:
- Sensor access
- Detection (rule + optional ML)
- Upload raw events

Backend:
- Verification
- Aggregation
- Routing intelligence
- Status management

---

## Data Flow (Locked)

Mobile Detection  
→ Firestore `detections`  
→ Cloud Function verification  
→ Firestore `potholes`  
→ Mobile warnings + maps  
→ Municipality workflows
