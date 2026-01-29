/// Data-only output of motion preprocessing.
///
/// This model represents already-processed motion signals that are safe for
/// detectors to consume without depending on raw phone axes.
class ProcessedMotion {
  final double verticalAccel;
  final DateTime timestamp;

  const ProcessedMotion({
    required this.verticalAccel,
    required this.timestamp,
  });
}

