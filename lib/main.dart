import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';


void main() {
  runApp(const RoadSenseApp());
}

class RoadSenseApp extends StatelessWidget {
  const RoadSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadSense',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isDetecting = false;
  AccelerometerEvent? lastEvent;

  void toggleDetection() {
    setState(() {
      isDetecting = !isDetecting;
    });

    if (isDetecting) {
      startListening();
    }
  }

  void startListening() {
    accelerometerEvents.listen((event) {
      if (!isDetecting) return;

      lastEvent = event;

      // 👇 THIS IS REAL SENSOR DATA
      debugPrint(
        'Accel -> x:${event.x.toStringAsFixed(2)} '
        'y:${event.y.toStringAsFixed(2)} '
        'z:${event.z.toStringAsFixed(2)}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoadSense'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 80,
              color: isDetecting ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isDetecting
                  ? 'Detecting road conditions…'
                  : 'Detection stopped',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: toggleDetection,
              child: Text(
                isDetecting ? 'Stop Detection' : 'Start Detection',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

