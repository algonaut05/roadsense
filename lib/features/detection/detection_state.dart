import '../../core/models/pothole_event.dart';
import '../../core/services/sensor_service.dart';

/// UI-facing state for the detection feature.
///
/// Data-only: the controller updates this, UI renders it.
class DetectionState {
  final bool isDetecting;
  final bool gpsReady;
  final MotionFrame? lastMotion;
  final PotholeEvent? lastEvent;

  const DetectionState({
    required this.isDetecting,
    required this.gpsReady,
    required this.lastMotion,
    required this.lastEvent,
  });

  factory DetectionState.initial() => const DetectionState(
        isDetecting: false,
        gpsReady: false,
        lastMotion: null,
        lastEvent: null,
      );

  DetectionState copyWith({
    bool? isDetecting,
    bool? gpsReady,
    MotionFrame? lastMotion,
    PotholeEvent? lastEvent,
  }) {
    return DetectionState(
      isDetecting: isDetecting ?? this.isDetecting,
      gpsReady: gpsReady ?? this.gpsReady,
      lastMotion: lastMotion ?? this.lastMotion,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

