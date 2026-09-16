package com.example.chat_app

import android.content.Intent
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get("call_engine")

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("call_engine", flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chat_app/background_calls")
            .setMethodCallHandler { call, result ->
                try {
                    val serviceIntent = Intent(applicationContext, CallListeningService::class.java)
                    when (call.method) {
                        "start" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                applicationContext.startForegroundService(serviceIntent)
                            } else {
                                applicationContext.startService(serviceIntent)
                            }
                            result.success(null)
                        }
                        "stop" -> {
                            applicationContext.stopService(serviceIntent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("BACKGROUND_CALLS", error.message, null)
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
