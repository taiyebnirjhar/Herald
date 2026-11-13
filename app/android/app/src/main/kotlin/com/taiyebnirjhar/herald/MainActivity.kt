package com.taiyebnirjhar.herald

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** A notification's route that Flutter has not picked up yet. */
    private var pendingRoute: String? = null

    /** Set once Flutter is attached; used to tell Flutter about a tap while the app is open. */
    private var navigation: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity (after the process was killed) must not open the notification's screen again.
        val route = takeRoute(intent)
        if (savedInstanceState == null) pendingRoute = route
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = takeRoute(intent) ?: return
        val channel = navigation
        if (channel != null) {
            channel.invokeMethod("route", route)
        } else {
            pendingRoute = route
        }
    }

    override fun onResume() {
        super.onResume()
        AppVisibility.resumed = true
    }

    override fun onPause() {
        AppVisibility.resumed = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        UpdateChannel(applicationContext).register(flutterEngine)
        JobNotifyChannel(applicationContext).register(flutterEngine)
        BatteryChannel(applicationContext).register(flutterEngine)
        val runtime = ProotRuntime(applicationContext)
        EngineChannel(applicationContext, runtime).register(flutterEngine)
        RuntimeChannel(
            runtime = runtime,
            hermes = HermesInstaller(applicationContext, runtime),
            downloads = BackgroundDownloads(applicationContext),
            service = { script -> HermesService.start(applicationContext, script) },
            startSupervisor = { SupervisorService.start(applicationContext) },
        ).register(flutterEngine)
        registerNavigation(flutterEngine)
    }

    /**
     * Tells Flutter which screen a notification asked for
     * "initialRoute" returns the route once; "route" is sent when a tap arrives while the app is open.
     */
    private fun registerNavigation(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        }
        navigation = channel
    }

    /** The route in [intent], cleared from it so the same tap is not handled twice. */
    private fun takeRoute(intent: Intent?): String? {
        val route = Routes.parse(intent?.getStringExtra(Routes.EXTRA))
        intent?.removeExtra(Routes.EXTRA)
        return route
    }

    companion object {
        const val NAVIGATION_CHANNEL = "herald/navigation"
    }
}
