// ============================================================
// INT-2 — Android AppWidget provider
// Version Stamp : v1.0
// Path: android/app/src/main/kotlin/com/example/shelf_app/ShelfWidgetProvider.kt
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   The home-screen widget is written NATIVELY; home_widget only carries
//   the data. This provider reads the shared store M5 wrote and draws the
//   day's numbers. It computes NOTHING — it only displays.
//
//   Staleness (S6): no fresh payload -> "—" and "no data", never a wrong
//   number. Tap (C6): opens the app via the deep-link route M5 minted.
//
// NOTE: this file cannot be compiled in the builder sandbox (no Android
//   SDK / JDK). It is delivered as source and verified on-device per
//   INT-2 V2/V3.
// ============================================================

package com.example.shelf_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

class ShelfWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shelf_widget)

            // M5 writes the payload under this key; the key name is
            // DO NOT TOUCH (both sides must agree).
            val raw = widgetData.getString("shelf_payload", null)

            if (raw.isNullOrBlank()) {
                // Staleness guard: never show a wrong number.
                views.setTextViewText(R.id.widget_numbers, "—")
                views.setTextViewText(R.id.widget_updated, "no data")
                views.setProgressBar(R.id.widget_progress, 100, 0, false)
            } else {
                val json = JSONObject(raw)
                val total = json.optInt("total_pages_today", 0)
                val goal = json.optInt("goal_pages", 0)
                val updated = json.optString("updated_at", "")

                views.setTextViewText(R.id.widget_numbers, "$total / $goal")

                val pct = if (goal > 0) (total * 100 / goal).coerceAtMost(100) else 0
                views.setProgressBar(R.id.widget_progress, 100, pct, false)

                views.setTextViewText(
                    R.id.widget_updated,
                    if (updated.isBlank()) "updated" else "updated $updated"
                )
            }

            // Tap (C6): open the app on the home screen route.
            val tapIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("shelf://home")
            )
            views.setOnClickPendingIntent(R.id.widget_root, tapIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
