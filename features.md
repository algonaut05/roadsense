# RoadSense — Frozen Feature List

## User / System Features (F1–F9)

F1. Automatic Pothole Detection  
F2. Severity Classification (Low / Medium / High)  
F3. GPS Mapping of Potholes  
F4. Crowdsourced Verification (Silent)  
F5. Upcoming Pothole Warning
   - **Logic:** This is a client-side feature. The mobile app will:
     1. Continuously monitor the user's real-time GPS location and heading.
     2. Periodically query the `verified_potholes` collection for potholes in geohash areas near the user's current location.
     3. For each nearby pothole, calculate the distance and bearing relative to the user's heading.
     4. Trigger an audible/visual alert if a verified pothole is detected within a set distance (e.g., 200m) and is in the user's forward path (i.e., the bearing is within a certain angle of the user's heading).
     5. Keep a temporary cache of alerted potholes to prevent repeated warnings for the same hazard.
F6. Live Road Condition Map  
F7. Mounted vs Handheld Mode  
F8. Vehicle Type Selection (Bike / Car)  
F9. Route Comparison Based on Road Quality  

No additional user features are allowed.

---
