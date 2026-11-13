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
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "describe" -> result.success(runtime.describe())
            "prootVersion" -> result.success(runtime.version())
            "installRootfs" -> inBackground(result) {
                runtime.installRootfs { stage, fraction -> reportProgress(stage, fraction) }
            }
            "runUname" -> inBackground(result) { runtime.uname() }
            else -> result.notImplemented()
        }
    }

    private var lastStage = ""
    private var lastStep = -1

    // Progress for Flutter: sent when the stage or the whole percent changes.
    private fun reportProgress(stage: String, fraction: Double) {
        val step = (fraction * 100).toInt()
        if (stage == lastStage && step == lastStep) return
        lastStage = stage
        lastStep = step
        main.post {
            channel?.invokeMethod("progress", mapOf("stage" to stage, "fraction" to fraction))
        }
    }

    private var channel: MethodChannel? = null

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
