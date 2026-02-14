#include "window_detector.h"
#include "window_utils.h"
#include <algorithm>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>

WindowInfo WaylandWindowDetector::GetActiveWindow() {
  WindowInfo info = TryGnomeWayland();
  if (info.title != "unknown" || info.application != "unknown") {
    return info;
  }

  info = TrySwayWayland();
  if (info.title != "unknown" || info.application != "unknown") {
    return info;
  }

  info = TryKdeWayland();
  if (info.title != "unknown" || info.application != "unknown") {
    return info;
  }

  info = TryWlrootsWayland();
  if (info.title != "unknown" || info.application != "unknown") {
    return info;
  }

  return {"unknown", "unknown"};
}

WindowInfo WaylandWindowDetector::TryGnomeWayland() {
  WindowInfo info{"unknown", "unknown"};

  // In Flatpak, pgrep won't work. Just try to call GNOME Shell via D-Bus.
  // If it fails, we assume GNOME Shell is not running or not accessible.
  std::cerr << "[DEBUG] TryGnomeWayland: Attempting to call org.gnome.Shell..."
            << std::endl;

  // Get window title
  std::string title_cmd =
      "gdbus call --session --dest org.gnome.Shell --object-path "
      "/org/gnome/Shell --method org.gnome.Shell.Eval "
      "\"global.display.focus_window?.get_title()\"";
  std::string title_result = ExecuteCommand(title_cmd);
  std::cerr << "[DEBUG] TryGnomeWayland: Title result: " << title_result
            << std::endl;

  // Get application ID
  std::string app_cmd =
      "gdbus call --session --dest org.gnome.Shell --object-path "
      "/org/gnome/Shell --method org.gnome.Shell.Eval "
      "\"global.display.focus_window?.get_gtk_application_id() || "
      "global.display.focus_window?.get_wm_class()\"";
  std::string app_result = ExecuteCommand(app_cmd);
  std::cerr << "[DEBUG] TryGnomeWayland: App result: " << app_result
            << std::endl;

  WindowInfo parsed = ParseGnomeEval(title_result, app_result);
  if (!parsed.title.empty())
    info.title = parsed.title;
  if (!parsed.application.empty())
    info.application = parsed.application;

  return info;
}

WindowInfo WaylandWindowDetector::TrySwayWayland() {
  WindowInfo info{"unknown", "unknown"};

  // In Flatpak, pgrep won't work.
  // Check if swaymsg is available.
  if (ExecuteCommand("which swaymsg 2>/dev/null").empty()) {
    std::cerr << "[DEBUG] TrySwayWayland: swaymsg not found." << std::endl;
    return info;
  }

  std::cerr << "[DEBUG] TrySwayWayland: Attempting to query swaymsg..."
            << std::endl;

  std::string cmd = "swaymsg -t get_tree 2>/dev/null | jq -r '.. | "
                    "select(.focused? == true)' 2>/dev/null";
  std::string result = ExecuteCommand(cmd);

  if (!result.empty()) {
    // Extract title
    std::string title_cmd = "echo '" + result + "' | jq -r '.name' 2>/dev/null";
    info.title = WindowDetector::ValidateUtf8(ExecuteCommand(title_cmd));

    // Extract app_id
    std::string app_cmd =
        "echo '" + result +
        "' | jq -r '.app_id // .window_properties.class' 2>/dev/null";
    info.application = WindowDetector::ValidateUtf8(ExecuteCommand(app_cmd));

    // Fallback to PID if app_id is null
    if (info.application == "null" || info.application.empty()) {
      std::string pid_cmd = "echo '" + result + "' | jq -r '.pid' 2>/dev/null";
      std::string pid = ExecuteCommand(pid_cmd);
      if (!pid.empty() && pid != "null") {
        std::string comm_cmd = "cat /proc/" + pid + "/comm 2>/dev/null";
        info.application =
            WindowDetector::ValidateUtf8(ExecuteCommand(comm_cmd));
      }
    }
  }

  return info;
}

WindowInfo WaylandWindowDetector::TryKdeWayland() {
  std::cerr << "[DEBUG] TryKdeWayland: Entry" << std::endl;
  // Priority 1: KWin Scripting (Most robust for native Wayland)
  WindowInfo info = TryKdeWaylandScript();
  if (info.application != "unknown") {
    std::cerr << "[DEBUG] TryKdeWayland: Script success: " << info.application
              << std::endl;
    return info;
  }

  // Priority 2: supportInformation Parsing (Fallback)
  return TryKdeWaylandDebugInfo();
}

WindowInfo WaylandWindowDetector::TryKdeWaylandScript() {
  WindowInfo info{"unknown", "unknown"};

  // Logic:
  // 1. Write a KWin script to /tmp.
  // 2. Load it via DBus (gdbus).
  // 3. Start it (executes the script logic).
  // 4. Script prints active window details to journal.
  // 5. Grep journal for output.
  // 6. Unload script.

  // Check if we are inside Flatpak by looking for flatpak-spawn
  bool has_flatpak_spawn = (system("which flatpak-spawn >/dev/null 2>&1") == 0);
  std::string prefix = has_flatpak_spawn ? "flatpak-spawn --host " : "";

  std::cerr << "[DEBUG] TryKdeWaylandScript: has_flatpak_spawn="
            << has_flatpak_spawn << std::endl;

  // Unique delimiter to avoid parsing issues
  std::string delim = "WHPH_KWIN_da39a3ee";

  // JS Script Content
  std::string script_content = "var c = workspace.activeWindow; "
                               "if (c) { "
                               "   print('" +
                               delim +
                               "|' + c.resourceClass + '|' + c.caption); "
                               "} else { "
                               "   print('" +
                               delim +
                               "|null|null'); "
                               "}";

  // Composite Shell Command
  std::string cmd =
      prefix +
      "sh -c \""
      // 1. Write Script
      "echo \\\"" +
      script_content +
      "\\\" > /tmp/whph_kwin.js; "
      // 2. Unload previous if stuck
      "gdbus call --session --dest org.kde.KWin --object-path /Scripting "
      "--method org.kde.kwin.Scripting.unloadScript 'whph_detector_v1' "
      ">/dev/null 2>&1; "
      // 3. Load Script
      "gdbus call --session --dest org.kde.KWin --object-path /Scripting "
      "--method org.kde.kwin.Scripting.loadScript '/tmp/whph_kwin.js' "
      "'whph_detector_v1' >/dev/null; "
      // 4. Start
      "gdbus call --session --dest org.kde.KWin --object-path /Scripting "
      "--method org.kde.kwin.Scripting.start >/dev/null; "
      // 5. Sleep
      "sleep 0.1; "
      // 6. Read Log
      "journalctl --user --no-pager -n 50 | grep '" +
      delim +
      "' | tail -1; "
      // 7. Cleanup
      "gdbus call --session --dest org.kde.KWin --object-path /Scripting "
      "--method org.kde.kwin.Scripting.unloadScript 'whph_detector_v1' "
      ">/dev/null; "
      "rm -f /tmp/whph_kwin.js"
      "\"";

  std::string output = ExecuteCommand(cmd);
  // Debug logs removed for production

  if (!output.empty()) {
    return ParseKdeJournalOutput(output, delim);
  }

  return info;
}

WindowInfo
WaylandWindowDetector::ParseKdeJournalOutput(const std::string &journal_out,
                                             const std::string &request_token) {
  WindowInfo info{"unknown", "unknown"};

  // Expected format: ... WHPH_KWIN_...|resourceClass|caption
  // journal_out contains the full line, but we only care about the part
  // starting with token

  if (journal_out.empty())
    return info;

  size_t token_pos = journal_out.find(request_token);
  if (token_pos == std::string::npos)
    return info;

  std::string clean =
      journal_out.substr(token_pos + request_token.length() + 1); // Skip TOKEN|

  size_t split = clean.find('|');
  if (split != std::string::npos) {
    std::string app = clean.substr(0, split);
    std::string title = clean.substr(split + 1);

    // Trim in case there are extra characters
    if (!app.empty()) {
      app.erase(0, app.find_first_not_of(" \n\r\t"));
      app.erase(app.find_last_not_of(" \n\r\t") + 1);
    }
    if (!title.empty()) {
      title.erase(0, title.find_first_not_of(" \n\r\t"));
      title.erase(title.find_last_not_of(" \n\r\t") + 1);
    }

    if (app != "null") {
      info.application = WindowDetector::ValidateUtf8(app);
      info.title = WindowDetector::ValidateUtf8(title);
    }
  }

  return info;
}

WindowInfo WaylandWindowDetector::TryKdeWaylandDebugInfo() {
  WindowInfo info{"unknown", "unknown"};

  // Method 1: Use supportInformation method (built-in KWin debug info)
  // We utilize host-side grep to avoid truncating the massive output in the
  // dbus/flatpak buffer.
  std::string output;

  bool has_flatpak_spawn = (system("which flatpak-spawn >/dev/null 2>&1") == 0);

  if (has_flatpak_spawn) {
    // Construct command: qdbus ... | grep ...
    // We look for "Active: true" and 25 lines before it to capture Class and
    // Caption. We wrap in sh -c to use pipes on host.
    std::string host_cmd = "flatpak-spawn --host sh -c \"qdbus org.kde.KWin "
                           "/KWin org.kde.KWin.supportInformation 2>/dev/null "
                           "| grep -i -B 25 'Active: true'\"";
    output = ExecuteCommand(host_cmd);

    if (output.empty()) {
      // Fallback to gdbus if qdbus is missing
      host_cmd = "flatpak-spawn --host sh -c \"gdbus call --session --dest "
                 "org.kde.KWin --object-path /KWin --method "
                 "org.kde.KWin.supportInformation 2>/dev/null | grep -i -B 25 "
                 "'Active: true'\"";
      output = ExecuteCommand(host_cmd);
    }
  } else {
    std::string cmd = "gdbus call --session --dest org.kde.KWin --object-path "
                      "/KWin --method org.kde.KWin.supportInformation";
    output = ExecuteCommand(cmd);
  }

  if (!output.empty()) {
    std::string unescaped = output;

    // If output looks like GVariant (starting with (' ), unescape it.
    if (output.rfind("('", 0) == 0) {
      unescaped = UnescapeGVariantString(output);
    }

    // Parse loop
    std::istringstream stream(unescaped);
    std::string line;
    std::string current_app = "";
    std::string current_title = "";

    while (std::getline(stream, line)) {
      if (line.find("Resource Class:") != std::string::npos) {
        size_t pos = line.find(":");
        if (pos != std::string::npos) {
          current_app = line.substr(pos + 1);
          current_app.erase(0, current_app.find_first_not_of(" \t"));
          current_app.erase(current_app.find_last_not_of(" \t") + 1);
        }
      }

      if (line.find("Caption:") != std::string::npos) {
        size_t pos = line.find(":");
        if (pos != std::string::npos) {
          current_title = line.substr(pos + 1);
          current_title.erase(0, current_title.find_first_not_of(" \t"));
          current_title.erase(current_title.find_last_not_of(" \t") + 1);
        }
      }

      // "Active: true" marker
      if (line.find("Active: true") != std::string::npos ||
          line.find("active: true") != std::string::npos) {

        info.application = current_app;
        info.title = current_title;
        return info;
      }
    }
  }

  // Method 2: Try using xprop even on Wayland (sometimes works with XWayland)
  std::string check_xprop = has_flatpak_spawn
                                ? "flatpak-spawn --host which xprop 2>/dev/null"
                                : "which xprop 2>/dev/null";
  if (!ExecuteCommand(check_xprop).empty()) {
    std::string xprop_cmd =
        has_flatpak_spawn
            ? "flatpak-spawn --host xprop -root _NET_ACTIVE_WINDOW 2>/dev/null "
              "| cut -d' ' -f5"
            : "xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | cut -d' ' -f5";

    std::string xprop_result = ExecuteCommand(xprop_cmd);

    if (!xprop_result.empty() && xprop_result != "0x0" &&
        xprop_result.find("0x") != std::string::npos) {
      std::string title_cmd, class_cmd;
      if (has_flatpak_spawn) {
        title_cmd = "flatpak-spawn --host xprop -id " +
                    ShellEscape(xprop_result) + " WM_NAME 2>/dev/null";
        class_cmd = "flatpak-spawn --host xprop -id " +
                    ShellEscape(xprop_result) + " WM_CLASS 2>/dev/null";
      } else {
        title_cmd =
            "xprop -id " + ShellEscape(xprop_result) + " WM_NAME 2>/dev/null";
        class_cmd =
            "xprop -id " + ShellEscape(xprop_result) + " WM_CLASS 2>/dev/null";
      }

      std::string raw_title = ExecuteCommand(title_cmd);
      std::string raw_class = ExecuteCommand(class_cmd);

      bool title_ok = !raw_title.empty() &&
                      raw_title.find("not found") == std::string::npos &&
                      raw_title.find("no such property") == std::string::npos;
      bool class_ok = !raw_class.empty() &&
                      raw_class.find("not found") == std::string::npos &&
                      raw_class.find("no such property") == std::string::npos &&
                      raw_class.find("\"") != std::string::npos;

      if (title_ok) {
        std::string title = "";
        size_t first_quote = raw_title.find('"');
        if (first_quote != std::string::npos) {
          size_t last_quote = raw_title.rfind('"');
          if (last_quote > first_quote) {
            title =
                raw_title.substr(first_quote + 1, last_quote - first_quote - 1);
          }
        }

        std::string app_class = "";
        if (class_ok) {
          size_t last_quote = raw_class.rfind('"');
          if (last_quote != std::string::npos) {
            size_t prev_quote = raw_class.rfind('"', last_quote - 1);
            if (prev_quote != std::string::npos) {
              app_class =
                  raw_class.substr(prev_quote + 1, last_quote - prev_quote - 1);
            }
          }
        }

        if (!title.empty()) {
          info.title = WindowDetector::ValidateUtf8(title);
          info.application = WindowDetector::ValidateUtf8(
              !app_class.empty() ? app_class : title);
          return info;
        }
      }
    }
  }

  // Method 3: Process-based detection via host heuristics
  // This is a last resort for native Wayland apps that don't expose info via
  // KWin.
  if (has_flatpak_spawn) {
    std::vector<std::string> gui_process_commands = {
        // Check for common GUI apps in list, sorted by start time (most recent
        // last)
        "flatpak-spawn --host sh -c \"ps -eo comm --sort=lstart 2>/dev/null | "
        "grep -E "
        "'(firefox|chrome|chromium|kate|dolphin|konsole|okular|kwrite|gwenview|"
        "ark|spectacle|code|atom|sublime|discord|slack|spotify|vlc|mpv|obs|"
        "studio|idea|webstorm|pycharm|goland|clion|rider|datagrip|brave|edge|"
        "opera|vivaldi|zen|zed)' 2>/dev/null | tail -1\"",
        // Check for highest CPU usage process that isn't a daemon
        "flatpak-spawn --host sh -c \"ps -eo comm --sort=-pcpu 2>/dev/null | "
        "grep -vE "
        "'(systemd|dbus|kwin|plasmashell|bash|ps|grep|kernel|flatpak|whph|Xorg|"
        "Xwayland)' 2>/dev/null | head -1 2>/dev/null\""};

    for (const auto &cmd : gui_process_commands) {
      std::string result = ExecuteCommand(cmd);

      if (!result.empty()) {
        std::string comm = result;
        if (comm.find('/') != std::string::npos) {
          size_t slash_pos = comm.find_last_of('/');
          comm = comm.substr(slash_pos + 1);
        }

        comm.erase(0, comm.find_first_not_of(" \t\n\r"));
        comm.erase(comm.find_last_not_of(" \t\n\r") + 1);

        if (!comm.empty()) {
          info.application = WindowDetector::ValidateUtf8(comm);
          info.title = WindowDetector::ValidateUtf8(comm);
          return info;
        }
      }
    }
  }

  return info;
}

WindowInfo WaylandWindowDetector::TryWlrootsWayland() {
  WindowInfo info{"unknown", "unknown"};

  // Try Hyprland
  if (!ExecuteCommand("which hyprctl 2>/dev/null").empty()) {
    std::string cmd = "hyprctl activewindow -j 2>/dev/null";
    std::string result = ExecuteCommand(cmd);

    if (!result.empty() && !ExecuteCommand("which jq 2>/dev/null").empty()) {
      std::string title_cmd =
          "echo '" + result + "' | jq -r '.title' 2>/dev/null";
      info.title = WindowDetector::ValidateUtf8(ExecuteCommand(title_cmd));

      std::string class_cmd =
          "echo '" + result + "' | jq -r '.class' 2>/dev/null";
      info.application =
          WindowDetector::ValidateUtf8(ExecuteCommand(class_cmd));

      if (info.title != "null" && info.application != "null") {
        return info;
      }
    }
  }

  // Try wayinfo for river and other wlroots compositors
  if (!ExecuteCommand("which wayinfo 2>/dev/null").empty()) {
    info.title = WindowDetector::ValidateUtf8(
        ExecuteCommand("wayinfo active-window-title 2>/dev/null"));
    info.application = WindowDetector::ValidateUtf8(
        ExecuteCommand("wayinfo active-window-app-id 2>/dev/null"));
  }

  return info;
}

// WaylandWindowDetector focus implementation
bool WaylandWindowDetector::FocusWindow(const std::string &windowTitle) {
  // Detect which compositor is running and use appropriate method

  // Try GNOME/Mutter first
  if (!ExecuteCommand("pgrep -f gnome-shell 2>/dev/null").empty()) {
    std::string gnome_cmd =
        "gdbus call --session --dest org.gnome.Shell --object-path "
        "/org/gnome/Shell --method org.gnome.Shell.Eval "
        "\"global.get_window_actors().find(w => "
        "w.get_meta_window().get_title().includes('" +
        windowTitle +
        "')).get_meta_window().activate(global.get_current_time())\" "
        "2>/dev/null";
    if (system(gnome_cmd.c_str()) == 0) {
      return true;
    }

    // Fallback for GNOME
    std::string gnome_fallback =
        "gdbus call --session --dest org.gnome.Shell --object-path "
        "/org/gnome/Shell --method org.gnome.Shell.Eval "
        "\"global.get_window_actors().find(w => "
        "w.get_meta_window().get_wm_class().toLowerCase().includes('whph'))."
        "get_meta_window().activate(global.get_current_time())\" 2>/dev/null";
    if (system(gnome_fallback.c_str()) == 0) {
      return true;
    }
  }

  // Try Sway
  if (!ExecuteCommand("pgrep -f sway 2>/dev/null").empty()) {
    std::vector<std::string> sway_commands = {
        "swaymsg '[title=\"" + windowTitle + "\"] focus' 2>/dev/null",
        "swaymsg '[app_id=\"whph\"] focus' 2>/dev/null",
        "swaymsg '[class=\"whph\"] focus' 2>/dev/null"};

    for (const auto &cmd : sway_commands) {
      if (system(cmd.c_str()) == 0) {
        return true;
      }
    }
  }

  // Try KDE/KWin with safer methods
  if (!ExecuteCommand("pgrep -f plasmashell 2>/dev/null").empty()) {
    // Method 1: Try using wmctrl first (sometimes works on KDE Wayland)
    std::vector<std::string> wmctrl_commands = {
        "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
        "wmctrl -x -a \"whph\" 2>/dev/null"};

    for (const auto &cmd : wmctrl_commands) {
      if (system(cmd.c_str()) == 0) {
        return true;
      }
    }

    // Method 2: Try KWin D-Bus methods if available
    if (!ExecuteCommand("which qdbus 2>/dev/null").empty()) {
      // Check if KWin scripting is available
      std::string kwin_check =
          ExecuteCommand("qdbus org.kde.KWin /Scripting 2>/dev/null");
      if (!kwin_check.empty()) {
        // Create a temporary script file for window focusing
        std::string temp_script = "/tmp/kwin_focus_window.js";
        std::string script_content =
            "var clients = workspace.clientList();\n"
            "for (var i = 0; i < clients.length; i++) {\n"
            "    var client = clients[i];\n"
            "    if (client.caption.indexOf('" +
            windowTitle +
            "') !== -1 || \n"
            "        client.resourceClass.indexOf('whph') !== -1) {\n"
            "        workspace.activeClient = client;\n"
            "        client.desktop = workspace.currentDesktop;\n"
            "        break;\n"
            "    }\n"
            "}\n";

        std::ofstream script_file(temp_script);
        if (script_file.is_open()) {
          script_file << script_content;
          script_file.close();

          // Load and run the script
          std::string load_cmd = "qdbus org.kde.KWin /Scripting "
                                 "org.kde.kwin.Scripting.loadScript " +
                                 temp_script + " 2>/dev/null";
          std::string script_id = ExecuteCommand(load_cmd);

          if (!script_id.empty()) {
            std::string run_cmd = "qdbus org.kde.KWin /" + script_id +
                                  " org.kde.kwin.Script.run 2>/dev/null";
            int result = system(run_cmd.c_str());

            // Clean up
            std::string stop_cmd = "qdbus org.kde.KWin /" + script_id +
                                   " org.kde.kwin.Script.stop 2>/dev/null";
            (void)system(stop_cmd.c_str());
            std::remove(temp_script.c_str());

            if (result == 0) {
              return true;
            }
          } else {
            std::remove(temp_script.c_str());
          }
        }
      }
    }
  }

  // Try Hyprland
  if (!ExecuteCommand("pgrep -f Hyprland 2>/dev/null").empty()) {
    std::vector<std::string> hypr_commands = {
        "hyprctl dispatch focuswindow title:\"" + windowTitle +
            "\" 2>/dev/null",
        "hyprctl dispatch focuswindow class:whph 2>/dev/null"};

    for (const auto &cmd : hypr_commands) {
      if (system(cmd.c_str()) == 0) {
        return true;
      }
    }
  }

  // Generic fallbacks that might work on some Wayland compositors
  std::vector<std::string> fallback_commands = {
      "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
      "wmctrl -x -a \"whph\" 2>/dev/null",
      "xdotool search --name \"" + windowTitle +
          "\" windowactivate 2>/dev/null"};

  for (const auto &command : fallback_commands) {
    if (system(command.c_str()) == 0) {
      return true;
    }
  }

  return false;
}

WindowInfo WaylandWindowDetector::ParseGnomeEval(const std::string &title_res,
                                                 const std::string &app_res) {
  WindowInfo info{"", ""};

  auto parse_val = [](const std::string &res) -> std::string {
    if (res.find("true") != std::string::npos) {
      size_t start = res.find("(true, ");
      if (start != std::string::npos) {
        start += 7;
        size_t end = res.find(")", start);
        if (end != std::string::npos) {
          return WindowDetector::ValidateUtf8(
              WindowDetector::CleanQuotes(res.substr(start, end - start)));
        }
      }
    }
    return "";
  };

  info.title = parse_val(title_res);
  info.application = parse_val(app_res);

  return info;
}

WindowInfo WaylandWindowDetector::ParseSwayTree(const std::string &tree_json) {
  return {"", ""};
}
