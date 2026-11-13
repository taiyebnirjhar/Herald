package com.taiyebnirjhar.herald

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UpdateChannel(applicationContext).register(flutterEngine)
        val runtime = ProotRuntime(applicationContext)
        RuntimeChannel(
            runtime = runtime,
            hermes = HermesInstaller(applicationContext, runtime),
            downloads = BackgroundDownloads(applicationContext),
            service = { script -> HermesService.start(applicationContext, script) },
            startSupervisor = { SupervisorService.start(applicationContext) },
        ).register(flutterEngine)
    }
}
