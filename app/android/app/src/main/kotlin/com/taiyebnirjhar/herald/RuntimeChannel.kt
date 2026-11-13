package com.taiyebnirjhar.herald

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter side of [ProotRuntime] (lib/runtime/runtime_channel.dart). */
class RuntimeChannel(private val runtime: ProotRuntime) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "describe" -> result.success(runtime.describe())
            "prootVersion" -> result.success(runtime.version())
            "installRootfs" -> {
                val url = call.argument<String>("url")
                val sha = call.argument<String>("sha256")
                if (url == null || sha == null) {
                    result.error("bad_args", "No image address or checksum given", null)
                    return
                }
                inBackground(result) { runtime.installRootfs(url, sha) }
            }
            "runUname" -> inBackground(result) { runtime.uname() }
            else -> result.notImplemented()
        }
    }

    // Long work (download, extract, run) happens off the main thread; the
    // answer goes back on it, as Flutter requires.
    private fun inBackground(result: MethodChannel.Result, work: () -> Map<String, Any?>) {
        Thread({
            val answer = try {
                work()
            } catch (e: Exception) {
                mapOf("ok" to false, "error" to "${e.javaClass.simpleName}: ${e.message}")
            }
            main.post { result.success(answer) }
        }, "runtime-work").start()
    }

    companion object {
        const val CHANNEL = "herald/runtime"
    }
}
