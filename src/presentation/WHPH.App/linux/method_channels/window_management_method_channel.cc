#include "window_management_method_channel.h"
#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

// Helper to get the window from user_data
static GtkWindow* get_window(gpointer user_data) {
  if (user_data && GTK_IS_WINDOW(user_data)) {
    return GTK_WINDOW(user_data);
  }
  return nullptr;
}

void window_management_method_call_cb(FlMethodChannel* channel,
                                      FlMethodCall* method_call,
                                      gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  GtkWindow* window = get_window(user_data);

  if (strcmp(method, "setWindowClass") == 0) {
    // Get the window class parameter
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* window_class = "me.ahmetcetinkaya.whph"; // default

    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      window_class = fl_value_get_string(args);
    }

    bool success = false;

#ifdef GDK_WINDOWING_X11
    if (window && GDK_IS_X11_WINDOW(gtk_widget_get_window(GTK_WIDGET(window)))) {
      GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
      if (GDK_IS_X11_WINDOW(gdk_window)) {
        // Set the WM_CLASS property for X11 windows
        gdk_window_set_role(gdk_window, window_class);

        // Also set the class hint for better KDE integration
        XClassHint* class_hint = XAllocClassHint();
        if (class_hint) {
          class_hint->res_name = const_cast<char*>(window_class);
          class_hint->res_class = const_cast<char*>(window_class);

          XSetClassHint(GDK_DISPLAY_XDISPLAY(gdk_display_get_default()),
                        GDK_WINDOW_XID(gdk_window),
                        class_hint);

          XFree(class_hint);
          success = true;
        }
      }
    }
#endif

    g_autoptr(FlValue) flutter_result = fl_value_new_bool(success);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(flutter_result));
  } else if (strcmp(method, "setTheme") == 0) {
    // Get the theme mode parameter
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* theme_mode = "light"; // default

    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      theme_mode = fl_value_get_string(args);
    }

    gboolean prefer_dark = g_strcmp0(theme_mode, "dark") == 0;
    
    GtkSettings *settings = gtk_settings_get_default();
    g_object_set(G_OBJECT(settings), "gtk-application-prefer-dark-theme", prefer_dark, nullptr);

    g_autoptr(FlValue) flutter_result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(flutter_result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}
