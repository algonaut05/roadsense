import 'package:flutter/material.dart';

import 'core/services/location_service.dart';
import 'core/services/sensor_service.dart';
import 'core/services/upload_service.dart';
import 'features/detection/detection_controller.dart';
import 'features/detection/detection_screen.dart';

class RoadSenseApp extends StatefulWidget {
  const RoadSenseApp({super.key});

  @override
  State<RoadSenseApp> createState() => _RoadSenseAppState();
}

class _RoadSenseAppState extends State<RoadSenseApp> {
  late final DetectionController _controller;

  @override
  void initState() {
    super.initState();

    // Composition root: wire services + controller. No detection logic here.
    final sensorService = SensorsPlusSensorService();
    final locationService = GeolocatorLocationService();
    final uploadService = DebugUploadService();

    _controller = DetectionController(
      sensorService: sensorService,
      locationService: locationService,
      uploadService: uploadService,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadSense',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: DetectionScreen(controller: _controller),
    );
  }
}
