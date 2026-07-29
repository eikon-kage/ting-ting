package com.trustsoft.tingting

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dart gọi sang mỗi khi số liệu đổi: lưu lại rồi vẽ lại widget.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "update") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val fields = call.arguments as? Map<*, *>
                if (fields == null) {
                    result.error("bad_args", "Cần một map các dòng chữ", null)
                    return@setMethodCallHandler
                }
                saveFields(fields)
                SummaryWidgetProvider.refreshAll(applicationContext)
                result.success(null)
            }
    }

    private fun saveFields(fields: Map<*, *>) {
        val prefs = applicationContext
            .getSharedPreferences(SummaryWidgetProvider.PREFS_NAME, MODE_PRIVATE)
        val editor = prefs.edit()
        for ((key, value) in fields) {
            if (key is String && value is String) editor.putString(key, value)
        }
        editor.apply()
    }

    private companion object {
        const val WIDGET_CHANNEL = "com.trustsoft.tingting/widget"
    }
}
