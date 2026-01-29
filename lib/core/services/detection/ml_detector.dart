import '../../models/pothole_event.dart';
import '../location_service.dart';
import '../sensor_service.dart';
import 'detection_engine.dart';

/// Optional ML-based detector/refiner (pluggable).
///
/// Per architecture:
/// - Rule-based detection remains the source of truth.
/// - ML is optional and may only confirm/refine.
///
/// This is a stub implementation for now: it delegates to a base engine.
class MlBasedDetector implements DetectionEngine {
  final DetectionEngine base;

  MlBasedDetector({required this.base});

  @override
  PotholeEvent? detect({
    required MotionFrame motion,
    LocationFix? location,
  }) {
    // Rule-first contract: do not run ML unless rule-based triggered.
    //
    // Stub behavior for now: pass-through of the base (rule) decision.
    // Later: run ML refinement only when `event != null`.
    final event = base.detect(motion: motion, location: location);
    if (event == null) return null;
    return event;
  }
}

