package com.classified.mira

import android.app.ActivityManager
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mira/system"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryClass") {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                result.success(am.memoryClass)
            } else {
                result.notImplemented()
            }
        }
    }
}
