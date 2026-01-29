import '../../models/pothole_event.dart';
import '../location_service.dart';
import '../sensor_service.dart';

/// Contract for pothole detection engines.
///
/// ## Engine responsibilities
/// - Accept a single combined sensor frame ([MotionFrame]) plus an optional
///   location fix ([LocationFix]).
/// - Decide whether that input triggers a pothole detection *at this moment*.
/// - Return a data-only [PotholeEvent] when detection triggers.
///
/// ## Return-null contract
/// - Returning `null` means **no pothole detected** for that input frame.
/// - Callers should treat `null` as the normal/expected result most of the time.
///
/// ## Source of truth
/// - The rule-based engine is the **primary source of truth** in the pipeline.
/// - ML is optional and may only *refine/confirm* results; it must **not**
///   override a negative rule decision (i.e., ML must not "create" a pothole
///   when the rule engine returns `null`).
///
/// Non-responsibilities:
/// - No implementation logic here.
/// - No Flutter/UI imports.
abstract class DetectionEngine {
  /// Processes a single combined sensor frame and optional location fix.
  ///
  /// Returns a [PotholeEvent] if detection triggers, otherwise null.
  PotholeEvent? detect({
    required MotionFrame motion,
    LocationFix? location,
  });
}

