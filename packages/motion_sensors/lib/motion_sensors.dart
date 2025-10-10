library motion_sensors;

import 'dart:async';

import 'package:flutter/services.dart';

import 'src/events.dart';

export 'src/events.dart';

typedef _Mapper<T> = T Function(List<dynamic> values);

class MotionSensors {
  MotionSensors._();

  static final MotionSensors instance = MotionSensors._();

  static const MethodChannel _methodChannel = MethodChannel('motion_sensors/method');
  static const EventChannel _accelerometerChannel = EventChannel('motion_sensors/accelerometer');
  static const EventChannel _gyroscopeChannel = EventChannel('motion_sensors/gyroscope');
  static const EventChannel _magnetometerChannel = EventChannel('motion_sensors/magnetometer');
  static const EventChannel _gravityChannel = EventChannel('motion_sensors/gravity');
  static const EventChannel _linearAccelerationChannel =
      EventChannel('motion_sensors/linear_acceleration');
  static const EventChannel _orientationChannel = EventChannel('motion_sensors/orientation');
  static const EventChannel _absoluteOrientationChannel =
      EventChannel('motion_sensors/absolute_orientation');

  Stream<AccelerometerEvent>? _accelerometer;
  Stream<GyroscopeEvent>? _gyroscope;
  Stream<MagnetometerEvent>? _magnetometer;
  Stream<GravityEvent>? _gravity;
  Stream<LinearAccelerationEvent>? _linearAcceleration;
  Stream<OrientationEvent>? _orientation;
  Stream<AbsoluteOrientationEvent>? _absoluteOrientation;

  Stream<AccelerometerEvent> get accelerometer =>
      _accelerometer ??= _bind(_accelerometerChannel, AccelerometerEvent.fromList);

  Stream<GyroscopeEvent> get gyroscope =>
      _gyroscope ??= _bind(_gyroscopeChannel, GyroscopeEvent.fromList);

  Stream<MagnetometerEvent> get magnetometer =>
      _magnetometer ??= _bind(_magnetometerChannel, MagnetometerEvent.fromList);

  Stream<GravityEvent> get gravity => _gravity ??= _bind(_gravityChannel, GravityEvent.fromList);

  Stream<LinearAccelerationEvent> get linearAcceleration => _linearAcceleration ??=
      _bind(_linearAccelerationChannel, LinearAccelerationEvent.fromList);

  Stream<OrientationEvent> get orientation =>
      _orientation ??= _bind(_orientationChannel, OrientationEvent.fromList);

  Stream<AbsoluteOrientationEvent> get absoluteOrientation => _absoluteOrientation ??=
      _bind(_absoluteOrientationChannel, AbsoluteOrientationEvent.fromList);

  Stream<T> _bind<T>(EventChannel channel, _Mapper<T> mapper) {
    return channel.receiveBroadcastStream().map((dynamic event) {
      if (event is List<dynamic>) {
        return mapper(event);
      }
      throw ArgumentError('Unexpected sensor payload: ${event.runtimeType}');
    });
  }

  Future<void> setUpdateInterval(SensorType sensor, Duration interval) {
    return _methodChannel.invokeMethod<void>('setUpdateInterval', <String, dynamic>{
      'sensor': sensor.channelName,
      'interval': interval.inMicroseconds,
    });
  }
}

enum SensorType {
  accelerometer('motion_sensors/accelerometer'),
  gyroscope('motion_sensors/gyroscope'),
  magnetometer('motion_sensors/magnetometer'),
  gravity('motion_sensors/gravity'),
  linearAcceleration('motion_sensors/linear_acceleration'),
  orientation('motion_sensors/orientation'),
  absoluteOrientation('motion_sensors/absolute_orientation');

  const SensorType(this.channelName);

  final String channelName;
}

final MotionSensors motionSensors = MotionSensors.instance;
