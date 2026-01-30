import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

import '../models/pothole_event.dart';
import 'device_id_service.dart';
import 'upload_service.dart';

export 'device_id_service.dart' show SharedPreferencesDeviceIdService;

class FirestoreUploadService implements UploadService {
  final FirebaseFirestore _db;
  final DeviceIdService _deviceIdService;

  FirestoreUploadService(
    this._db, {
    DeviceIdService? deviceIdService,
  }) : _deviceIdService = deviceIdService ?? SharedPreferencesDeviceIdService();

  @override
  Future<void> uploadDetection(PotholeEvent event) async {
    try {
      dev.log('Starting upload detection...', name: 'roadsense.upload');
      
      final deviceId = await _deviceIdService.getDeviceId();
      dev.log('Got device ID: $deviceId', name: 'roadsense.upload');
      
      final docRef = await _db.collection('detections').add({
        'latitude': event.latitude,
        'longitude': event.longitude,
        'severity': event.severity.name.toUpperCase(),
        'confidence': event.confidence,
        'timestamp': Timestamp.fromDate(event.detectedAt),
        'userId': deviceId,
      });
      
      dev.log('✅ Detection uploaded successfully! Doc ID: ${docRef.id}', name: 'roadsense.upload');
    } catch (e) {
      dev.log('❌ Upload FAILED: $e', name: 'roadsense.upload');
      rethrow;
    }
  }
}
