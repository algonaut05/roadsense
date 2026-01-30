import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// F6. Live Road Condition Map
/// Displays real-time pothole heat map with severity indicators
class LiveRoadMapScreen extends StatefulWidget {
  const LiveRoadMapScreen({Key? key}) : super(key: key);

  @override
  State<LiveRoadMapScreen> createState() => _LiveRoadMapScreenState();
}

class _LiveRoadMapScreenState extends State<LiveRoadMapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _heatMapCircles = {};
  Position? _currentPosition;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, high, medium, low
  double _mapZoom = 15.0;

  // Heat map configuration
  static const double _heatMapRadius = 0.5; // km
  static const int _maxMarkersDisplayed = 100;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  /// Initialize map and fetch current location
  Future<void> _initializeMap() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      );

      setState(() {
        _currentPosition = position;
      });

      // Load potholes near current location
      await _loadPotsholesNearby();
    } catch (e) {
      print('Error initializing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Load potholes from Firestore and display on map
  Future<void> _loadPotsholesNearby() async {
    if (_currentPosition == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Query verified potholes collection
      final snapshot = await firestore
          .collection('verified_potholes')
          .limit(_maxMarkersDisplayed)
          .get();

      final Set<Marker> markers = {};
      final Map<String, int> heatMapData = {}; // geohash -> count

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'] as double?;
        final longitude = data['longitude'] as double?;
        final severity = data['severity'] as int? ?? 1;
        final verified = data['verified'] as bool? ?? false;

        if (latitude == null || longitude == null) continue;

        // Apply severity filter
        if (_selectedFilter != 'all') {
          final severityLabel = _getSeverityLabel(severity);
          if (_selectedFilter != severityLabel) continue;
        }

        // Skip unverified for cleaner map
        if (!verified) continue;

        final markerId = MarkerId(doc.id);
        final color = _getSeverityColor(severity);

        markers.add(
          Marker(
            markerId: markerId,
            position: LatLng(latitude, longitude),
            icon: await _getCustomMarkerIcon(color),
            infoWindow: InfoWindow(
              title: 'Pothole (Severity: ${_getSeverityLabel(severity)})',
              snippet:
                  'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
              onTap: () => _showPotholeDetails(doc.id, data),
            ),
          ),
        );

        // Add to heat map (group by geohash for clustering)
        final geohash = data['geohash'] as String? ?? 'unknown';
        heatMapData[geohash] = (heatMapData[geohash] ?? 0) + 1;
      }

      // Generate heat map circles
      _generateHeatMapCircles(snapshot.docs, heatMapData);

      setState(() {
        _markers.clear();
        _markers.addAll(markers);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading potholes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading potholes: $e')),
        );
      }
    }
  }

  /// Generate heat map circles based on pothole density
  void _generateHeatMapCircles(
    List<QueryDocumentSnapshot> docs,
    Map<String, int> heatMapData,
  ) {
    final Set<Circle> circles = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final latitude = data['latitude'] as double?;
      final longitude = data['longitude'] as double?;
      final count = heatMapData[data['geohash'] as String?] ?? 0;

      if (latitude == null || longitude == null) continue;

      // Color intensity based on density
      final color = _getHeatMapColor(count);
      final radius = _calculateHeatMapRadius(count);

      circles.add(
        Circle(
          circleId: CircleId('heat_${doc.id}'),
          center: LatLng(latitude, longitude),
          radius: radius,
          fillColor: color,
          strokeColor: color.withOpacity(0.8),
          strokeWidth: 1,
        ),
      );
    }

    setState(() {
      _heatMapCircles.clear();
      _heatMapCircles.addAll(circles);
    });
  }

  /// Get color for heat map based on pothole density
  Color _getHeatMapColor(int count) {
    if (count > 10) return Colors.red.withOpacity(0.4);
    if (count > 5) return Colors.orange.withOpacity(0.4);
    if (count > 2) return Colors.yellow.withOpacity(0.4);
    return Colors.green.withOpacity(0.4);
  }

  /// Calculate radius for heat map circle
  double _calculateHeatMapRadius(int count) {
    // Radius in meters: higher density = larger radius
    return 50 + (count * 10).toDouble();
  }

  /// Get color based on severity level
  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 3:
        return Colors.red; // High
      case 2:
        return Colors.orange; // Medium
      case 1:
      default:
        return Colors.yellow; // Low
    }
  }

  /// Get severity label
  String _getSeverityLabel(int severity) {
    switch (severity) {
      case 3:
        return 'high';
      case 2:
        return 'medium';
      case 1:
      default:
        return 'low';
    }
  }

  /// Get custom marker icon (simplified - returns default for now)
  Future<BitmapDescriptor> _getCustomMarkerIcon(Color color) async {
    // In production, create custom marker icons
    return BitmapDescriptor.defaultMarkerWithHue(
      color == Colors.red
          ? BitmapDescriptor.hueRed
          : color == Colors.orange
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueYellow,
    );
  }

  /// Show detailed information about a pothole
  void _showPotholeDetails(String potholeId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pothole Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _DetailRow('ID', potholeId),
            _DetailRow('Severity', _getSeverityLabel(data['severity'] ?? 1)),
            _DetailRow(
              'Latitude',
              (data['latitude'] as double?)?.toStringAsFixed(6) ?? 'N/A',
            ),
            _DetailRow(
              'Longitude',
              (data['longitude'] as double?)?.toStringAsFixed(6) ?? 'N/A',
            ),
            _DetailRow(
              'Verified',
              ((data['verified'] as bool?) ?? false) ? 'Yes' : 'No',
            ),
            _DetailRow(
              'Verifications',
              '${data['verification_count'] ?? 0}',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Refresh map data
  Future<void> _refreshMap() async {
    setState(() => _isLoading = true);
    await _loadPotsholesNearby();
  }

  /// Toggle heat map visibility
  void _toggleHeatMap() {
    setState(() {
      if (_heatMapCircles.isEmpty) {
        _generateHeatMapCircles([], {});
      } else {
        _heatMapCircles.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Road Condition Map'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMap,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showLegend(),
            tooltip: 'Legend',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 48),
                      const SizedBox(height: 16),
                      const Text('Location not available'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeMap,
                        child: const Text('Enable Location'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: _mapZoom,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      markers: _markers,
                      circles: _heatMapCircles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                    ),
                    // Filter controls
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter by Severity:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterButton(
                                    label: 'All',
                                    value: 'all',
                                    isSelected: _selectedFilter == 'all',
                                    onTap: () async {
                                      setState(() => _selectedFilter = 'all');
                                      await _loadPotsholesNearby();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterButton(
                                    label: 'High',
                                    value: 'high',
                                    isSelected: _selectedFilter == 'high',
                                    color: Colors.red,
                                    onTap: () async {
                                      setState(
                                        () => _selectedFilter = 'high',
                                      );
                                      await _loadPotsholesNearby();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterButton(
                                    label: 'Medium',
                                    value: 'medium',
                                    isSelected: _selectedFilter == 'medium',
                                    color: Colors.orange,
                                    onTap: () async {
                                      setState(
                                        () => _selectedFilter = 'medium',
                                      );
                                      await _loadPotsholesNearby();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterButton(
                                    label: 'Low',
                                    value: 'low',
                                    isSelected: _selectedFilter == 'low',
                                    color: Colors.yellow,
                                    onTap: () async {
                                      setState(() => _selectedFilter = 'low');
                                      await _loadPotsholesNearby();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Action buttons
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FloatingActionButton.small(
                            onPressed: _toggleHeatMap,
                            tooltip: 'Toggle Heat Map',
                            child: const Icon(Icons.layers),
                          ),
                          FloatingActionButton.small(
                            onPressed: () {
                              if (_currentPosition != null) {
                                _mapController.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      zoom: _mapZoom,
                                    ),
                                  ),
                                );
                              }
                            },
                            tooltip: 'Center on Location',
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem('High Severity', Colors.red),
            const SizedBox(height: 12),
            _LegendItem('Medium Severity', Colors.orange),
            const SizedBox(height: 12),
            _LegendItem('Low Severity', Colors.yellow),
            const SizedBox(height: 20),
            const Text(
              'Heat Map:\nDarker areas = higher pothole density',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Filter button widget
class _FilterButton extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? Colors.blue) : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (color ?? Colors.blue) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}

/// Legend item widget
class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
