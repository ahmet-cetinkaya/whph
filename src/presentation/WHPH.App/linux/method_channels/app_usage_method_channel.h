#ifndef APP_USAGE_METHOD_CHANNEL_H
#define APP_USAGE_METHOD_CHANNEL_H

#include <flutter_linux/flutter_linux.h>

void app_usage_method_call_cb(FlMethodChannel *channel,
                              FlMethodCall *method_call, gpointer user_data);

#endif // APP_USAGE_METHOD_CHANNEL_H
