#ifndef WINDOW_DETECTOR_WIN_H_
#define WINDOW_DETECTOR_WIN_H_

#include <windows.h>
// include windows.h before psapi.h
#include <psapi.h>
#include <string>

struct WindowInfo {
  std::string title;
  std::string application;
};

class WindowsWindowDetector {
public:
  static WindowInfo GetActiveWindow();

private:
  static std::string GetProcessName(DWORD processId);
  static std::wstring StringToWString(const std::string &str);
  static std::string WStringToString(const std::wstring &wstr);
};

#endif // WINDOW_DETECTOR_WIN_H_
