package com.trustsoft.tingting

import android.app.Application
import android.content.ComponentName
import android.service.notification.NotificationListenerService
import android.util.Log
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import com.pravera.flutter_foreground_task.service.RestartReceiver
import io.flutter.embedding.engine.FlutterEngine

/**
 * Runs on every process start and re-arms the two things HyperOS tears down
 * when the user swipes the app off the recents list.
 *
 * What happens on that swipe: `ProcessSceneCleaner` SIGKILLs the process. That
 * is not a service stop, so neither `ForegroundService.onDestroy` nor
 * `onTaskRemoved` gets to run — and those are the only places the plugin
 * schedules its restart alarm from. Android does restart the service itself
 * (START_STICKY), but on this device the notification listener drops out of the
 * system's live listener list and never comes back, and the persistent
 * notification never reappears. Capture is then dead until the app is opened by
 * hand, with nothing on screen saying so.
 *
 * This class is the one hook that still runs in that situation: whatever
 * component the system decides to restart, the process has to be created first,
 * and process creation calls [onCreate].
 */
class TingTingApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "process created, re-arming capture")
        serveWidgetChannelInTheService()
        scheduleServiceRestart()
        requestListenerRebind()
    }

    /**
     * Gives the capture isolate the same widget channel the activity has.
     *
     * The service creates its own FlutterEngine, and that engine only gets the
     * plugins the generated registrant knows about — a channel wired up by hand
     * in [MainActivity] is not among them. Registering the listener here rather
     * than at the call site is what makes it early enough: the engine is built
     * when the service starts, which on a restart after a swipe happens well
     * before any Dart code of ours has run.
     */
    private fun serveWidgetChannelInTheService() {
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(
            object : FlutterForegroundTaskLifecycleListener {
                private var channel: WidgetChannel? = null

                override fun onEngineCreate(flutterEngine: FlutterEngine?) {
                    val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: return
                    channel = WidgetChannel(applicationContext).also { it.attach(messenger) }
                }

                override fun onEngineWillDestroy() {
                    channel?.detach()
                    channel = null
                }

                override fun onTaskStart(starter: FlutterForegroundTaskStarter) = Unit

                override fun onTaskRepeatEvent() = Unit

                override fun onTaskDestroy() = Unit
            }
        )
    }

    /**
     * Asks the plugin's own restart alarm to check on the service.
     *
     * Unconditional on purpose: `RestartReceiver` already returns early when the
     * service is running or when the user turned tracking off through the API,
     * so this cannot resurrect something the user deliberately stopped, and it
     * cannot start a second copy. The alarm matters because it fires as a
     * broadcast, which is a context Android still allows a foreground service to
     * be started from — unlike the plain background start that a killed process
     * would otherwise have to attempt.
     */
    private fun scheduleServiceRestart() {
        try {
            RestartReceiver.setRestartAlarm(this, RESTART_DELAY_MS)
        } catch (e: Exception) {
            Log.e(TAG, "could not schedule the service restart alarm", e)
        }
    }

    /**
     * Asks the system to bind the notification listener again.
     *
     * Being in the user's allowed-listeners list is not the same as being bound:
     * after the swipe the app stays allowed but disappears from the system's
     * live listener list, so no notification is ever delivered. `requestRebind`
     * is the documented way back, and it is a no-op when the listener is already
     * connected.
     *
     * The component is named as a string because it belongs to the notification
     * listener plugin, which is also how `AndroidManifest.xml` refers to it.
     */
    private fun requestListenerRebind() {
        try {
            NotificationListenerService.requestRebind(
                ComponentName(packageName, LISTENER_CLASS)
            )
        } catch (e: Exception) {
            Log.e(TAG, "could not request a listener rebind", e)
        }
    }

    private companion object {
        const val TAG = "TingTingApp"

        /**
         * Long enough that a normal app launch has already started the service
         * and cancelled this alarm, short enough that a bank message arriving
         * right after a swipe is only missed for a few seconds.
         */
        const val RESTART_DELAY_MS = 3000

        const val LISTENER_CLASS = "notification.listener.service.NotificationListener"
    }
}
