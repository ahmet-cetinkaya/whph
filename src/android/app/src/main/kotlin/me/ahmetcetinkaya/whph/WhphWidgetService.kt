package me.ahmetcetinkaya.whph

import android.content.Intent
import android.widget.RemoteViewsService

class WhphWidgetService : RemoteViewsService() {
  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
    if (intent.hasExtra("is_habits_widget") && intent.getBooleanExtra("is_habits_widget", false)) {
      HabitsRemoteViewsFactory(this.applicationContext)
    } else {
      TasksRemoteViewsFactory(this.applicationContext)
    }
}
