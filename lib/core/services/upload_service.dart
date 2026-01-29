import 'dart:developer' as dev;

import '../models/pothole_event.dart';

/// Upload / persistence service for detected pothole events.
///
/// For now (per project scope), this can be mocked. No backend implementation.
abstract class UploadService {
  Future<void> uploadDetection(PotholeEvent event);
}

/// Hackathon-safe mock uploader that logs detections.
class DebugUploadService implements UploadService {
  @override
  Future<void> uploadDetection(PotholeEvent event) async {
    dev.log(
      'UPLOAD (mock) pothole: severity=${event.severity} '
      'confidence=${event.confidence} '
      'lat=${event.latitude} lon=${event.longitude} '
      'at=${event.detectedAt.toIso8601String()}',
      name: 'roadsense.upload',
    );
  }
}

