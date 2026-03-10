#include "window_detector.h"
#include "window_utils.h"
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <vector>

WindowInfo FallbackWindowDetector::GetActiveWindow() {
  WindowInfo info{"unknown", "unknown"};

  // Get top processes by CPU usage, excluding common background processes
  std::string cmd = "ps -eo pid,pcpu,comm --sort=-pcpu | grep -v -E "
                    "\"bash|ps|grep|systemd|init|dbus|journald|pulseaudio|"
                    "NetworkManager\" | head -n 1";
  std::string result = ExecuteCommand(cmd);

  /*
   We fetch information via ExecuteCommand usually, but for testing we want to
   exercise the parsing logic. The original logic:
   1. Get PS output: pid pcpu comm
   2. Get cmdline output (optional)
   */

  if (!result.empty()) {
    std::string pid;
    {
      std::istringstream iss(result);
      iss >> pid;
    }

    // We need 'cmdline' content (simulated here by reading the file if we are
    // live) But for static method we pass strings. Let's refactor the live code
    // to read strings then call Parser.

    std::string cmdline_content;
    if (!pid.empty()) {
      std::string cmdline_cmd =
          "tr '\\0' ' ' < /proc/" + pid + "/cmdline 2>/dev/null";
      cmdline_content = ExecuteCommand(cmdline_cmd);
    }

    WindowInfo parsed = ParsePsOutput(result, cmdline_content);
    if (parsed.application != "unknown")
      info.application = parsed.application;
    if (parsed.title != "unknown")
      info.title = parsed.title;
  }

  return info;
}

WindowInfo
FallbackWindowDetector::ParsePsOutput(const std::string &ps_output,
                                      const std::string &cmdline_output) {
  WindowInfo info{"unknown", "unknown"};

  if (ps_output.empty())
    return info;

  std::istringstream iss(ps_output);
  std::string pid, pcpu, comm;
  if (iss >> pid >> pcpu >> comm) {
    info.application = WindowDetector::ValidateUtf8(comm);
    info.title = WindowDetector::ValidateUtf8(
        comm); // Use process name as title fallback

    if (!cmdline_output.empty()) {
      std::string cmdline = cmdline_output;
      // Extract filename if it contains a path
      size_t slash_pos = cmdline.find_last_of('/');
      if (slash_pos != std::string::npos) {
        std::string filename = cmdline.substr(slash_pos + 1);
        size_t space_pos = filename.find(' ');
        if (space_pos != std::string::npos) {
          filename = filename.substr(0, space_pos);
        }
        if (!filename.empty()) {
          info.title = WindowDetector::ValidateUtf8(filename);
        }
      }
    }
  }
  return info;
}

// FallbackWindowDetector focus implementation
bool FallbackWindowDetector::FocusWindow(const std::string &windowTitle) {
  // Try wmctrl as fallback
  std::vector<std::string> commands = {
      "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
      "wmctrl -x -a \"whph\" 2>/dev/null",
      "xdotool search --name \"" + windowTitle +
          "\" windowactivate 2>/dev/null"};

  for (const auto &command : commands) {
    int result = system(command.c_str());
    if (result == 0) {
      return true;
    }
  }

  return false;
}
