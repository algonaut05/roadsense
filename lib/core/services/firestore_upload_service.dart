import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pothole_event.dart';
import 'upload_service.dart';

class FirestoreUploadService implements UploadService {
  final FirebaseFirestore _db;

  FirestoreUploadService(this._db);

  @override
  Future<void> uploadDetection(PotholeEvent event) async {
    await _db.collection('detections').add({
      'lat': event.latitude,
      'lng': event.longitude,
      'severity': event.severity.name.toUpperCase(),
      'confidence': event.confidence,
      'timestamp': Timestamp.fromDate(event.detectedAt),
    });
  }
}
