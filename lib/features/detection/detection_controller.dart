import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/detector_mode.dart';
import '../../core/models/pothole_event.dart';
import '../../core/services/detection/detection_engine.dart';
import '../../core/services/detection/ml_detector.dart';
import '../../core/services/detection/rule_detector.dart';
import '../../core/services/location_service.dart';
import '../../core/services/sensor_service.dart';
import '../../core/services/upload_service.dart';
import 'detection_state.dart';

/// Orchestrates detection without containing detection logic.
///
/// Responsibilities:
/// - Start/stop services (sensors/location).
/// - Feed sensor+location into the selected [DetectionEngine].
/// - Update [DetectionState] for the UI.
/// - Trigger uploads (mocked for now).
class DetectionController {
  final SensorService sensorService;
  final LocationService locationService;
  final UploadService uploadService;

  late final RuleBasedDetector _ruleEngine;
  late final MlBasedDetector _mlEngine;
  DetectorMode _mode;

  DetectorMode get mode => _mode;

  final ValueNotifier<DetectionState> state =
      ValueNotifier<DetectionState>(DetectionState.initial());

  StreamSubscription<MotionFrame>? _motionSub;
  StreamSubscription<LocationFix>? _fixSub;
  LocationFix? lastKnownLocation;

  bool get gpsReady => lastKnownLocation != null;

  DetectionController({
    required this.sensorService,
    required this.locationService,
    required this.uploadService,
    DetectorMode initialMode = DetectorMode.ruleOnly,
  }) : _mode = initialMode {
    _ruleEngine = RuleBasedDetector();
    _mlEngine = MlBasedDetector(base: _ruleEngine);
  }

  void setMode(DetectorMode mode) {
    _mode = mode;
  }

  DetectionEngine _activeEngine() {
    switch (_mode) {
      case DetectorMode.ruleOnly:
        return _ruleEngine;
      case DetectorMode.rulePlusMl:
        // ML wraps rule-based. ML must not run unless rule triggered
        // (enforced inside MlBasedDetector).
        return _mlEngine;
    }
  }

  Future<void> startDetection() async {
    if (state.value.isDetecting) return;

    state.value = state.value.copyWith(isDetecting: true);

    await sensorService.start();
    // GPS is best-effort enrichment. Do not block detection on permission/fixes.
    unawaited(locationService.start());

    _fixSub ??= locationService.locationStream.listen((fix) {
      lastKnownLocation = fix;
      if (!state.value.gpsReady) {
        state.value = state.value.copyWith(gpsReady: true);
      }
    });

    _motionSub ??= sensorService.motionFrames.listen((motion) async {
      // Controller does not "detect"—it delegates to the engine.
      final event =
          _activeEngine().detect(motion: motion, location: lastKnownLocation);

      final PotholeEvent? enrichedEvent;
      if (event == null) {
        enrichedEvent = null;
      } else if (lastKnownLocation == null) {
        enrichedEvent = event;
      } else {
        // Best-effort enrichment: never wait for GPS, only attach if available.
        enrichedEvent = PotholeEvent(
          detectedAt: event.detectedAt,
          severity: event.severity,
          confidence: event.confidence,
          latitude: lastKnownLocation!.latitude,
          longitude: lastKnownLocation!.longitude,
        );
      }

      state.value = state.value.copyWith(
        lastMotion: motion,
        lastEvent: enrichedEvent ?? state.value.lastEvent,
      );

      if (enrichedEvent != null) {
        await uploadService.uploadDetection(enrichedEvent);
      }
    });
  }

  Future<void> stopDetection() async {
    if (!state.value.isDetecting) return;

    state.value = state.value.copyWith(isDetecting: false);

    await _motionSub?.cancel();
    _motionSub = null;

    await _fixSub?.cancel();
    _fixSub = null;
    lastKnownLocation = null;

    await sensorService.stop();
    await locationService.stop();
  }

  void dispose() {
    // Best-effort cleanup.
    _motionSub?.cancel();
    _fixSub?.cancel();
    sensorService.dispose();
    locationService.dispose();
    state.dispose();
  }
}

