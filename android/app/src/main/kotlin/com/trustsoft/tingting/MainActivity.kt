package com.trustsoft.tingting

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart gọi sang mỗi khi số liệu đổi: lưu lại rồi vẽ lại widget.
                    "update" -> {
                        val fields = call.arguments as? Map<*, *>
                        if (fields == null) {
                            result.error("bad_args", "Cần một map các dòng chữ", null)
                        } else {
                            saveFields(fields)
                            SummaryWidgetProvider.refreshAll(applicationContext)
                            result.success(null)
                        }
                    }
                    "canPin" -> result.success(pinSupported())
                    "pin" -> result.success(requestPin())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Launcher có nhận yêu cầu ghim widget không. Sai từ Android 7 trở xuống, và
     * ở vài launcher tự chế; chỗ nào sai thì app giấu luôn nút đi.
     */
    private fun pinSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return AppWidgetManager.getInstance(applicationContext)
            .isRequestPinAppWidgetSupported
    }

    /**
     * Nhờ hệ thống hỏi thẳng "thêm ô này ra màn hình chính?".
     *
     * Có đường này vì khay chọn widget của HyperOS không liệt kê widget của app
     * bên thứ ba — provider đăng ký đúng, launcher vẫn không cho tìm ra. Hộp
     * thoại ghim đi qua AppWidgetManager nên không phụ thuộc cái khay đó.
     */
    private fun requestPin(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(applicationContext)
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(
            ComponentName(applicationContext, SummaryWidgetProvider::class.java),
            null,
            null,
        )
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
