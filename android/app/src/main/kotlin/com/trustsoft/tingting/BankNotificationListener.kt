package com.trustsoft.tingting

import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.content.ContextCompat
import com.pravera.flutter_foreground_task.models.ForegroundServiceAction
import com.pravera.flutter_foreground_task.models.ForegroundServiceStatus
import com.pravera.flutter_foreground_task.service.ForegroundService
import com.pravera.flutter_foreground_task.service.RestartReceiver
import org.json.JSONObject
import java.io.File

/**
 * Writes every notification straight to a file the moment it arrives.
 *
 * Why this exists at all: the notification_listener_service plugin hands events
 * to Dart through a BroadcastReceiver that it registers at runtime and that
 * holds a live Flutter engine's EventSink. Its own manifest declares nothing.
 * So when no engine is running there is nobody to receive a notification at any
 * level — the event is simply gone. On HyperOS that happens every time the user
 * swipes the app off the recents list: the process is SIGKILLed, and the
 * foreground service that was holding the engine does not come back.
 *
 * A NotificationListenerService is bound by the system, not by us, and the
 * system starts our process to deliver to it. That makes this class the one
 * place that is guaranteed to be running when a bank message arrives. It does
 * the least it can: append the notification to a queue on disk. Parsing and
 * bookkeeping stay in Dart, which drains the queue the next time any engine
 * runs — see `PendingNotifications` on the Dart side.
 *
 * The user has to enable this component under Notification access, the same as
 * the plugin's one. Both can be on at once and events arriving twice are
 * harmless: raw_logs is unique on (package, title, content, post_time) and a
 * transaction's fingerprint is built from the same fields, so the second copy
 * is dropped by the database rather than by any check here.
 */
class BankNotificationListener : NotificationListenerService() {

    private val handler = Handler(Looper.getMainLooper())

    /**
     * Checks, a few seconds after a notification was queued, whether anything
     * came and read it.
     *
     * This replaces guessing at whether the engine is alive. Android offers no
     * way to ask: the foreground service keeps its ServiceRecord and its
     * permanent notification after the engine inside it dies, and the plugin's
     * restart alarm only asks whether the service is running — which that
     * zombie answers yes to, so nothing revived the engine and the queue grew
     * untouched until the app was opened by hand.
     *
     * Two time-based guesses were tried first and both had holes. A heartbeat
     * that Dart refreshes still looks fresh for minutes right after the engine
     * dies, and the age of the queue says nothing when the queue was empty
     * because this is the first notification since. Waiting to see whether the
     * queue is actually emptied has no such gap: a live engine drains in about a
     * second, so a file still sitting there is proof, not an estimate.
     */
    private val reviveIfStillQueued = Runnable {
        val file = File(filesDir, QUEUE_FILE)
        if (file.exists() && file.length() > 0L) reviveForegroundTask()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val queued = try {
            enqueue(sbn)
        } catch (e: Exception) {
            Log.e(TAG, "could not queue a notification", e)
            false
        }
        if (!queued) return

        // One check outstanding at a time: a burst of notifications should lead
        // to a single look at the queue, not one per message.
        handler.removeCallbacks(reviveIfStillQueued)
        handler.postDelayed(reviveIfStillQueued, DRAIN_GRACE_MS)
    }

    /**
     * Builds a fresh Flutter engine inside the foreground service.
     *
     * Goes through the plugin's API_RESTART action rather than its restart
     * alarm: the alarm bails out when a service record exists, which is exactly
     * the case being fixed here. API_RESTART runs `onStartCommand`, which calls
     * `createForegroundTask()` and gets an engine either way.
     *
     * A notification listener runs at a persistent process state, so this is not
     * the background start that Android 14 refuses — but it can still be
     * refused, and the queue on disk is what makes that survivable: the next
     * drain picks everything up.
     */
    private fun reviveForegroundTask() {
        Log.w(TAG, "no Dart engine has run lately, restarting the foreground task")
        try {
            ForegroundServiceStatus.setData(this, ForegroundServiceAction.API_RESTART)
            ContextCompat.startForegroundService(
                this,
                Intent(this, ForegroundService::class.java),
            )
        } catch (e: Exception) {
            Log.e(TAG, "restarting the foreground task failed, falling back to the alarm", e)
            try {
                RestartReceiver.setRestartAlarm(this, RESTART_DELAY_MS)
            } catch (e2: Exception) {
                Log.e(TAG, "the restart alarm failed too", e2)
            }
        }
    }

    /**
     * The queue is a JSON object per line, appended.
     *
     * Field names and the values behind them match what the plugin's channel
     * sends for an active notification, so both paths produce byte-identical
     * rows in raw_logs and the database dedup actually fires. Changing an
     * extraction here without changing it there would turn one bank message
     * into two transactions.
     */
    private fun enqueue(sbn: StatusBarNotification): Boolean {
        val notification = sbn.notification ?: return false
        val extras = notification.extras ?: return false

        // Ongoing notifications are never transactions — media controls, download
        // progress, and our own "đang theo dõi" one. Dart drops them anyway, but
        // ours is re-posted every time the service updates it, so keeping them
        // would slowly fill the queue with nothing but itself.
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) return false

        val json = JSONObject().apply {
            put("id", sbn.id)
            put("packageName", sbn.packageName ?: "")
            put("title", extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: "")
            put("content", extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: "")
            put("postTime", sbn.postTime)
            put("onGoing", false)
        }

        val file = File(filesDir, QUEUE_FILE)
        // A queue this long means Dart has not run for a very long time, and the
        // notifications are still on the status bar for the catch-up scan to find
        // anyway. Drop the write instead of growing without a bound.
        if (file.length() > MAX_QUEUE_BYTES) {
            Log.w(TAG, "queue is over ${MAX_QUEUE_BYTES}B, dropping this notification")
            return false
        }
        file.appendText(json.toString() + "\n")
        return true
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        // The system dropped us. Asking to come back is the documented remedy and
        // is the whole reason the swipe left capture dead: being in the user's
        // allowed list is not the same as being bound.
        Log.w(TAG, "listener disconnected, asking for a rebind")
        try {
            requestRebind(ComponentName(this, BankNotificationListener::class.java))
        } catch (e: Exception) {
            Log.e(TAG, "could not request a rebind", e)
        }
    }

    private companion object {
        const val TAG = "BankNotifListener"
        const val QUEUE_FILE = "pending_notifications.jsonl"

        const val MAX_QUEUE_BYTES = 512L * 1024
        const val RESTART_DELAY_MS = 1000

        /**
         * How long a live engine is given to drain the queue before it counts as
         * gone. Comfortably above the second or so a healthy drain takes, and
         * short enough that a transaction still shows up while the user is
         * looking at their phone.
         */
        const val DRAIN_GRACE_MS = 12_000L
    }
}
