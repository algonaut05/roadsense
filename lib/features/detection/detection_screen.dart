import 'package:flutter/material.dart';

import 'detection_controller.dart';
import 'detection_state.dart';

/// Dumb UI for detection feature.
///
/// Responsibilities:
/// - Render controller state.
/// - Trigger controller actions.
/// - No sensor access, no detection logic.
class DetectionScreen extends StatelessWidget {
  final DetectionController controller;

  const DetectionScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DetectionState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final last = state.lastEvent;

        return Scaffold(
          appBar: AppBar(title: const Text('RoadSense')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.isDetecting ? 'Detecting…' : 'Detection stopped',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (last == null)
                  const Text('No potholes detected yet.')
                else ...[
                  Text('Last pothole: ${last.severity}'),
                  Text('Confidence: ${last.confidence}'),
                  Text('Lat: ${last.latitude ?? '-'}'),
                  Text('Lon: ${last.longitude ?? '-'}'),
                  Text('Time: ${last.detectedAt.toIso8601String()}'),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: state.isDetecting
                      ? controller.stopDetection
                      : controller.startDetection,
                  child: Text(
                    state.isDetecting ? 'Stop Detection' : 'Start Detection',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

