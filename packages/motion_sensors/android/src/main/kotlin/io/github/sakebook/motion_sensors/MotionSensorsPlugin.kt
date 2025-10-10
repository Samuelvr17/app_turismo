package io.github.sakebook.motion_sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MotionSensorsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var sensorManager: SensorManager
    private val handlers: MutableMap<String, SensorStreamHandler> = mutableMapOf()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        sensorManager = binding.applicationContext
            .getSystemService(Context.SENSOR_SERVICE) as SensorManager

        registerHandler(
            binding,
            ACCELEROMETER_CHANNEL,
            Sensor.TYPE_ACCELEROMETER
        ) { event ->
            listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble())
        }

        registerHandler(
            binding,
            GYROSCOPE_CHANNEL,
            Sensor.TYPE_GYROSCOPE
        ) { event ->
            listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble())
        }

        registerHandler(
            binding,
            MAGNETOMETER_CHANNEL,
            Sensor.TYPE_MAGNETIC_FIELD
        ) { event ->
            listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble())
        }

        registerHandler(
            binding,
            GRAVITY_CHANNEL,
            Sensor.TYPE_GRAVITY
        ) { event ->
            listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble())
        }

        registerHandler(
            binding,
            LINEAR_ACCELERATION_CHANNEL,
            Sensor.TYPE_LINEAR_ACCELERATION
        ) { event ->
            listOf(event.values[0].toDouble(), event.values[1].toDouble(), event.values[2].toDouble())
        }

        registerHandler(
            binding,
            ORIENTATION_CHANNEL,
            Sensor.TYPE_ROTATION_VECTOR
        ) { event ->
            val rotationMatrix = FloatArray(9)
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            val orientations = FloatArray(3)
            SensorManager.getOrientation(rotationMatrix, orientations)
            listOf(
                orientations[0].toDouble(),
                orientations[1].toDouble(),
                orientations[2].toDouble()
            )
        }

        registerHandler(
            binding,
            ABSOLUTE_ORIENTATION_CHANNEL,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                Sensor.TYPE_GAME_ROTATION_VECTOR
            } else {
                Sensor.TYPE_ROTATION_VECTOR
            }
        ) { event ->
            val quaternion = FloatArray(4)
            SensorManager.getQuaternionFromVector(quaternion, event.values)
            listOf(
                quaternion[0].toDouble(),
                quaternion[1].toDouble(),
                quaternion[2].toDouble(),
                quaternion[3].toDouble()
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        handlers.values.forEach { it.dispose() }
        handlers.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "setUpdateInterval") {
            val sensorName = call.argument<String>("sensor")
            val interval = call.argument<Int>("interval")
            val handler = handlers[sensorName]
            if (sensorName == null || interval == null || handler == null) {
                result.error("argument_error", "Invalid arguments", null)
                return
            }
            handler.setUpdateInterval(interval)
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    private fun registerHandler(
        binding: FlutterPlugin.FlutterPluginBinding,
        channelName: String,
        sensorType: Int,
        mapper: (SensorEvent) -> Any
    ) {
        val channel = EventChannel(binding.binaryMessenger, channelName)
        val handler = SensorStreamHandler(sensorManager, sensorType, mapper)
        channel.setStreamHandler(handler)
        handlers[channelName] = handler
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "motion_sensors/method"
        private const val ACCELEROMETER_CHANNEL = "motion_sensors/accelerometer"
        private const val GYROSCOPE_CHANNEL = "motion_sensors/gyroscope"
        private const val MAGNETOMETER_CHANNEL = "motion_sensors/magnetometer"
        private const val GRAVITY_CHANNEL = "motion_sensors/gravity"
        private const val LINEAR_ACCELERATION_CHANNEL = "motion_sensors/linear_acceleration"
        private const val ORIENTATION_CHANNEL = "motion_sensors/orientation"
        private const val ABSOLUTE_ORIENTATION_CHANNEL = "motion_sensors/absolute_orientation"
    }
}

private class SensorStreamHandler(
    private val sensorManager: SensorManager,
    private val sensorType: Int,
    private val mapper: (SensorEvent) -> Any
) : EventChannel.StreamHandler, SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private var samplingPeriodUs: Int = SensorManager.SENSOR_DELAY_GAME
    private var sensor: Sensor? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        sensor = sensorManager.getDefaultSensor(sensorType)
        sensor?.let {
            sensorManager.registerListener(this, it, samplingPeriodUs)
        } ?: run {
            events.error("unavailable", "Sensor $sensorType not available", null)
        }
    }

    override fun onCancel(arguments: Any?) {
        sensor?.let { sensorManager.unregisterListener(this, it) }
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    override fun onSensorChanged(event: SensorEvent) {
        sink?.success(mapper(event))
    }

    fun setUpdateInterval(intervalUs: Int) {
        samplingPeriodUs = if (intervalUs > 0) intervalUs else SensorManager.SENSOR_DELAY_GAME
        sink?.let {
            sensor?.let { sensor ->
                sensorManager.unregisterListener(this, sensor)
                sensorManager.registerListener(this, sensor, samplingPeriodUs)
            }
        }
    }

    fun dispose() {
        sensor?.let { sensorManager.unregisterListener(this, it) }
    }
}
