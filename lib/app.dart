import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/services/firestore_upload_service.dart';
import 'core/services/location_service.dart';
import 'core/services/municipality_auth_service.dart';
import 'core/services/sensor_service.dart';
import 'features/auth/login_landing_page.dart';
import 'features/auth/municipality_login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/detection/detection_controller.dart';
import 'features/detection/detection_screen.dart';

enum AppScreen { splash, login, userMode, municipalityLogin }

class RoadSenseApp extends StatefulWidget {
  const RoadSenseApp({super.key});

  @override
  State<RoadSenseApp> createState() => _RoadSenseAppState();
}

class _RoadSenseAppState extends State<RoadSenseApp> {
  late final DetectionController _detectionController;
  late final MunicipalityAuthService _authService;
  AppScreen _currentScreen = AppScreen.splash;

  @override
  void initState() {
    super.initState();

    // Initialize auth service
    _authService = MunicipalityAuthService();

    // Composition root: wire services + controller. No detection logic here.
    final sensorService = SensorsPlusSensorService();
    final locationService = GeolocatorLocationService();
    final uploadService = FirestoreUploadService(
      FirebaseFirestore.instanceFor(
        databaseId: 'roadse',
        app: Firebase.app(),
      ),
    );

    _detectionController = DetectionController(
      sensorService: sensorService,
      locationService: locationService,
      uploadService: uploadService,
    );

    // Simulate splash screen delay, then navigate to login
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentScreen = AppScreen.login;
        });
      }
    });
  }

  @override
  void dispose() {
    _detectionController.dispose();
    super.dispose();
  }

  void _navigateToUserMode() {
    setState(() {
      _currentScreen = AppScreen.userMode;
    });
  }

  void _navigateToMunicipalityLogin() {
    setState(() {
      _currentScreen = AppScreen.municipalityLogin;
    });
  }

  void _backToLogin() {
    setState(() {
      _currentScreen = AppScreen.login;
    });
  }


  Widget _buildScreen() {
    switch (_currentScreen) {
      case AppScreen.splash:
        return const SplashScreen();

      case AppScreen.login:
        return LoginLandingPage(
          onUserLoginPressed: _navigateToUserMode,
          onMunicipalityLoginPressed: _navigateToMunicipalityLogin,
        );

      case AppScreen.userMode:
        return DetectionScreen(controller: _detectionController);

      case AppScreen.municipalityLogin:
        return MunicipalityLoginScreen(
          authService: _authService,
          onLoginSuccess: () {
            // TODO: Navigate to municipality dashboard after successful login
            setState(() {
              _currentScreen = AppScreen.login;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Municipality dashboard coming soon!'),
              ),
            );
          },
          onBackPressed: _backToLogin,
        );
    }
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
      home: _buildScreen(),
    );
  }
}
