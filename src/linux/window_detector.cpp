#include "window_detector.h"
#include "window_utils.h"
#include <cstdlib>
#include <cstring>
#include <glib.h>
#include <iostream>
#include <memory>

std::unique_ptr<WindowDetector> WindowDetector::Create() {
  // Detect display server type
  const char *wayland_display = getenv("WAYLAND_DISPLAY");
  const char *xdg_session_type = getenv("XDG_SESSION_TYPE");
  const char *display = getenv("DISPLAY");

  if ((wayland_display && strlen(wayland_display) > 0) ||
      (xdg_session_type && strcmp(xdg_session_type, "wayland") == 0)) {
    return std::make_unique<WaylandWindowDetector>();
  } else if ((display && strlen(display) > 0) ||
             (xdg_session_type && strcmp(xdg_session_type, "x11") == 0)) {
    return std::make_unique<X11WindowDetector>();
  }

  // Fallback
  return std::make_unique<FallbackWindowDetector>();
}

// Helper function to clean quotes from strings
std::string WindowDetector::CleanQuotes(const std::string &input) {
  std::string result = input;

  if (result.empty()) {
    return result;
  }

  // Check if string is enclosed in double quotes
  if (result.size() >= 2 && result.front() == '"' && result.back() == '"') {
    result = result.substr(1, result.size() - 2);
  }
  // Check if string is enclosed in single quotes
  else if (result.size() >= 2 && result.front() == '\'' &&
           result.back() == '\'') {
    result = result.substr(1, result.size() - 2);
  }

  return result;
}

// Helper function to validate and clean UTF-8 strings
std::string WindowDetector::ValidateUtf8(const std::string &input) {
  if (g_utf8_validate(input.c_str(), -1, nullptr)) {
    return input;
  }

  gchar *valid_str = g_utf8_make_valid(input.c_str(), -1);
  std::string result(valid_str);
  g_free(valid_str);
  return result;
}
