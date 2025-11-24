import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class OrientationReading {
  const OrientationReading({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  final double yaw; // radians
  final double pitch; // radians
  final double roll; // radians
}

class DeviceOrientationService {
  DeviceOrientationService._();

  static final DeviceOrientationService instance = DeviceOrientationService._();

  final StreamController<OrientationReading> _orientationController =
      StreamController<OrientationReading>.broadcast();
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  vm.Vector3? _lastAcc;
  vm.Vector3? _lastMag;
  vm.Vector3 _gyroOrientation = vm.Vector3.zero();
  vm.Vector3 _magBias = vm.Vector3.zero();
  DateTime? _lastGyroTimestamp;

  bool _tracking = false;

  Stream<OrientationReading> get orientationStream => _orientationController.stream;

  OrientationReading get latestReading => _latestReading;
  OrientationReading _latestReading = const OrientationReading(
    yaw: 0,
    pitch: 0,
    roll: 0,
  );

  Future<void> startTracking() async {
    if (_tracking) return;
    _tracking = true;
    _gyroOrientation = vm.Vector3.zero();
    _lastGyroTimestamp = null;

    _accSub = accelerometerEvents.listen((event) {
      _lastAcc = vm.Vector3(event.x, event.y, event.z);
      _updateFusion();
    });

    _magSub = magnetometerEvents.listen((event) {
      _lastMag = vm.Vector3(event.x, event.y, event.z) - _magBias;
      _updateFusion();
    });

    _gyroSub = gyroscopeEvents.listen((event) {
      final DateTime now = DateTime.now();
      double dt = 0.016; // default ~60Hz
      if (_lastGyroTimestamp != null) {
        dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1e6;
      }
      _lastGyroTimestamp = now;

      _gyroOrientation += vm.Vector3(event.x * dt, event.y * dt, event.z * dt);
      _updateFusion();
    });
  }

  Future<void> calibrateMagnetometer({Duration sampleDuration = const Duration(seconds: 2)}) async {
    final List<vm.Vector3> samples = <vm.Vector3>[];
    final StreamSubscription<MagnetometerEvent> sub = magnetometerEvents.listen((event) {
      samples.add(vm.Vector3(event.x, event.y, event.z));
    });

    await Future<void>.delayed(sampleDuration);
    await sub.cancel();

    if (samples.isEmpty) {
      return;
    }

    vm.Vector3 sum = vm.Vector3.zero();
    for (final vm.Vector3 s in samples) {
      sum += s;
    }
    _magBias = sum / samples.length.toDouble();
  }

  Future<void> stopTracking() async {
    _tracking = false;
    await _accSub?.cancel();
    await _magSub?.cancel();
    await _gyroSub?.cancel();
    _accSub = null;
    _magSub = null;
    _gyroSub = null;
    _lastAcc = null;
    _lastMag = null;
    _gyroOrientation = vm.Vector3.zero();
    _lastGyroTimestamp = null;
  }

  void _updateFusion() {
    if (!_tracking || _lastAcc == null || _lastMag == null) {
      return;
    }

    final vm.Vector3 acc = _lastAcc!;
    final vm.Vector3 mag = _lastMag!;

    final vm.Vector3 normAcc = acc.normalized();
    final vm.Vector3 normMag = mag.normalized();

    final double pitch = math.asin(-normAcc.x);
    final double roll = math.atan2(normAcc.y, normAcc.z);

    final double mx = normMag.x * math.cos(pitch) + normMag.z * math.sin(pitch);
    final double my = normMag.x * math.sin(roll) * math.sin(pitch) +
        normMag.y * math.cos(roll) -
        normMag.z * math.sin(roll) * math.cos(pitch);
    final double yaw = math.atan2(-my, mx);

    const double alpha = 0.98;
    _gyroOrientation = vm.Vector3(
      _wrapAngle(alpha * (_gyroOrientation.x) + (1 - alpha) * yaw),
      _wrapAngle(alpha * (_gyroOrientation.y) + (1 - alpha) * pitch),
      _wrapAngle(alpha * (_gyroOrientation.z) + (1 - alpha) * roll),
    );

    _latestReading = OrientationReading(
      yaw: _gyroOrientation.x,
      pitch: _gyroOrientation.y,
      roll: _gyroOrientation.z,
    );
    _orientationController.add(_latestReading);
  }

  double _wrapAngle(double angle) {
    // Normalize to -pi..pi
    return math.atan2(math.sin(angle), math.cos(angle));
  }
}
