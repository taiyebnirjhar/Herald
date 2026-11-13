package com.taiyebnirjhar.herald

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * What the native chat needs from Android (WBS 6.2): where the Hermes API server
 * listens and the key it asks for. The key stays on the phone.
 */
class EngineChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connection" -> result.success(
                mapOf(
                    "host" to HermesSupervisor.HOST,
                    "port" to Engine.GATEWAY.port,
                    "key" to ApiKey.load(context),
                ),
            )
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "herald/engine"
    }
}
