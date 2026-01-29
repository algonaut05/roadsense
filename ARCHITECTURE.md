# RoadSense — Architecture Contract (LOCKED)

This project follows a strict, layered, feature-driven architecture.

This file is the final authority. Any code that violates this architecture
must be rejected or refactored.

---

## 1. Core Principles

- Architecture is decided before features
- UI is dumb
- Logic lives in services
- Detection is engine-based (Rule + optional ML)
- Backend handles verification and aggregation
- No scope creep beyond frozen features

---

## 2. Layer Responsibilities

### UI (Presentation Layer)
- Flutter widgets only
- Displays data
- Triggers actions
- NO logic, NO sensors, NO math

### Controller Layer
- Orchestrates services
- Holds app state
- Decides when to call detection
- NO detection logic

### Service Layer
- Sensor access
- Detection logic
- ML inference
- GPS, upload, filters
- NO Flutter UI imports

### Detection Engines
- RuleBasedDetector (mandatory)
- MLBasedDetector (optional, pluggable)
- UI and controllers must not know which engine is used

### Models
- Data-only classes
- Shared across app and backend
- No logic inside models

---

## 3. Detection Pipeline (Locked)

Sensor Data  
→ Rule-Based Detection  
→ (Optional) ML Confirmation  
→ Pothole Event  
→ Cloud Upload  

Rule-based detection is the primary source of truth.
ML is used only for confirmation or refinement.

---

## 4. Non-Negotiable Rules

- UI must never access sensors
- UI must never contain detection logic
- Services must never import Flutter widgets
- ML must never run on raw continuous streams
- All features must map to FEATURES.md

Any violation = architecture break.
