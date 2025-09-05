#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "window_detector_win.h"
#include "windows_app_constants.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::SetStartMinimized(bool minimized) {
  start_minimized_ = minimized;
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  
  // Setup method channel for app usage
  SetupMethodChannel();
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (start_minimized_) {
    // For minimized startup, we create the window but don't show it
    // The window will be available in the taskbar but not visible
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      // Handle edge cases for minimized startup
      HWND hwnd = GetHandle();
      if (hwnd) {
        // Set window state without showing it first
        // This avoids any brief flicker on startup
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, 
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        
        // Use SW_MINIMIZE to minimize without activation
        // This ensures the window doesn't steal focus from other applications
        ShowWindow(hwnd, SW_MINIMIZE);
        
        // Ensure the window doesn't appear on any monitor
        // by keeping it truly minimized
        CloseWindow(hwnd);
      }
    });
  } else {
    flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
    });
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupMethodChannel() {
  auto messenger = flutter_controller_->engine()->messenger();
  
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, APP_USAGE_CHANNEL,
      &flutter::StandardMethodCodec::GetInstance());
      
  channel->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name().compare("getActiveWindow") == 0) {
      WindowInfo info = WindowsWindowDetector::GetActiveWindow();
      std::string response = info.title + "," + info.application;
      result->Success(flutter::EncodableValue(response));
    } else {
      result->NotImplemented();
    }
  });
}
