#include "window_detector.h"
#include <cstdlib>
#include <iostream>
#include <memory>
#include <sstream>
#include <vector>
#include <cstring>
#include <unistd.h>
#include <sys/wait.h>
#include <algorithm>
#include <fstream>

// X11 headers (will be conditionally compiled)
#ifdef HAVE_X11
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#endif

std::unique_ptr<WindowDetector> WindowDetector::Create() {
    // Detect display server type
    const char* wayland_display = getenv("WAYLAND_DISPLAY");
    const char* xdg_session_type = getenv("XDG_SESSION_TYPE");
    const char* display = getenv("DISPLAY");
    
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

// Helper function to execute shell command and get output
std::string ExecuteCommand(const std::string& command) {
    std::string result;
    FILE* pipe = popen(command.c_str(), "r");
    if (!pipe) return result;
    
    char buffer[128];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    pclose(pipe);
    
    // Remove trailing newline
    if (!result.empty() && result.back() == '\n') {
        result.pop_back();
    }
    
    return result;
}

// Helper function to clean quotes from strings
std::string CleanQuotes(const std::string& input) {
    std::string result = input;
    // Remove quotes
    result.erase(std::remove(result.begin(), result.end(), '"'), result.end());
    result.erase(std::remove(result.begin(), result.end(), '\''), result.end());
    return result;
}

#ifdef HAVE_X11
WindowInfo X11WindowDetector::GetActiveWindow() {
    WindowInfo info{"unknown", "unknown"};
    
    Display* display = XOpenDisplay(nullptr);
    if (!display) {
        return info;
    }
    
    Window root = DefaultRootWindow(display);
    Atom net_active_window = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char* prop = nullptr;
    
    // Get active window
    if (XGetWindowProperty(display, root, net_active_window, 0, 1, False,
                          XA_WINDOW, &actual_type, &actual_format, &nitems,
                          &bytes_after, &prop) == Success && prop) {
        Window active_window = *(Window*)prop;
        XFree(prop);
        
        // Get window title
        Atom wm_name = XInternAtom(display, "WM_NAME", False);
        if (XGetWindowProperty(display, active_window, wm_name, 0, 1024, False,
                              AnyPropertyType, &actual_type, &actual_format,
                              &nitems, &bytes_after, &prop) == Success && prop) {
            info.title = std::string(reinterpret_cast<char*>(prop));
            XFree(prop);
        }
        
        // Get process ID
        Atom net_wm_pid = XInternAtom(display, "_NET_WM_PID", False);
        if (XGetWindowProperty(display, active_window, net_wm_pid, 0, 1, False,
                              XA_CARDINAL, &actual_type, &actual_format,
                              &nitems, &bytes_after, &prop) == Success && prop) {
            pid_t pid = *(pid_t*)prop;
            XFree(prop);
            
            // Get process name from /proc/pid/comm
            std::string comm_path = "/proc/" + std::to_string(pid) + "/comm";
            std::ifstream comm_file(comm_path);
            if (comm_file.is_open()) {
                std::getline(comm_file, info.application);
                comm_file.close();
            }
        }
    }
    
    XCloseDisplay(display);
    return info;
}

bool X11WindowDetector::IsX11Available() {
    Display* display = XOpenDisplay(nullptr);
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
    
    std::string window_id = ExecuteCommand("xprop -root | grep '_NET_ACTIVE_WINDOW(WINDOW)' | awk '{print $5}'");
    if (window_id.empty() || window_id == "0x0") {
        return info;
    }
    
    std::string title_cmd = "xprop -id " + window_id + " | grep '^WM_NAME' | cut -d '\"' -f 2";
    info.title = ExecuteCommand(title_cmd);
    
    std::string pid_cmd = "xprop -id " + window_id + " | grep '^_NET_WM_PID' | awk -F '= ' '{print $2}'";
    std::string pid_str = ExecuteCommand(pid_cmd);
    
    if (!pid_str.empty()) {
        std::string comm_cmd = "cat /proc/" + pid_str + "/comm 2>/dev/null";
        info.application = ExecuteCommand(comm_cmd);
        if (info.application.empty()) {
            std::string ps_cmd = "ps -p " + pid_str + " -o comm= 2>/dev/null";
            info.application = ExecuteCommand(ps_cmd);
        }
    }
    
    return info;
}

bool X11WindowDetector::IsX11Available() {
    return !ExecuteCommand("which xprop").empty();
}
#endif

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
    
    // Check if gdbus is available and gnome-shell is running
    if (ExecuteCommand("which gdbus").empty() || 
        ExecuteCommand("pgrep -f gnome-shell").empty()) {
        return info;
    }
    
    // Get window title
    std::string title_cmd = "gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval \"global.display.focus_window?.get_title()\" 2>/dev/null";
    std::string title_result = ExecuteCommand(title_cmd);
    
    if (title_result.find("true") != std::string::npos) {
        size_t start = title_result.find("(true, ");
        if (start != std::string::npos) {
            start += 7; // Length of "(true, "
            size_t end = title_result.find(")", start);
            if (end != std::string::npos) {
                info.title = CleanQuotes(title_result.substr(start, end - start));
            }
        }
    }
    
    // Get application ID
    std::string app_cmd = "gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval \"global.display.focus_window?.get_gtk_application_id() || global.display.focus_window?.get_wm_class()\" 2>/dev/null";
    std::string app_result = ExecuteCommand(app_cmd);
    
    if (app_result.find("true") != std::string::npos) {
        size_t start = app_result.find("(true, ");
        if (start != std::string::npos) {
            start += 7;
            size_t end = app_result.find(")", start);
            if (end != std::string::npos) {
                info.application = CleanQuotes(app_result.substr(start, end - start));
            }
        }
    }
    
    return info;
}

WindowInfo WaylandWindowDetector::TrySwayWayland() {
    WindowInfo info{"unknown", "unknown"};
    
    // Check if swaymsg and jq are available, and sway is running
    if (ExecuteCommand("which swaymsg").empty() || 
        ExecuteCommand("which jq").empty() ||
        ExecuteCommand("pgrep -f sway").empty()) {
        return info;
    }
    
    std::string cmd = "swaymsg -t get_tree 2>/dev/null | jq -r '.. | select(.focused? == true)' 2>/dev/null";
    std::string result = ExecuteCommand(cmd);
    
    if (!result.empty()) {
        // Extract title
        std::string title_cmd = "echo '" + result + "' | jq -r '.name' 2>/dev/null";
        info.title = ExecuteCommand(title_cmd);
        
        // Extract app_id
        std::string app_cmd = "echo '" + result + "' | jq -r '.app_id // .window_properties.class' 2>/dev/null";
        info.application = ExecuteCommand(app_cmd);
        
        // Fallback to PID if app_id is null
        if (info.application == "null" || info.application.empty()) {
            std::string pid_cmd = "echo '" + result + "' | jq -r '.pid' 2>/dev/null";
            std::string pid = ExecuteCommand(pid_cmd);
            if (!pid.empty() && pid != "null") {
                std::string comm_cmd = "cat /proc/" + pid + "/comm 2>/dev/null";
                info.application = ExecuteCommand(comm_cmd);
            }
        }
    }
    
    return info;
}

WindowInfo WaylandWindowDetector::TryKdeWayland() {
    WindowInfo info{"unknown", "unknown"};
    
    // Check if KDE Plasma is running
    if (ExecuteCommand("pgrep -f plasmashell").empty()) {
        return info;
    }
    
    // Method 1: Try using qdbus to interact with KWin
    if (!ExecuteCommand("which qdbus").empty()) {
        // Check what KWin services are actually available
        std::string kwin_services = ExecuteCommand("qdbus 2>/dev/null | grep -E '(org\\.kde\\.KWin|org\\.kde\\.kwin)' 2>/dev/null");
        
        if (!kwin_services.empty()) {
            // Try different KWin D-Bus interfaces
            std::vector<std::string> kwin_attempts = {
                // Try KWin scripting with simpler approach
                "qdbus org.kde.KWin /Scripting 2>/dev/null",
                "qdbus org.kde.kwin /Scripting 2>/dev/null"
            };
            
            for (const auto& attempt : kwin_attempts) {
                std::string scripting_check = ExecuteCommand(attempt);
                if (!scripting_check.empty()) {
                    // KWin scripting is available, but the inline script approach might not work
                    // Let's try a different approach - check for window manager info
                    break;
                }
            }
        }
    }
    
    // Method 2: Try using xprop even on Wayland (sometimes works with XWayland)
    if (!ExecuteCommand("which xprop").empty()) {
        std::string xprop_result = ExecuteCommand("xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | cut -d' ' -f5");
        if (!xprop_result.empty() && xprop_result != "0x0") {
            std::string title_cmd = "xprop -id " + xprop_result + " WM_NAME 2>/dev/null | cut -d'\"' -f2";
            std::string class_cmd = "xprop -id " + xprop_result + " WM_CLASS 2>/dev/null | cut -d'\"' -f4";
            
            std::string title = ExecuteCommand(title_cmd);
            std::string app_class = ExecuteCommand(class_cmd);
            
            if (!title.empty() && title != "unknown") {
                info.title = title;
                info.application = !app_class.empty() ? app_class : title;
                return info;
            }
        }
    }
    
    // Method 3: Try using wmctrl (sometimes works on KDE Wayland)
    if (!ExecuteCommand("which wmctrl").empty()) {
        std::string wmctrl_result = ExecuteCommand("wmctrl -l 2>/dev/null | head -1");
        if (!wmctrl_result.empty()) {
            // Parse wmctrl output: window_id desktop_id hostname window_title
            std::istringstream iss(wmctrl_result);
            std::string window_id, desktop_id, hostname;
            if (iss >> window_id >> desktop_id >> hostname) {
                std::string title;
                std::getline(iss, title);
                if (!title.empty()) {
                    title = title.substr(1); // Remove leading space
                    info.title = title;
                    info.application = title; // Use title as application name
                    return info;
                }
            }
        }
    }
    
    // Method 4: Process-based detection with better heuristics
    std::vector<std::string> gui_process_commands = {
        // Look for recently active GUI processes
        "ps -eo pid,lstart,comm 2>/dev/null | grep -E '(firefox|chrome|chromium|kate|dolphin|konsole|okular|kwrite|gwenview|ark|spectacle|code|atom|sublime)' 2>/dev/null | tail -1",
        
        // Look for processes with high CPU usage (likely active)
        "ps -eo pid,pcpu,comm --sort=-pcpu 2>/dev/null | grep -vE '(systemd|dbus|kwin|plasmashell|bash|ps|grep|kernel)' 2>/dev/null | head -1 2>/dev/null",
        
        // Look for processes using X11/Wayland
        "ps -eo pid,comm 2>/dev/null | grep -E '(qt|gtk|electron|java)' 2>/dev/null | head -1 2>/dev/null"
    };
    
    for (const auto& cmd : gui_process_commands) {
        std::string result = ExecuteCommand(cmd);
        if (!result.empty()) {
            std::istringstream iss(result);
            std::string pid, extra, comm;
            if (iss >> pid >> extra >> comm) {
                // Clean up the process name
                if (comm.find('/') != std::string::npos) {
                    size_t slash_pos = comm.find_last_of('/');
                    comm = comm.substr(slash_pos + 1);
                }
                
                if (!comm.empty() && comm != "unknown") {
                    info.application = comm;
                    info.title = comm;
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
    if (!ExecuteCommand("which hyprctl").empty()) {
        std::string cmd = "hyprctl activewindow -j 2>/dev/null";
        std::string result = ExecuteCommand(cmd);
        
        if (!result.empty() && !ExecuteCommand("which jq").empty()) {
            std::string title_cmd = "echo '" + result + "' | jq -r '.title' 2>/dev/null";
            info.title = ExecuteCommand(title_cmd);
            
            std::string class_cmd = "echo '" + result + "' | jq -r '.class' 2>/dev/null";
            info.application = ExecuteCommand(class_cmd);
            
            if (info.title != "null" && info.application != "null") {
                return info;
            }
        }
    }
    
    // Try wayinfo for river and other wlroots compositors
    if (!ExecuteCommand("which wayinfo").empty()) {
        info.title = ExecuteCommand("wayinfo active-window-title 2>/dev/null");
        info.application = ExecuteCommand("wayinfo active-window-app-id 2>/dev/null");
    }
    
    return info;
}

WindowInfo FallbackWindowDetector::GetActiveWindow() {
    WindowInfo info{"unknown", "unknown"};
    
    // Get top processes by CPU usage, excluding common background processes
    std::string cmd = "ps -eo pid,pcpu,comm --sort=-pcpu | grep -v -E \"bash|ps|grep|systemd|init|dbus|journald|pulseaudio|NetworkManager\" | head -n 1";
    std::string result = ExecuteCommand(cmd);
    
    if (!result.empty()) {
        std::istringstream iss(result);
        std::string pid, pcpu, comm;
        if (iss >> pid >> pcpu >> comm) {
            info.application = comm;
            info.title = comm; // Use process name as title fallback
            
            // Try to get more descriptive name from cmdline
            std::string cmdline_cmd = "tr '\\0' ' ' < /proc/" + pid + "/cmdline 2>/dev/null";
            std::string cmdline = ExecuteCommand(cmdline_cmd);
            if (!cmdline.empty()) {
                // Extract filename if it contains a path
                size_t slash_pos = cmdline.find_last_of('/');
                if (slash_pos != std::string::npos) {
                    std::string filename = cmdline.substr(slash_pos + 1);
                    size_t space_pos = filename.find(' ');
                    if (space_pos != std::string::npos) {
                        filename = filename.substr(0, space_pos);
                    }
                    if (!filename.empty()) {
                        info.title = filename;
                    }
                }
            }
        }
    }
    
    return info;
}

// X11WindowDetector focus implementation
bool X11WindowDetector::FocusWindow(const std::string& windowTitle) {
#ifdef HAVE_X11
    if (!IsX11Available()) {
        return false;
    }
    
    Display* display = XOpenDisplay(nullptr);
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
    Window* windows = nullptr;
    
    // Get list of all windows
    int status = XGetWindowProperty(display, root, net_client_list, 0, 1024,
                                   False, XA_WINDOW, &actual_type, &actual_format,
                                   &nitems, &bytes_after, (unsigned char**)&windows);
    
    if (status != Success || !windows) {
        XCloseDisplay(display);
        return false;
    }
    
    bool found = false;
    
    for (unsigned long i = 0; i < nitems; i++) {
        Window window = windows[i];
        
        // Try _NET_WM_NAME first (UTF-8)
        unsigned char* name_prop = nullptr;
        status = XGetWindowProperty(display, window, net_wm_name, 0, 1024,
                                   False, utf8_string, &actual_type, &actual_format,
                                   &nitems, &bytes_after, &name_prop);
        
        std::string title;
        if (status == Success && name_prop) {
            title = std::string((char*)name_prop);
            XFree(name_prop);
        } else {
            // Fallback to WM_NAME
            char* window_name = nullptr;
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
    std::string command = "wmctrl -a \"" + windowTitle + "\" 2>/dev/null || wmctrl -x -a \"whph\" 2>/dev/null";
    int result = system(command.c_str());
    return result == 0;
#endif
}

// WaylandWindowDetector focus implementation
bool WaylandWindowDetector::FocusWindow(const std::string& windowTitle) {
    // Detect which compositor is running and use appropriate method
    
    // Try GNOME/Mutter first
    if (!ExecuteCommand("pgrep -f gnome-shell").empty()) {
        std::string gnome_cmd = "gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval \"global.get_window_actors().find(w => w.get_meta_window().get_title().includes('" + windowTitle + "')).get_meta_window().activate(global.get_current_time())\" 2>/dev/null";
        if (system(gnome_cmd.c_str()) == 0) {
            return true;
        }
        
        // Fallback for GNOME
        std::string gnome_fallback = "gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval \"global.get_window_actors().find(w => w.get_meta_window().get_wm_class().toLowerCase().includes('whph')).get_meta_window().activate(global.get_current_time())\" 2>/dev/null";
        if (system(gnome_fallback.c_str()) == 0) {
            return true;
        }
    }
    
    // Try Sway
    if (!ExecuteCommand("pgrep -f sway").empty()) {
        std::vector<std::string> sway_commands = {
            "swaymsg '[title=\"" + windowTitle + "\"] focus' 2>/dev/null",
            "swaymsg '[app_id=\"whph\"] focus' 2>/dev/null",
            "swaymsg '[class=\"whph\"] focus' 2>/dev/null"
        };
        
        for (const auto& cmd : sway_commands) {
            if (system(cmd.c_str()) == 0) {
                return true;
            }
        }
    }
    
    // Try KDE/KWin with safer methods
    if (!ExecuteCommand("pgrep -f plasmashell").empty()) {
        // Method 1: Try using wmctrl first (sometimes works on KDE Wayland)
        std::vector<std::string> wmctrl_commands = {
            "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
            "wmctrl -x -a \"whph\" 2>/dev/null"
        };
        
        for (const auto& cmd : wmctrl_commands) {
            if (system(cmd.c_str()) == 0) {
                return true;
            }
        }
        
        // Method 2: Try KWin D-Bus methods if available
        if (!ExecuteCommand("which qdbus").empty()) {
            // Check if KWin scripting is available
            std::string kwin_check = ExecuteCommand("qdbus org.kde.KWin /Scripting 2>/dev/null");
            if (!kwin_check.empty()) {
                // Create a temporary script file for window focusing
                std::string temp_script = "/tmp/kwin_focus_window.js";
                std::string script_content = 
                    "var clients = workspace.clientList();\n"
                    "for (var i = 0; i < clients.length; i++) {\n"
                    "    var client = clients[i];\n"
                    "    if (client.caption.indexOf('" + windowTitle + "') !== -1 || \n"
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
                    std::string load_cmd = "qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript " + temp_script + " 2>/dev/null";
                    std::string script_id = ExecuteCommand(load_cmd);
                    
                    if (!script_id.empty()) {
                        std::string run_cmd = "qdbus org.kde.KWin /" + script_id + " org.kde.kwin.Script.run 2>/dev/null";
                        int result = system(run_cmd.c_str());
                        
                        // Clean up
                        std::string stop_cmd = "qdbus org.kde.KWin /" + script_id + " org.kde.kwin.Script.stop 2>/dev/null";
                        system(stop_cmd.c_str());
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
    if (!ExecuteCommand("pgrep -f Hyprland").empty()) {
        std::vector<std::string> hypr_commands = {
            "hyprctl dispatch focuswindow title:\"" + windowTitle + "\" 2>/dev/null",
            "hyprctl dispatch focuswindow class:whph 2>/dev/null"
        };
        
        for (const auto& cmd : hypr_commands) {
            if (system(cmd.c_str()) == 0) {
                return true;
            }
        }
    }
    
    // Generic fallbacks that might work on some Wayland compositors
    std::vector<std::string> fallback_commands = {
        "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
        "wmctrl -x -a \"whph\" 2>/dev/null",
        "xdotool search --name \"" + windowTitle + "\" windowactivate 2>/dev/null"
    };
    
    for (const auto& command : fallback_commands) {
        if (system(command.c_str()) == 0) {
            return true;
        }
    }
    
    return false;
}

// FallbackWindowDetector focus implementation
bool FallbackWindowDetector::FocusWindow(const std::string& windowTitle) {
    // Try wmctrl as fallback
    std::vector<std::string> commands = {
        "wmctrl -a \"" + windowTitle + "\" 2>/dev/null",
        "wmctrl -x -a \"whph\" 2>/dev/null",
        "xdotool search --name \"" + windowTitle + "\" windowactivate 2>/dev/null"
    };
    
    for (const auto& command : commands) {
        int result = system(command.c_str());
        if (result == 0) {
            return true;
        }
    }
    
    return false;
}
