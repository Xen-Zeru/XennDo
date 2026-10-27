package com.xennzeru.xenndo

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val settingsChannel = "xenndo/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            settingsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestNotificationPermission" -> {
                    val asked = getSharedPreferences("notification_permission", MODE_PRIVATE)
                        .getBoolean("asked", false)
                    val canRequest = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        (!asked || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS))
                    result.success(canRequest)
                }
                "notificationPermissionRequested" -> {
                    getSharedPreferences("notification_permission", MODE_PRIVATE)
                        .edit().putBoolean("asked", true).apply()
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    val detailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    } else {
                        detailsIntent
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (_: android.content.ActivityNotFoundException) {
                        try {
                            startActivity(detailsIntent)
                            result.success(true)
                        } catch (_: android.content.ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
