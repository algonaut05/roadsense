import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense/core/services/detection/rule_detector.dart';
import 'package:roadsense/core/services/location_service.dart';
import 'package:roadsense/core/services/sensor_service.dart';

MotionFrame _motion({
  required DateTime t,
  required double ax,
  required double ay,
  required double az,
}) {
  return MotionFrame(
    timestamp: t,
    ax: ax,
    ay: ay,
    az: az,
    gx: 0,
    gy: 0,
    gz: 0,
  );
}

LocationFix _loc({
  required DateTime t,
  required double speedMps,
}) {
  return LocationFix(
    timestamp: t,
    latitude: 0,
    longitude: 0,
    speedMps: speedMps,
  );
}

void _warmUpGravity({
  required RuleBasedDetector detector,
  required DateTime start,
  required MotionFrame Function(DateTime t) baselineFrame,
  required int frames,
}) {
  // Use low speed to guarantee no detections during warmup, while still letting
  // the estimator/filter internal state converge.
  for (var i = 0; i < frames; i++) {
    final t = start.add(Duration(milliseconds: 20 * i));
    detector.detect(motion: baselineFrame(t), location: _loc(t: t, speedMps: 0));
  }
}

void main() {
  group('RuleBasedDetector', () {
    test(
        'orientation independence: same vertical pattern in different rotations -> same detection outcome',
        () {
      // Car thresholds: low=6, med=9, high=12 (in detector).
      // We apply a strong vertical impulse to guarantee a detection.
      const impulse = 15.0; // m/s^2 linear acceleration along gravity
      const g = 9.81;
      final start = DateTime(2026, 1, 1);

      // Scenario A: gravity aligned with phone Z.
      final detA = RuleBasedDetector();
      _warmUpGravity(
        detector: detA,
        start: start,
        frames: 200,
        baselineFrame: (t) => _motion(t: t, ax: 0, ay: 0, az: g),
      );
      final tA = start.add(const Duration(milliseconds: 20 * 200));
      final eventA = detA.detect(
        motion: _motion(t: tA, ax: 0, ay: 0, az: g + impulse),
        location: _loc(t: tA, speedMps: 2.0), // 7.2 km/h (> 5)
      );

      // Scenario B: gravity aligned with phone X (rotated phone).
      final detB = RuleBasedDetector();
      _warmUpGravity(
        detector: detB,
        start: start,
        frames: 200,
        baselineFrame: (t) => _motion(t: t, ax: g, ay: 0, az: 0),
      );
      final tB = start.add(const Duration(milliseconds: 20 * 200));
      final eventB = detB.detect(
        motion: _motion(t: tB, ax: g + impulse, ay: 0, az: 0),
        location: _loc(t: tB, speedMps: 2.0), // 7.2 km/h (> 5)
      );

      expect(eventA, isNotNull);
      expect(eventB, isNotNull);

      // "Same detection outcome" here means both trigger and classify the same.
      expect(eventA!.severity, eventB!.severity);
    });

    test('cooldown enforcement: two spikes within cooldown -> only first triggers',
        () {
      const impulse = 15.0;
      const g = 9.81;
      final start = DateTime(2026, 1, 1);
      final det = RuleBasedDetector();

      _warmUpGravity(
        detector: det,
        start: start,
        frames: 200,
        baselineFrame: (t) => _motion(t: t, ax: 0, ay: 0, az: g),
      );

      final t1 = start.add(const Duration(milliseconds: 20 * 200));
      final e1 = det.detect(
        motion: _motion(t: t1, ax: 0, ay: 0, az: g + impulse),
        location: _loc(t: t1, speedMps: 2.0),
      );
      expect(e1, isNotNull);

      // Second impulse 200ms later (< 900ms cooldown).
      final t2 = t1.add(const Duration(milliseconds: 200));
      final e2 = det.detect(
        motion: _motion(t: t2, ax: 0, ay: 0, az: g + impulse),
        location: _loc(t: t2, speedMps: 2.0),
      );
      expect(e2, isNull);
    });

    test('speed gating: speed below 5 km/h -> no detection', () {
      const impulse = 15.0;
      const g = 9.81;
      final start = DateTime(2026, 1, 1);
      final det = RuleBasedDetector();

      _warmUpGravity(
        detector: det,
        start: start,
        frames: 200,
        baselineFrame: (t) => _motion(t: t, ax: 0, ay: 0, az: g),
      );

      final t = start.add(const Duration(milliseconds: 20 * 200));
      final event = det.detect(
        motion: _motion(t: t, ax: 0, ay: 0, az: g + impulse),
        location: _loc(t: t, speedMps: 0.5), // 1.8 km/h (< 5)
      );
      expect(event, isNull);
    });
  });
}

