import 'dart:math' as math;

import '../models/processed_motion.dart';

/// Lightweight, real-time friendly signal filters.
///
/// - No Flutter imports (service-layer safe).
/// - No external DSP libraries.
/// - Designed for per-sample processing.

/// Computes the smoothing factor alpha for a first-order RC high-pass filter.
///
/// For a cutoff frequency \(f_c\) and sample interval \(dt\):
/// - \(rc = 1 / (2π f_c)\)
/// - \(alpha = rc / (rc + dt)\)
double highPassAlpha({
  required double cutoffHz,
  required double dtSeconds,
}) {
  final safeCutoff = cutoffHz <= 0 ? 0.0001 : cutoffHz;
  final safeDt = dtSeconds <= 0 ? 0.0001 : dtSeconds;

  final rc = 1.0 / (2.0 * math.pi * safeCutoff);
  return rc / (rc + safeDt);
}

/// Computes the smoothing factor alpha for a first-order RC low-pass filter.
///
/// For a cutoff frequency \(f_c\) and sample interval \(dt\):
/// - \(rc = 1 / (2π f_c)\)
/// - \(alpha = dt / (rc + dt)\)
double lowPassAlpha({
  required double cutoffHz,
  required double dtSeconds,
}) {
  final safeCutoff = cutoffHz <= 0 ? 0.0001 : cutoffHz;
  final safeDt = dtSeconds <= 0 ? 0.0001 : dtSeconds;

  final rc = 1.0 / (2.0 * math.pi * safeCutoff);
  return safeDt / (rc + safeDt);
}

/// First-order IIR high-pass filter (stateful).
///
/// Update equation:
/// y[n] = alpha * (y[n-1] + x[n] - x[n-1])
///
/// Use this for bump emphasis after computing an appropriate input signal
/// (e.g. orientation-independent vertical acceleration).
class HighPassFilter {
  final double cutoffHz;

  double _prevInput;
  double _prevOutput;

  HighPassFilter({
    required this.cutoffHz,
    double initialInput = 0.0,
    double initialOutput = 0.0,
  })  : _prevInput = initialInput,
        _prevOutput = initialOutput;

  /// Filters a single sample and returns the filtered value.
  ///
  /// Pass the time delta between samples. For many sensor streams, you can use:
  /// dtSeconds ≈ 1 / sampleRateHz (e.g. 1/50).
  double update({
    required double input,
    required double dtSeconds,
  }) {
    final alpha = highPassAlpha(cutoffHz: cutoffHz, dtSeconds: dtSeconds);
    final output = alpha * (_prevOutput + input - _prevInput);

    _prevInput = input;
    _prevOutput = output;
    return output;
  }

  /// Resets internal state.
  void reset({double input = 0.0, double output = 0.0}) {
    _prevInput = input;
    _prevOutput = output;
  }

  double get previousInput => _prevInput;
  double get previousOutput => _prevOutput;
}

/// Estimates the gravity vector from raw accelerometer readings.
///
/// This uses a simple low-pass filter (hackathon-safe) to track the slow-moving
/// gravity component even when the phone orientation changes.
class GravityEstimator {
  /// Low-pass cutoff for gravity tracking (Hz). Lower = smoother gravity.
  final double cutoffHz;

  double _gx, _gy, _gz;

  GravityEstimator({
    this.cutoffHz = 0.8,
    double initialGx = 0.0,
    double initialGy = 0.0,
    double initialGz = 9.81,
  })  : _gx = initialGx,
        _gy = initialGy,
        _gz = initialGz;

  /// Updates the gravity estimate and returns (gx, gy, gz).
  (double, double, double) update({
    required double ax,
    required double ay,
    required double az,
    required double dtSeconds,
  }) {
    final a = lowPassAlpha(cutoffHz: cutoffHz, dtSeconds: dtSeconds);
    _gx = _gx + a * (ax - _gx);
    _gy = _gy + a * (ay - _gy);
    _gz = _gz + a * (az - _gz);
    return (_gx, _gy, _gz);
  }

  void reset({double gx = 0.0, double gy = 0.0, double gz = 9.81}) {
    _gx = gx;
    _gy = gy;
    _gz = gz;
  }

  (double, double, double) get value => (_gx, _gy, _gz);
}

/// Computes an orientation-independent vertical acceleration signal.
///
/// Output is the acceleration component **along gravity** with gravity removed:
/// \(vertical = (a - g) · unit(g)\)
///
/// This stays meaningful even when the phone is tilted/rotated/handheld.
class VerticalAccelerationEstimator {
  final GravityEstimator _gravity;

  VerticalAccelerationEstimator({double gravityCutoffHz = 0.8})
      : _gravity = GravityEstimator(cutoffHz: gravityCutoffHz);

  /// Returns vertical linear acceleration (m/s^2) for this sample.
  double update({
    required double ax,
    required double ay,
    required double az,
    required double dtSeconds,
  }) {
    final (gx, gy, gz) =
        _gravity.update(ax: ax, ay: ay, az: az, dtSeconds: dtSeconds);

    final gMag = math.sqrt(gx * gx + gy * gy + gz * gz);
    if (gMag < 1e-6) return 0.0;

    final ugx = gx / gMag;
    final ugy = gy / gMag;
    final ugz = gz / gMag;

    // Linear acceleration: remove gravity estimate.
    final lax = ax - gx;
    final lay = ay - gy;
    final laz = az - gz;

    // Project linear acceleration onto gravity direction.
    return lax * ugx + lay * ugy + laz * ugz;
  }

  /// Processes a raw accelerometer sample into a data-only [ProcessedMotion].
  ///
  /// This preserves the existing [update] behavior and simply packages the
  /// computed vertical acceleration with the provided timestamp.
  ProcessedMotion process({
    required double ax,
    required double ay,
    required double az,
    required double dtSeconds,
    required DateTime timestamp,
  }) {
    final verticalAccel = update(
      ax: ax,
      ay: ay,
      az: az,
      dtSeconds: dtSeconds,
    );
    return ProcessedMotion(verticalAccel: verticalAccel, timestamp: timestamp);
  }

  void reset() => _gravity.reset();
}
