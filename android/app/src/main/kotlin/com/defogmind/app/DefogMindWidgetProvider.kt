package com.defogmind.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class DefogMindWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        DefogMindWidgetUpdater.updateWidgets(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        DefogMindWidgetUpdater.updateWidgets(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        DefogMindWidgetUpdater.updateWidgets(context)
    }
}
