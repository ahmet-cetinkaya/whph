#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "app_constants.h"
#include "window_detector.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Global variable to store the main window for later access
static GtkWindow* main_window = nullptr;

// Method channel callback for getting active window and focusing windows
static void get_active_window_method_call_cb(FlMethodChannel* channel,
                                           FlMethodCall* method_call,
                                           gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getActiveWindow") == 0) {
    auto detector = WindowDetector::Create();
    WindowInfo info = detector->GetActiveWindow();

    // Create result string in format: "title,application"
    std::string result = info.title + "," + info.application;

    g_autoptr(FlValue) flutter_result = fl_value_new_string(result.c_str());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(flutter_result));
  } else if (strcmp(method, "focusWindow") == 0) {
    // Get the window title parameter
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* window_title = "whph"; // default

    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      window_title = fl_value_get_string(args);
    }

    auto detector = WindowDetector::Create();
    bool success = detector->FocusWindow(window_title);

    g_autoptr(FlValue) flutter_result = fl_value_new_bool(success);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(flutter_result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Method channel callback for window management
static void window_management_method_call_cb(FlMethodChannel* channel,
                                             FlMethodCall* method_call,
                                             gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "setWindowClass") == 0) {
    // Get the window class parameter
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* window_class = "me.ahmetcetinkaya.whph"; // default

    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      window_class = fl_value_get_string(args);
    }

    bool success = false;

#ifdef GDK_WINDOWING_X11
    if (main_window && GDK_IS_X11_WINDOW(gtk_widget_get_window(GTK_WIDGET(main_window)))) {
      GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(main_window));
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
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Setup method channels
static void setup_method_channels(FlView* view) {
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);

  // Setup app usage method channel
  g_autoptr(FlStandardMethodCodec) app_usage_codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) app_usage_channel = fl_method_channel_new(
    messenger,
    APP_USAGE_CHANNEL,
    FL_METHOD_CODEC(app_usage_codec)
  );

  fl_method_channel_set_method_call_handler(
    app_usage_channel,
    get_active_window_method_call_cb,
    nullptr,
    nullptr
  );

  // Setup window management method channel
  g_autoptr(FlStandardMethodCodec) window_management_codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) window_management_channel = fl_method_channel_new(
    messenger,
    WINDOW_MANAGEMENT_CHANNEL,
    FL_METHOD_CODEC(window_management_codec)
  );

  fl_method_channel_set_method_call_handler(
    window_management_channel,
    window_management_method_call_cb,
    nullptr,
    nullptr
  );
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Store the main window reference for later access
  main_window = window;

  // Set window icon
  GError *error = nullptr;
  GdkPixbuf* icon = gdk_pixbuf_new_from_file("/usr/share/icons/hicolor/512x512/apps/whph.png", &error);
  if (icon != nullptr) {
    gtk_window_set_icon(window, icon);
    g_object_unref(icon);
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, APP_NAME);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, APP_NAME);
  }

  gtk_window_set_default_size(window, 1280, 720);
  
  // Conditionally show the window based on arguments to prevent flashing for CLI/minimized starts
  gboolean should_show = TRUE;
  if (self->dart_entrypoint_arguments != nullptr) {
    for (int i = 0; self->dart_entrypoint_arguments[i] != nullptr; i++) {
      if (g_strcmp0(self->dart_entrypoint_arguments[i], "--minimized") == 0 ||
          g_strcmp0(self->dart_entrypoint_arguments[i], "--sync") == 0) {
        should_show = FALSE;
        break;
      }
    }
  }

  if (!should_show) {
    // Iconify before show to prevent flash. Engine needs show to start Dart.
    gtk_window_iconify(window);
  }
  
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Setup our method channels
  setup_method_channels(view);

  gtk_widget_grab_focus(GTK_WIDGET(view));
  
  // Note: Minimized startup logic is duplicated in Flutter's PlatformInitializationService
  // but it's important to prevent the show in C++ to avoid any flash.
}


// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
