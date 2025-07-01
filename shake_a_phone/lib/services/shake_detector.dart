import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  // Adjust these values to change shake sensitivity
  static const double _shakeThreshold = 200.0; // Increased from 30.0 to 50.0 (less sensitive)
  static const int _minShakeCount = 5;        // Increased from 3 to 5 (requires more shakes)
  static const Duration _shakeTimeout = Duration(milliseconds: 800); // Reduced window for shakes
  static const Duration _cooldownPeriod = Duration(seconds: 3); // Longer cooldown period

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShake;
  int _shakeCount = 0;
  DateTime? _lastTrigger;

  void startListening({required VoidCallback onShake}) {
    if (_accelerometerSubscription != null) return;

    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        final double acceleration = _computeAcceleration(event);
        final now = DateTime.now();

        // Check if this is a significant shake event
        if (acceleration > _shakeThreshold) {
          if (_lastShake == null || now.difference(_lastShake!) > _shakeTimeout) {
            // Reset counter if too much time elapsed
            _shakeCount = 1;
          } else {
            // Increment counter if within time window
            _shakeCount++;
          }

          _lastShake = now;

          // Check if we've reached enough shakes and not in cooldown period
          if (_shakeCount >= _minShakeCount) {
            if (_lastTrigger == null || now.difference(_lastTrigger!) > _cooldownPeriod) {
              _lastTrigger = now;
              _shakeCount = 0;
              onShake();
            }
          }
        }
      },
      onError: (error) {
        print('Shake detector error: $error');
      },
    );
  }

  double _computeAcceleration(AccelerometerEvent event) {
    // Calculate magnitude of acceleration vector
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _shakeCount = 0;
    _lastShake = null;
  }

  void dispose() {
    stopListening();
  }
}

typedef VoidCallback = void Function();

