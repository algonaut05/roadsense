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
import 'features/detection/user_home_screen.dart';
import 'features/dashboard/municipality_dashboard_screen.dart';
import 'features/map/live_road_map_screen.dart';
import 'features/map/route_comparison_screen.dart';

enum AppScreen { splash, login, userMode, municipalityLogin, municipalityDashboard, liveMap, routeComparison }

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

  void _navigateToMunicipalityDashboard() {
    setState(() {
      _currentScreen = AppScreen.municipalityDashboard;
    });
  }

  void _navigateLiveMap() {
    setState(() {
      _currentScreen = AppScreen.liveMap;
    });
  }

  void _navigateRouteComparison() {
    setState(() {
      _currentScreen = AppScreen.routeComparison;
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
        return UserHomeScreen(controller: _detectionController);

      case AppScreen.municipalityLogin:
        return MunicipalityLoginScreen(
          authService: _authService,
          onLoginSuccess: () {
            // Navigate to municipality dashboard after successful login
            setState(() {
              _currentScreen = AppScreen.municipalityDashboard;
            });
          },
          onBackPressed: _backToLogin,
        );

      case AppScreen.municipalityDashboard:
        return MunicipalityDashboardScreen(
          authService: _authService,
          onLogout: () {
            // Navigate back to login after logout
            setState(() {
              _currentScreen = AppScreen.login;
            });
          },
        );

      case AppScreen.liveMap:
        return WillPopScope(
          onWillPop: () async {
            _navigateToUserMode();
            return false;
          },
          child: const LiveRoadMapScreen(),
        );

      case AppScreen.routeComparison:
        return WillPopScope(
          onWillPop: () async {
            _navigateToUserMode();
            return false;
          },
          child: const RouteComparisonScreen(),
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
