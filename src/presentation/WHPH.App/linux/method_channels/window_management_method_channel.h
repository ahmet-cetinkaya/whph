#ifndef WINDOW_MANAGEMENT_METHOD_CHANNEL_H
#define WINDOW_MANAGEMENT_METHOD_CHANNEL_H

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

void window_management_method_call_cb(FlMethodChannel *channel,
                                      FlMethodCall *method_call,
                                      gpointer user_data);

#endif // WINDOW_MANAGEMENT_METHOD_CHANNEL_H
