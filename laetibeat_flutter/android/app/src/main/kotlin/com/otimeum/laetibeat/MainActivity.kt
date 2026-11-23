package com.otimeum.laetibeat

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_COLORS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemColors" -> result.success(readSystemColors())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Reads the same finalized Material You roles Compose uses, instead of
     * rebuilding accent tones from the five CorePalette palettes.
     */
    private fun readSystemColors(): Map<String, Map<String, Int>>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null

        return mapOf(
            "light" to readRoles("light"),
            "dark" to readRoles("dark"),
        )
    }

    @Suppress("DEPRECATION")
    private fun readRoles(brightnessSuffix: String): Map<String, Int> {
        val roles = linkedMapOf<String, Int>()
        for ((role, resourceName) in ROLE_RESOURCES) {
            val id = resources.getIdentifier(
                "${resourceName}_$brightnessSuffix",
                "color",
                "android",
            )
            if (id != 0) {
                roles[role] = resources.getColor(id)
            }
        }
        return roles
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
        const val SYSTEM_COLORS_CHANNEL = "com.otimeum.laetibeat/system_colors"

        val ROLE_RESOURCES = linkedMapOf(
            "primary" to "system_primary",
            "onPrimary" to "system_on_primary",
            "primaryContainer" to "system_primary_container",
            "onPrimaryContainer" to "system_on_primary_container",
            "secondary" to "system_secondary",
            "onSecondary" to "system_on_secondary",
            "secondaryContainer" to "system_secondary_container",
            "onSecondaryContainer" to "system_on_secondary_container",
            "tertiary" to "system_tertiary",
            "onTertiary" to "system_on_tertiary",
            "tertiaryContainer" to "system_tertiary_container",
            "onTertiaryContainer" to "system_on_tertiary_container",
            "error" to "system_error",
            "onError" to "system_on_error",
            "errorContainer" to "system_error_container",
            "onErrorContainer" to "system_on_error_container",
            "surface" to "system_surface",
            "onSurface" to "system_on_surface",
            "onSurfaceVariant" to "system_on_surface_variant",
            "surfaceContainerLowest" to "system_surface_container_lowest",
            "surfaceContainerLow" to "system_surface_container_low",
            "surfaceContainer" to "system_surface_container",
            "surfaceContainerHigh" to "system_surface_container_high",
            "surfaceContainerHighest" to "system_surface_container_highest",
            "surfaceDim" to "system_surface_dim",
            "surfaceBright" to "system_surface_bright",
            "outline" to "system_outline",
            "outlineVariant" to "system_outline_variant",
            "inverseSurface" to "system_inverse_surface",
            "onInverseSurface" to "system_inverse_on_surface",
            "inversePrimary" to "system_inverse_primary",
            "shadow" to "system_shadow",
            "scrim" to "system_scrim",
            "surfaceTint" to "system_surface_tint",
        )
    }
}
