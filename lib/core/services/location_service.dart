import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Service-layer access to GPS location and speed.
///
/// Responsibilities:
/// - Provide current location (lat/lon).
/// - Provide current speed (m/s) when available.
/// - Expose async methods and/or streams for consumers.
///
/// Non-responsibilities:
/// - Do NOT trigger detection.
/// - Do NOT contain detection logic.
/// - Do NOT import Flutter UI.
abstract class LocationService {
  /// Returns the most recent known location fix, or null if unavailable.
  Future<LocationFix?> getCurrentFix();

  /// Stream of location fixes (may be empty if provider not available).
  Stream<LocationFix> get fixes;

  /// Stream of location fixes (preferred name).
  ///
  /// This is an alias of [fixes] to keep naming consistent in the codebase.
  Stream<LocationFix> get locationStream;

  bool get isRunning;

  Future<void> start();
  Future<void> stop();
  void dispose();
}

/// Data-only representation of a GPS fix.
///
/// Kept in this file to avoid creating new files/folders.
class LocationFix {
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  /// Speed in meters/second if available from provider.
  final double? speedMps;

  const LocationFix({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.speedMps,
  });
}

/// Hackathon-safe placeholder implementation.
///
/// This keeps architecture intact even before adding a GPS plugin.
/// It never emits fixes and always returns null.
class StubLocationService implements LocationService {
  final StreamController<LocationFix> _controller =
      StreamController<LocationFix>.broadcast();

  bool _running = false;

  @override
  Stream<LocationFix> get fixes => _controller.stream;

  @override
  Stream<LocationFix> get locationStream => fixes;

  @override
  bool get isRunning => _running;

  @override
  Future<LocationFix?> getCurrentFix() async => null;

  @override
  Future<void> start() async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Real GPS-backed implementation using `geolocator`.
///
/// Notes:
/// - Permission is requested **once** on first start/use (best-effort).
/// - Consumers must treat GPS as enrichment only; this service may emit nothing.
class GeolocatorLocationService implements LocationService {
  final StreamController<LocationFix> _controller =
      StreamController<LocationFix>.broadcast();

  StreamSubscription<Position>? _sub;

  bool _running = false;
  bool _permissionRequested = false;
  bool _permissionGranted = false;

  @override
  Stream<LocationFix> get fixes => _controller.stream;

  @override
  Stream<LocationFix> get locationStream => fixes;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _ensurePermissionOnce();
    if (!_permissionGranted) return;

    // Start continuous stream. If it errors, we just stop emitting.
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        _controller.add(
          LocationFix(
            timestamp: DateTime.now(),
            latitude: pos.latitude,
            longitude: pos.longitude,
            speedMps: pos.speed,
          ),
        );
      },
      onError: (_) {
        // Best-effort only: keep silent to avoid disrupting detection.
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<LocationFix?> getCurrentFix() async {
    await _ensurePermissionOnce();
    if (!_permissionGranted) return null;

    try {
      final pos = await Geolocator.getCurrentPosition();
      return LocationFix(
        timestamp: DateTime.now(),
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensurePermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _permissionGranted = false;
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      _permissionGranted = perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
    } catch (_) {
      _permissionGranted = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

