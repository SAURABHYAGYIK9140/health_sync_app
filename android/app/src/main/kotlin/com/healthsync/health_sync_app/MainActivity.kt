package com.healthsync.health_sync_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onStart() {
        super.onStart()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Health Sync Channel
            val healthSyncChannel = NotificationChannel(
                "health_sync_channel",
                "Health Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for health data synchronization"
                enableVibration(false)
            }
            notificationManager?.createNotificationChannel(healthSyncChannel)

            // Background Service Channel
            val backgroundServiceChannel = NotificationChannel(
                "health_sync_foreground",
                "Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for background health sync service"
                enableVibration(false)
            }
            notificationManager?.createNotificationChannel(backgroundServiceChannel)
        }
    }
}