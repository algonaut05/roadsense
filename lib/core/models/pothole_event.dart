import 'severity.dart';

/// Data-only representation of a detected pothole event.
///
/// This model is shared across layers (and later, backend), so it contains
/// only the *result* of detection, not the detection process.
class PotholeEvent {
  final DateTime detectedAt;
  final Severity severity;

  /// Confidence score in range [0.0, 1.0].
  ///
  /// Rule-based detection is the source of truth; this value can be used for
  /// optional ML refinement and later backend verification.
  final double confidence;

  /// GPS position if available at detection time.
  final double? latitude;
  final double? longitude;

  const PotholeEvent({
    required this.detectedAt,
    required this.severity,
    required this.confidence,
    this.latitude,
    this.longitude,
  });
}
