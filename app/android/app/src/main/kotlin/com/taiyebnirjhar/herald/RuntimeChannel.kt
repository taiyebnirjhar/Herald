package com.taiyebnirjhar.herald

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Flutter side of the runtime: proot, background downloads, the Linux base and Hermes. */
class RuntimeChannel(
    private val runtime: ProotRuntime,
    private val hermes: HermesInstaller,
    private val downloads: BackgroundDownloads,
    private val service: (File) -> Unit,
    private val startSupervisor: () -> Unit,
) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun register(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "describe" -> result.success(runtime.describe())
            "prootVersion" -> result.success(runtime.version())
            "startDownload" -> {
                val url = call.argument<String>("url")
                val name = call.argument<String>("name")
                val title = call.argument<String>("title") ?: name
                val wifiOnly = call.argument<Boolean>("wifiOnly") ?: false
                if (url == null || name == null) {
                    result.error("bad_args", "No address or file name given", null)
                } else {
                    result.success(downloads.start(url, name, title ?: name, wifiOnly))
                }
            }
            "downloadStatus" -> {
                val name = call.argument<String>("name")
                if (name == null) result.error("bad_args", "No file name given", null)
                else result.success(downloads.status(name))
            }
            "installRootfs" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "No image file given", null)
                    return
                }
                inBackground(result) {
                    runtime.installRootfs(File(path)) { stage, fraction -> reportProgress(stage, fraction) }
                }
            }
            "runUname" -> inBackground(result) { runtime.uname() }
            "hermesInstall" -> {
                val script = call.argument<String>("script")
                if (script == null) {
                    result.error("bad_args", "No installer file given", null)
                } else {
                    service(File(script))
                    result.success(mapOf("started" to true))
                }
            }
            "hermesStatus" -> result.success(hermes.status())
            "startHermes" -> {
                startSupervisor()
                result.success(mapOf("started" to true))
            }
            "stopHermes" -> {
                HermesSupervisor.requestStop()
                result.success(mapOf("stopping" to true))
            }
            "hermesHealth" -> result.success(
                mapOf("phase" to HermesSupervisor.phase.name, "message" to HermesSupervisor.message),
            )
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

    // Long work (unpacking, running commands) happens off the main thread; the
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
