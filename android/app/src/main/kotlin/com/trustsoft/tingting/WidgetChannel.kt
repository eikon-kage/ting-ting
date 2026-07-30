package com.trustsoft.tingting

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The channel behind the home screen widget: Dart hands over the finished lines
 * of text, this stores them and repaints the widget.
 *
 * Lives here rather than inside [MainActivity] because the activity is not the
 * only engine the app runs. Transactions are read out of bank notifications by
 * the foreground service's isolate, which is exactly the isolate that stays
 * alive while there is no activity — and a channel registered only on the
 * activity engine answers `MissingPluginException` there. The widget then keeps
 * whatever numbers were current the last time the app was open, which is the
 * one moment it is meant to be showing something new.
 *
 * Everything here works off the application context, so nothing needs a window:
 * even the pin request goes through AppWidgetManager rather than an activity.
 */
class WidgetChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    /** Start answering Dart on [messenger]. Safe to call once per engine. */
    fun attach(messenger: BinaryMessenger) {
        detach()
        channel = MethodChannel(messenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    /** Stop answering. Call when the engine that owned the messenger goes away. */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Dart gọi sang mỗi khi số liệu đổi: lưu lại rồi vẽ lại widget.
            "update" -> {
                val fields = call.arguments as? Map<*, *>
                if (fields == null) {
                    result.error("bad_args", "Cần một map các dòng chữ", null)
                } else {
                    saveFields(fields)
                    SummaryWidgetProvider.refreshAll(context)
                    result.success(null)
                }
            }
            "canPin" -> result.success(pinSupported())
            "pin" -> result.success(requestPin())
            else -> result.notImplemented()
        }
    }

    /**
     * Launcher có nhận yêu cầu ghim widget không. Sai từ Android 7 trở xuống, và
     * ở vài launcher tự chế; chỗ nào sai thì app giấu luôn nút đi.
     */
    private fun pinSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported
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
        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(
            ComponentName(context, SummaryWidgetProvider::class.java),
            null,
            null,
        )
    }

    private fun saveFields(fields: Map<*, *>) {
        val prefs = context
            .getSharedPreferences(SummaryWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for ((key, value) in fields) {
            if (key is String && value is String) editor.putString(key, value)
        }
        editor.apply()
    }

    private companion object {
        const val CHANNEL_NAME = "com.trustsoft.tingting/widget"
    }
}
