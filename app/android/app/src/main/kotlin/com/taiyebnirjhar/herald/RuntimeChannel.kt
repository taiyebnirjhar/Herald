package com.taiyebnirjhar.herald

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter side of [ProotRuntime] (lib/runtime/runtime_channel.dart). */
class RuntimeChannel(private val runtime: ProotRuntime) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "describe" -> result.success(runtime.describe())
            "prootVersion" -> result.success(runtime.version())
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "herald/runtime"
    }
}
