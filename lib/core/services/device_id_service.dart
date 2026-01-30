import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to manage a unique device ID for crowdsourced user identification.
///
/// Generates a UUID once and stores it locally. No login required.
/// Purpose: count unique device users for pothole verification threshold.
abstract class DeviceIdService {
  Future<String> getDeviceId();
}

/// Default implementation using SharedPreferences + UUID.
class SharedPreferencesDeviceIdService implements DeviceIdService {
  static const String _key = 'roadsense_device_id';
  static const _uuid = Uuid();

  @override
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Return existing ID if available
    final existing = prefs.getString(_key);
    if (existing != null) {
      return existing;
    }

    // Generate new ID on first run
    final newId = _uuid.v4();
    await prefs.setString(_key, newId);
    return newId;
  }
}
