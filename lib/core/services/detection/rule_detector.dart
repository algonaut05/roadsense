import 'dart:math' as math;
import 'dart:developer' as dev;

import '../../models/pothole_event.dart';
import '../../models/processed_motion.dart';
import '../../models/severity.dart';
import '../../models/vehicle_type.dart';
import '../../utils/signal_filters.dart';
import '../location_service.dart';
import '../sensor_service.dart';
import 'detection_engine.dart';

/// Mandatory, default detection engine (rule-based).
///
/// ## Orientation-independent signal
/// This detector does **not** assume phone axes map to world axes.
/// It computes an orientation-independent **vertical linear acceleration**
/// signal by estimating gravity from the full accelerometer vector and
/// projecting \((a - g)\) onto the gravity direction. This makes detection
/// robust when the phone is rotated, tilted, or handheld.
///
/// ## Source of truth
/// Rule-based detection is the **primary** decision-maker in the pipeline.
/// Any optional ML component may only confirm/refine a *positive* rule trigger;
/// it must not override a negative rule decision.
///
/// ## Gating / stability
/// - **Speed gate**: if speed is known and < 5 km/h, ignore detections to
///   reduce false positives when stationary/creeping.
/// - **Cooldown**: enforce a minimum time between detections to prevent
///   double-firing on a single bump.
///
/// Logic (hackathon-grade):
/// - Compute orientation-independent vertical acceleration from full accel
///   vector (gravity-aware).
/// - High-pass filter the vertical signal to emphasize sharp bumps.
/// - Detect sharp spikes via amplitude threshold.
/// - Use different thresholds for bike vs car.
/// - Ignore detection when speed is known and < 5 km/h.
class RuleBasedDetector implements DetectionEngine {
  final VehicleType vehicleType;

  /// High-pass cutoff to remove slow components (gravity/tilt).
  final double highPassCutoffHz;

  /// Minimum time between detections (prevents double-firing).
  final Duration cooldown;

  final HighPassFilter _hp;
  final VerticalAccelerationEstimator _vertical;
  DateTime? _prevTimestamp;
  DateTime? _lastDetection;
  final bool minimalFiltering;

  RuleBasedDetector({
    this.vehicleType = VehicleType.car,
    this.highPassCutoffHz = 1.0,
    this.cooldown = const Duration(milliseconds: 900),
    this.debug = false,
    this.minimalFiltering = false,
  })  : _hp = HighPassFilter(cutoffHz: highPassCutoffHz),
        _vertical = VerticalAccelerationEstimator();

  /// When true, logs amplitudes, thresholds and confidence for debugging.
  final bool debug;

  @override
  PotholeEvent? detect({
    required MotionFrame motion,
    LocationFix? location,
  }) {
    // Keep filter state up to date regardless of whether we "use" this frame.
    final dtSeconds = _computeDtSeconds(motion.timestamp);

    double amplitude;

    if (minimalFiltering) {
      // Simple, device-agnostic magnitude-based linear accel estimate:
      // amplitude = | sqrt(ax^2+ay^2+az^2) - g | . This avoids gravity estimator
      // and high-pass filters so detection is very sensitive for testing.
      const g = 9.81;
      final rawMag = math.sqrt(motion.ax * motion.ax + motion.ay * motion.ay + motion.az * motion.az);
      amplitude = (rawMag - g).abs();
    } else {
      // Normal pipeline: gravity-aware vertical accel + high-pass
      final ProcessedMotion processed = _vertical.process(
        ax: motion.ax,
        ay: motion.ay,
        az: motion.az,
        dtSeconds: dtSeconds,
        timestamp: motion.timestamp,
      );
      final vHp = _hp.update(input: processed.verticalAccel, dtSeconds: dtSeconds);
      amplitude = vHp.abs();
    }

    // Ignore detection at very low speeds (if speed is known).
    final speedMps = location?.speedMps;
    if (speedMps != null) {
      final speedKmh = speedMps * 3.6;
      if (speedKmh < 5.0) return null;
    }

    // Use the current motion timestamp for event timing.
    final eventTimestamp = motion.timestamp;

    // Cooldown to avoid multiple triggers from one bump.
    if (_lastDetection != null && eventTimestamp.difference(_lastDetection!) < cooldown) {
      return null;
    }

    final (lowT, medT, highT) = _thresholdsFor(vehicleType);

    if (debug) {
      dev.log(
        'DETECT: amp=${amplitude.toStringAsFixed(3)} thresholds=(${lowT.toStringAsFixed(2)},${medT.toStringAsFixed(2)},${highT.toStringAsFixed(2)})',
        name: 'roadsense.detector',
      );
    }

    if (amplitude < lowT) return null;

    final severity = amplitude >= highT
        ? Severity.high
        : amplitude >= medT
            ? Severity.medium
            : Severity.low;

    // Map amplitude to a simple confidence score [0,1].
    // Rule-based is authoritative; confidence can help downstream refinement.
    final normalized = (amplitude - lowT) / math.max(0.0001, highT - lowT);
    final confidence = (0.6 + 0.4 * normalized).clamp(0.0, 1.0);

    if (debug) {
      dev.log(
        'DETECT: severity=$severity confidence=${confidence.toStringAsFixed(3)}',
        name: 'roadsense.detector',
      );
    }

    _lastDetection = eventTimestamp;

    return PotholeEvent(
      detectedAt: eventTimestamp,
      severity: severity,
      confidence: confidence,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
  }

  double _computeDtSeconds(DateTime now) {
    final prev = _prevTimestamp;
    _prevTimestamp = now;

    if (prev == null) return 0.02; // assume ~50Hz first frame
    final us = now.difference(prev).inMicroseconds;
    if (us <= 0) return 0.02;
    return us / 1e6;
  }

  /// Returns (low, medium, high) spike thresholds for high-pass vertical
  /// amplitude.
  ///
  /// Units: m/s^2 (accelerometer).
  (double, double, double) _thresholdsFor(VehicleType type) {
    // Lowered thresholds; supports minimalFiltering mode.
    switch (type) {
      case VehicleType.bike:
        // Bikes feel sharper bumps; lower thresholds.
        return minimalFiltering ? (1.0, 2.0, 3.0) : (2.0, 4.0, 6.0);
      case VehicleType.car:
        return minimalFiltering ? (1.5, 3.0, 4.5) : (3.0, 6.0, 9.0);
    }
  }
}

