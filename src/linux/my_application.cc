#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "app_constants.h"
#include "window_detector.h"
#include "method_channels/app_usage_method_channel.h"
#include "method_channels/window_management_method_channel.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// CLI argument constants
constexpr const char* ARG_MINIMIZED = "--minimized";
constexpr const char* ARG_SYNC = "--sync";

// Global variable to store the main window for later access
static GtkWindow* main_window = nullptr;

// Helper to get the directory of the executable
std::string get_executable_dir() {
  char result[PATH_MAX];
  ssize_t count = readlink("/proc/self/exe", result, PATH_MAX);
  if (count != -1) {
    std::string path(result, count);
    size_t last_slash_idx = path.rfind('/');
    if (std::string::npos != last_slash_idx) {
      return path.substr(0, last_slash_idx);
    }
  }
  return "";
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
    app_usage_method_call_cb,
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
    main_window,
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

  // Set icon name for theme lookup (primary method for installed apps)
  gtk_window_set_icon_name(window, "me.ahmetcetinkaya.whph");

  // Set window icon fallback
  GError *error = nullptr;
  GdkPixbuf* icon = nullptr;
  
  // Try loading from standard legacy path first
  icon = gdk_pixbuf_new_from_file("/usr/share/icons/hicolor/512x512/apps/whph.png", &error);
  
  // If not found, try relative path from executable
  if (icon == nullptr) {
    if (error) {
       g_clear_error(&error); 
    }
    
    std::string exe_dir = get_executable_dir();
    if (!exe_dir.empty()) {
      // Check relative path: ../share/icons/hicolor/512x512/apps/whph.png
      // This assumes the executable is in bin/ or a similar structure relative to share/
      std::string relative_path = exe_dir + "/../share/icons/hicolor/512x512/apps/whph.png";
      icon = gdk_pixbuf_new_from_file(relative_path.c_str(), &error);
      
      // Also try local relative path for development/bundle: share/icons/hicolor/512x512/apps/whph.png
      // or simply relative to executable
       if (icon == nullptr) {
         if (error) {
           g_clear_error(&error);
         }
         std::string local_path = exe_dir + "/share/icons/hicolor/512x512/apps/whph.png";
         icon = gdk_pixbuf_new_from_file(local_path.c_str(), &error);
       }

       // Fallback: Check in data/flutter_assets (guaranteed content)
       if (icon == nullptr) {
          if (error) {
            g_clear_error(&error);
          }
          // Path: data/flutter_assets/lib/core/domain/shared/assets/images/whph_logo.png
          std::string asset_path = exe_dir + "/data/flutter_assets/lib/core/domain/shared/assets/images/whph_logo.png";
          icon = gdk_pixbuf_new_from_file(asset_path.c_str(), &error);
       }
    }
  }

  if (icon != nullptr) {
    gtk_window_set_icon(window, icon);
    g_object_unref(icon);
  } else {
    g_warning("Failed to load icon: %s", error ? error->message : "Unknown error");
    if (error) g_error_free(error);
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
      if (g_strcmp0(self->dart_entrypoint_arguments[i], ARG_MINIMIZED) == 0 ||
          g_strcmp0(self->dart_entrypoint_arguments[i], ARG_SYNC) == 0) {
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
