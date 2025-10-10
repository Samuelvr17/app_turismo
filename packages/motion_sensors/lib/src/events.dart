import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

double _toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw ArgumentError('Unexpected sensor value type: ${value.runtimeType}');
}

Vector3 _vector3FromList(List<dynamic> values) {
  if (values.length != 3) {
    throw ArgumentError('Expected 3 values but received ${values.length}');
  }
  return Vector3(
    _toDouble(values[0]),
    _toDouble(values[1]),
    _toDouble(values[2]),
  );
}

class AccelerometerEvent {
  AccelerometerEvent(this.x, this.y, this.z);

  factory AccelerometerEvent.fromList(List<dynamic> values) {
    final Vector3 vector = _vector3FromList(values);
    return AccelerometerEvent(vector.x, vector.y, vector.z);
  }

  final double x;
  final double y;
  final double z;
}

class GyroscopeEvent {
  GyroscopeEvent(this.x, this.y, this.z);

  factory GyroscopeEvent.fromList(List<dynamic> values) {
    final Vector3 vector = _vector3FromList(values);
    return GyroscopeEvent(vector.x, vector.y, vector.z);
  }

  final double x;
  final double y;
  final double z;
}

class MagnetometerEvent {
  MagnetometerEvent(this.x, this.y, this.z);

  factory MagnetometerEvent.fromList(List<dynamic> values) {
    final Vector3 vector = _vector3FromList(values);
    return MagnetometerEvent(vector.x, vector.y, vector.z);
  }

  final double x;
  final double y;
  final double z;
}

class GravityEvent {
  GravityEvent(this.x, this.y, this.z);

  factory GravityEvent.fromList(List<dynamic> values) {
    final Vector3 vector = _vector3FromList(values);
    return GravityEvent(vector.x, vector.y, vector.z);
  }

  final double x;
  final double y;
  final double z;
}

class LinearAccelerationEvent {
  LinearAccelerationEvent(this.x, this.y, this.z);

  factory LinearAccelerationEvent.fromList(List<dynamic> values) {
    final Vector3 vector = _vector3FromList(values);
    return LinearAccelerationEvent(vector.x, vector.y, vector.z);
  }

  final double x;
  final double y;
  final double z;
}

class OrientationEvent {
  OrientationEvent(this.yaw, this.pitch, this.roll);

  factory OrientationEvent.fromList(List<dynamic> values) {
    if (values.length != 3) {
      throw ArgumentError('Expected 3 values for orientation but received ${values.length}');
    }
    return OrientationEvent(
      _toDouble(values[0]),
      _toDouble(values[1]),
      _toDouble(values[2]),
    );
  }

  final double yaw;
  final double pitch;
  final double roll;
}

class AbsoluteOrientationEvent {
  AbsoluteOrientationEvent(this.w, this.x, this.y, this.z);

  factory AbsoluteOrientationEvent.fromList(List<dynamic> values) {
    if (values.length != 4) {
      throw ArgumentError('Expected 4 values for quaternion but received ${values.length}');
    }
    return AbsoluteOrientationEvent(
      _toDouble(values[0]),
      _toDouble(values[1]),
      _toDouble(values[2]),
      _toDouble(values[3]),
    );
  }

  final double w;
  final double x;
  final double y;
  final double z;

  Quaternion toQuaternion() => Quaternion(x, y, z, w);
}
