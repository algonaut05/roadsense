import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// Service-layer access to device motion sensors.
///
/// Responsibilities:
/// - Subscribe to accelerometer and gyroscope.
/// - Expose clean, reusable streams for other layers.
/// - Do NOT perform detection logic or UI work.
abstract class SensorService {
  /// Combined motion frames emitted at ~50Hz.
  Stream<MotionFrame> get motionFrames;

  bool get isRunning;

  Future<void> start();
  Future<void> stop();
  void dispose();
}

/// A single combined sensor sample (data-only).
///
/// Kept here to avoid adding new files/folders. This is not detection logic.
class MotionFrame {
  final DateTime timestamp;

  /// Accelerometer values (m/s^2).
  final double ax;
  final double ay;
  final double az;

  /// Gyroscope values (rad/s).
  final double gx;
  final double gy;
  final double gz;

  const MotionFrame({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });
}

/// Default implementation using `sensors_plus`.
///
/// Implementation notes (hackathon-grade, real-time friendly):
/// - Subscribes to native streams (device rate can vary).
/// - Emits at ~50Hz by sampling the latest values every 20ms.
class SensorsPlusSensorService implements SensorService {
  static const Duration _targetPeriod = Duration(milliseconds: 20); // ~50Hz

  final StreamController<MotionFrame> _controller =
      StreamController<MotionFrame>.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _tick;

  // Latest sensor values. Initialized to 0 for "safe" first frames.
  double _ax = 0.0, _ay = 0.0, _az = 0.0;
  double _gx = 0.0, _gy = 0.0, _gz = 0.0;

  bool _running = false;

  @override
  Stream<MotionFrame> get motionFrames => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    _accelSub = accelerometerEventStream().listen((e) {
      _ax = e.x;
      _ay = e.y;
      _az = e.z;
    });

    _gyroSub = gyroscopeEventStream().listen((e) {
      _gx = e.x;
      _gy = e.y;
      _gz = e.z;
    });

    _tick = Timer.periodic(_targetPeriod, (_) {
      // Emit a consistent-rate combined frame for downstream processing.
      _controller.add(
        MotionFrame(
          timestamp: DateTime.now(),
          ax: _ax,
          ay: _ay,
          az: _az,
          gx: _gx,
          gy: _gy,
          gz: _gz,
        ),
      );
    });
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    _tick?.cancel();
    _tick = null;

    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  @override
  void dispose() {
    // Best-effort cleanup; callers should prefer stop() + dispose().
    _tick?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller.close();
  }
}

