#include "app_usage_method_channel.h"
#include "../window_detector.h"
#include <cstring>
#include <string>

void app_usage_method_call_cb(FlMethodChannel* channel,
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
