#ifndef WINDOW_DETECTOR_H_
#define WINDOW_DETECTOR_H_

#include <string>
#include <memory>

struct WindowInfo {
    std::string title;
    std::string application;
};

class WindowDetector {
public:
    static std::unique_ptr<WindowDetector> Create();
    virtual ~WindowDetector() = default;
    virtual WindowInfo GetActiveWindow() = 0;
    virtual bool FocusWindow(const std::string& windowTitle) = 0;
};

// X11 implementation
class X11WindowDetector : public WindowDetector {
public:
    WindowInfo GetActiveWindow() override;
    bool FocusWindow(const std::string& windowTitle) override;
private:
    bool IsX11Available();
};

// Wayland implementations
class WaylandWindowDetector : public WindowDetector {
public:
    WindowInfo GetActiveWindow() override;
    bool FocusWindow(const std::string& windowTitle) override;
private:
    WindowInfo TryGnomeWayland();
    WindowInfo TrySwayWayland();
    WindowInfo TryKdeWayland();
    WindowInfo TryWlrootsWayland();
};

// Fallback implementation
class FallbackWindowDetector : public WindowDetector {
public:
    WindowInfo GetActiveWindow() override;
    bool FocusWindow(const std::string& windowTitle) override;
};

#endif  // WINDOW_DETECTOR_H_
