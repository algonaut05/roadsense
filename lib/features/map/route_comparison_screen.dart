import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

/// F9. Route Comparison Based on Road Quality
/// Compare multiple routes and show road condition quality for each
class RouteComparisonScreen extends StatefulWidget {
  const RouteComparisonScreen({Key? key}) : super(key: key);

  @override
  State<RouteComparisonScreen> createState() => _RouteComparisonScreenState();
}

class _RouteComparisonScreenState extends State<RouteComparisonScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  Position? _currentPosition;
  List<RouteQualityData> _routes = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _selectedRouteIndex = -1;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Get current location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  /// Analyze road condition for a route
  /// This simulates fetching potholes along a route
  Future<double> _analyzeRouteQuality(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Get all verified potholes
      final snapshot = await firestore
          .collection('verified_potholes')
          .where('verified', isEqualTo: true)
          .get();

      int totalPotholes = 0;
      double totalSeverity = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final severity = data['severity'] as int? ?? 1;

        if (lat == null || lng == null) continue;

        // Check if pothole is near the route (simplified)
        // In production, use actual route polyline
        final distance = _calculateDistance(
          startPoint.latitude,
          startPoint.longitude,
          lat,
          lng,
        );

        // If within 500m of route start (simplified check)
        if (distance < 500) {
          totalPotholes++;
          totalSeverity += severity;
        }
      }

      // Calculate quality score (0-100)
      // 100 = no potholes, lower = more potholes or higher severity
      if (totalPotholes == 0) {
        return 100;
      }

      final averageSeverity = totalSeverity / totalPotholes;
      final qualityScore = 100 - (totalPotholes * 2) - (averageSeverity * 10);

      return qualityScore.clamp(0, 100);
    } catch (e) {
      print('Error analyzing route: $e');
      return 0;
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c * 1000; // Convert to meters
  }

  double _toRad(double deg) => deg * (3.14159 / 180);

  /// Search and compare routes
  Future<void> _compareRoutes() async {
    if (_startController.text.isEmpty || _endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter start and end locations')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate 3 different routes
      // In production, use Google Maps Directions API or similar
      final routes = [
        RouteQualityData(
          name: 'Fastest Route',
          distance: 12.5,
          duration: 18,
          potholeCount: 3,
          qualityScore: await _analyzeRouteQuality(
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.05,
                _currentPosition!.longitude + 0.05),
          ),
          polylinePoints: [
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.02,
                _currentPosition!.longitude + 0.02),
            LatLng(_currentPosition!.latitude + 0.05,
                _currentPosition!.longitude + 0.05),
          ],
        ),
        RouteQualityData(
          name: 'Safest Route',
          distance: 14.2,
          duration: 22,
          potholeCount: 1,
          qualityScore: await _analyzeRouteQuality(
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.04,
                _currentPosition!.longitude + 0.06),
          ),
          polylinePoints: [
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.01,
                _currentPosition!.longitude + 0.03),
            LatLng(_currentPosition!.latitude + 0.04,
                _currentPosition!.longitude + 0.06),
          ],
        ),
        RouteQualityData(
          name: 'Balanced Route',
          distance: 13.1,
          duration: 19,
          potholeCount: 2,
          qualityScore: await _analyzeRouteQuality(
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.045,
                _currentPosition!.longitude + 0.055),
          ),
          polylinePoints: [
            LatLng(_currentPosition?.latitude ?? 0,
                _currentPosition?.longitude ?? 0),
            LatLng(_currentPosition!.latitude + 0.015,
                _currentPosition!.longitude + 0.025),
            LatLng(_currentPosition!.latitude + 0.045,
                _currentPosition!.longitude + 0.055),
          ],
        ),
      ];

      // Sort by quality score (highest first)
      routes.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

      setState(() {
        _routes = routes;
        _hasSearched = true;
        _selectedRouteIndex = 0; // Select best route by default
        _isLoading = false;
      });
    } catch (e) {
      print('Error comparing routes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// Get quality indicator color
  Color _getQualityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.red;
    return Colors.red.shade900;
  }

  /// Get quality indicator text
  String _getQualityText(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Comparison'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Search section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _startController,
                    decoration: InputDecoration(
                      hintText: 'Start location',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _endController,
                    decoration: InputDecoration(
                      hintText: 'End location',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _compareRoutes,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isLoading ? 'Analyzing Routes...' : 'Compare Routes',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results section
            if (_hasSearched && _routes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Routes Found: ${_routes.length}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    // Route cards
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        final isSelected = _selectedRouteIndex == index;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedRouteIndex = index),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      route.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _getQualityColor(route.qualityScore)
                                                .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getQualityText(route.qualityScore),
                                        style: TextStyle(
                                          color: _getQualityColor(
                                            route.qualityScore,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Quality score bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Road Quality',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          '${route.qualityScore.toStringAsFixed(0)}/100',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value:
                                            route.qualityScore.clamp(0, 100) /
                                                100,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation(
                                          _getQualityColor(
                                            route.qualityScore,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Route details grid
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _RouteDetailItem(
                                      icon: Icons.straighten,
                                      label: 'Distance',
                                      value: '${route.distance} km',
                                    ),
                                    _RouteDetailItem(
                                      icon: Icons.schedule,
                                      label: 'Duration',
                                      value: '${route.duration} min',
                                    ),
                                    _RouteDetailItem(
                                      icon: Icons.warning,
                                      label: 'Potholes',
                                      value: '${route.potholeCount}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Action button
                                if (isSelected)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${route.name} selected for navigation',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Navigate with this Route'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Tips section
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Road Condition Tips',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Safest route: Minimizes pothole encounters\n• Fastest route: Shortest travel time\n• Balanced route: Good quality with reasonable time\n\nQuality score considers pothole density and severity.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Empty state
            if (_hasSearched && _routes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.route,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No routes found',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}

/// Route data model
class RouteQualityData {
  final String name;
  final double distance; // in km
  final int duration; // in minutes
  final int potholeCount;
  final double qualityScore; // 0-100
  final List<LatLng> polylinePoints;

  RouteQualityData({
    required this.name,
    required this.distance,
    required this.duration,
    required this.potholeCount,
    required this.qualityScore,
    required this.polylinePoints,
  });
}

/// Route detail item widget
class _RouteDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RouteDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
