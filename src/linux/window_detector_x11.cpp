#include "window_detector.h"
#include "window_utils.h"
#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <vector>

// X11 headers (will be conditionally compiled)
#ifdef HAVE_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#endif

#ifdef HAVE_X11
WindowInfo X11WindowDetector::GetActiveWindow() {
  WindowInfo info{"unknown", "unknown"};

  Display *display = XOpenDisplay(nullptr);
  if (!display) {
    return info;
  }

  Window root = DefaultRootWindow(display);
  Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
  Atom actual_type;
  int actual_format;
  unsigned long nitems, bytes_after;
  unsigned char *prop = nullptr;

  // Get active window
  if (XGetWindowProperty(display, root, net_active_window, 0, 1, False,
                         XA_WINDOW, &actual_type, &actual_format, &nitems,
                         &bytes_after, &prop) == Success &&
      prop) {
    Window active_window = *(Window *)prop;
    XFree(prop);

    // Get window title
    Atom wm_name = XInternAtom(display, "WM_NAME", False);
    if (XGetWindowProperty(display, active_window, wm_name, 0, 1024, False,
                           AnyPropertyType, &actual_type, &actual_format,
                           &nitems, &bytes_after, &prop) == Success &&
        prop) {
      info.title = WindowDetector::ValidateUtf8(
          std::string(reinterpret_cast<char *>(prop)));
      XFree(prop);
    }

    // Get process ID
    Atom net_wm_pid = XInternAtom(display, "_NET_WM_PID", False);
    if (XGetWindowProperty(display, active_window, net_wm_pid, 0, 1, False,
                           XA_CARDINAL, &actual_type, &actual_format, &nitems,
                           &bytes_after, &prop) == Success &&
        prop) {
      pid_t pid = *(pid_t *)prop;
      XFree(prop);

      // Get process name from /proc/pid/comm
      std::string comm_path = "/proc/" + std::to_string(pid) + "/comm";
      std::ifstream comm_file(comm_path);
      if (comm_file.is_open()) {
        std::getline(comm_file, info.application);
        info.application = WindowDetector::ValidateUtf8(info.application);
        comm_file.close();
      }
    }

    // If application name is still unknown (e.g. running in Flatpak where /proc
    // is hidden), try to get it from WM_CLASS
    if (info.application == "unknown" || info.application.empty()) {
      std::cerr << "[DEBUG] App name unknown from /proc, trying WM_CLASS..."
                << std::endl;
      Atom wm_class = XInternAtom(display, "WM_CLASS", False);
      if (XGetWindowProperty(display, active_window, wm_class, 0, 1024, False,
                             XA_STRING, &actual_type, &actual_format, &nitems,
                             &bytes_after, &prop) == Success &&
          prop) {
        // WM_CLASS contains two strings: instance name and class name.
        // We usually want the class name (second string), but sometimes
        // instance name is useful. The strings are null-terminated and
        // sequential in the buffer.

        char *str = (char *)prop;
        std::string res_name = str;
        std::string res_class = "";

        // Advance to next string if available
        size_t len = res_name.length();
        if (len <
            nitems * (actual_format / 8) - 1) { // Check if there's more data
          res_class = std::string(str + len + 1);
        }

        std::cerr << "[DEBUG] WM_CLASS found - Name: " << res_name
                  << ", Class: " << res_class << std::endl;

        XFree(prop);

        // Prefer class name, fallback to instance name
        if (!res_class.empty()) {
          info.application = WindowDetector::ValidateUtf8(res_class);
        } else if (!res_name.empty()) {
          info.application = WindowDetector::ValidateUtf8(res_name);
        }
      } else {
        std::cerr << "[DEBUG] Failed to get WM_CLASS property" << std::endl;
      }
    } else {
      std::cerr << "[DEBUG] App name found from /proc: " << info.application
                << std::endl;
    }
  }

  XCloseDisplay(display);
  return info;
}

bool X11WindowDetector::IsX11Available() {
  Display *display = XOpenDisplay(nullptr);
  if (display) {
    XCloseDisplay(display);
    return true;
  }
  return false;
}
#else
WindowInfo X11WindowDetector::GetActiveWindow() {
  // Fallback to command execution if X11 headers not available
  WindowInfo info{"unknown", "unknown"};

  std::string window_id = ExecuteCommand(
      "xprop -root | grep '_NET_ACTIVE_WINDOW(WINDOW)' | awk '{print $5}'");
  if (window_id.empty() || window_id == "0x0") {
    return info;
  }

  std::string title_cmd =
      "xprop -id " + window_id + " | grep '^WM_NAME' | cut -d '\"' -f 2";
  info.title = WindowDetector::ValidateUtf8(ExecuteCommand(title_cmd));

  std::string pid_cmd = "xprop -id " + window_id +
                        " | grep '^_NET_WM_PID' | awk -F '= ' '{print $2}'";
  std::string pid_str = ExecuteCommand(pid_cmd);

  if (!pid_str.empty()) {
    std::string comm_cmd = "cat /proc/" + pid_str + "/comm 2>/dev/null";
    info.application = WindowDetector::ValidateUtf8(ExecuteCommand(comm_cmd));
    if (info.application.empty()) {
      std::string ps_cmd = "ps -p " + pid_str + " -o comm= 2>/dev/null";
      info.application = WindowDetector::ValidateUtf8(ExecuteCommand(ps_cmd));
    }
  }

  // Fallback to WM_CLASS if /proc failed (e.g. inside Flatpak)
  if (info.application.empty() || info.application == "unknown") {
    std::string class_cmd = "xprop -id " + window_id + " WM_CLASS 2>/dev/null";
    std::string class_res = ExecuteCommand(class_cmd);

    std::string parsed_app = ParseXpropWmClass(class_res);
    if (!parsed_app.empty()) {
      info.application = WindowDetector::ValidateUtf8(parsed_app);
    }
  }

  return info;
}

std::string X11WindowDetector::ParseXpropWmClass(const std::string &input) {
  // Output format: WM_CLASS(STRING) = "instance", "class"
  std::string app_name;

  size_t first_quote = input.find('"');
  if (first_quote != std::string::npos) {
    size_t second_quote = input.find('"', first_quote + 1);
    if (second_quote != std::string::npos) {
      // Check if there is a second part
      size_t third_quote = input.find('"', second_quote + 1);
      if (third_quote != std::string::npos) {
        size_t fourth_quote = input.find('"', third_quote + 1);
        if (fourth_quote != std::string::npos) {
          // We have a class name
          app_name =
              input.substr(third_quote + 1, fourth_quote - third_quote - 1);
        }
      }

      // If we still don't have an app name, use instance name
      if (app_name.empty()) {
        app_name =
            input.substr(first_quote + 1, second_quote - first_quote - 1);
      }
    }
  }
  return app_name;
}

bool X11WindowDetector::IsX11Available() {
  return !ExecuteCommand("which xprop 2>/dev/null").empty();
}
#endif

// X11WindowDetector focus implementation
bool X11WindowDetector::FocusWindow(const std::string &windowTitle) {
#ifdef HAVE_X11
  if (!IsX11Available()) {
    return false;
  }

  Display *display = XOpenDisplay(nullptr);
  if (!display) {
    return false;
  }

  Window root = DefaultRootWindow(display);
  Atom net_client_list = XInternAtom(display, "_NET_CLIENT_LIST", False);
  Atom net_wm_name = XInternAtom(display, "_NET_WM_NAME", False);
  Atom utf8_string = XInternAtom(display, "UTF8_STRING", False);

  Atom actual_type;
  int actual_format;
  unsigned long nitems, bytes_after;
  Window *windows = nullptr;

  // Get list of all windows
  int status = XGetWindowProperty(
      display, root, net_client_list, 0, 1024, False, XA_WINDOW, &actual_type,
      &actual_format, &nitems, &bytes_after, (unsigned char **)&windows);

  if (status != Success || !windows) {
    XCloseDisplay(display);
    return false;
  }

  bool found = false;

  for (unsigned long i = 0; i < nitems; i++) {
    Window window = windows[i];

    // Try _NET_WM_NAME first (UTF-8)
    unsigned char *name_prop = nullptr;
    status = XGetWindowProperty(display, window, net_wm_name, 0, 1024, False,
                                utf8_string, &actual_type, &actual_format,
                                &nitems, &bytes_after, &name_prop);

    std::string title;
    if (status == Success && name_prop) {
      title = std::string((char *)name_prop);
      XFree(name_prop);
    } else {
      // Fallback to WM_NAME
      char *window_name = nullptr;
      if (XFetchName(display, window, &window_name) && window_name) {
        title = std::string(window_name);
        XFree(window_name);
      }
    }

    // Check if this is our target window
    if (title.find(windowTitle) != std::string::npos || title == "whph") {
      // Focus the window
      XRaiseWindow(display, window);
      XSetInputFocus(display, window, RevertToParent, CurrentTime);
      XFlush(display);
      found = true;
      break;
    }
  }

  XFree(windows);
  XCloseDisplay(display);
  return found;
#else
  // Fallback to wmctrl if X11 headers not available
  std::string command = "wmctrl -a \"" + windowTitle +
                        "\" 2>/dev/null || wmctrl -x -a \"whph\" 2>/dev/null";
  int result = system(command.c_str());
  return result == 0;
#endif
}
