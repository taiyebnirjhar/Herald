package com.taiyebnirjhar.herald

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * What the native chat needs from Android (WBS 6.2 and 5.2): where the Hermes API server
 * listens, the key it asks for, and saving a provider's key and model. Keys stay on the phone.
 */
class EngineChannel(
    private val context: Context,
    private val runtime: ProotRuntime,
) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())

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
            "saveProvider" -> saveProvider(call, result)
            else -> result.notImplemented()
        }
    }

    /** Checks the input, then saves it inside the Linux base on a background thread. */
    private fun saveProvider(call: MethodCall, result: MethodChannel.Result) {
        val provider = Provider.byId(call.argument<String>("provider") ?: "")
        val key = call.argument<String>("key") ?: ""
        val model = call.argument<String>("model") ?: ""
        val problem = ProviderSetup.problem(provider, key, model)
        if (problem != null || provider == null) {
            result.success(mapOf("ok" to false, "error" to (problem ?: "Pick a provider first.")))
            return
        }
        Thread({
            val outcome = runCatching {
                // The first failing command stops the rest. Output is not kept, so the key is never logged.
                ProviderSetup.commands(provider, key, model).firstNotNullOfOrNull { command ->
                    val run = runtime.runInGuest(command, fakeRoot = false, logTo = null)
                    if (run["ok"] == true) null else SAVE_FAILED
                }
            }.getOrElse { SAVE_FAILED }
            main.post {
                result.success(
                    if (outcome == null) mapOf("ok" to true) else mapOf("ok" to false, "error" to outcome),
                )
            }
        }, "save-provider").start()
    }

    companion object {
        const val CHANNEL = "herald/engine"
        private const val SAVE_FAILED = "Couldn't save the key. Make sure Hermes is set up on the Home screen."
    }
}
