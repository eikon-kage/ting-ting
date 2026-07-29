package com.trustsoft.tingting

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/**
 * Ô tổng quan thu chi ngoài màn hình chính.
 *
 * Widget chạy trong tiến trình của launcher nên không đọc được database của app.
 * Mọi con số đã được Dart tính và định dạng sẵn, đẩy sang qua MethodChannel rồi
 * cất trong SharedPreferences — ở đây chỉ có việc bơm chữ vào RemoteViews.
 */
class SummaryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it) }
    }

    companion object {
        const val PREFS_NAME = "ting_ting_widget"

        /** Khoá trong SharedPreferences -> id TextView tương ứng trên layout. */
        private val FIELDS = mapOf(
            "updated" to R.id.widget_updated,
            "label" to R.id.widget_label,
            "amount" to R.id.widget_amount,
            "income" to R.id.widget_income,
            "net" to R.id.widget_net,
            "balance" to R.id.widget_balance,
        )

        /** Vẽ lại mọi ô user đã đặt ra màn hình chính. Gọi sau mỗi lần Dart đẩy số mới. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SummaryWidgetProvider::class.java)
            )
            ids.forEach { render(context, manager, it) }
        }

        private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_summary)

            for ((key, viewId) in FIELDS) {
                // Chưa có dữ liệu thì giữ nguyên chữ mặc định trong layout.
                val text = prefs.getString(key, null) ?: continue
                views.setTextViewText(viewId, text)
            }
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))

            manager.updateAppWidget(widgetId, views)
        }

        /** Chạm vào ô -> mở app. */
        private fun openApp(context: Context): PendingIntent? {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName) ?: return null
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            return PendingIntent.getActivity(context, 0, intent, flags)
        }
    }
}
