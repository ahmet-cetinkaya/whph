#ifndef WINDOW_DETECTOR_H_
#define WINDOW_DETECTOR_H_

#include <memory>
#include <string>

struct WindowInfo {
  std::string title;
  std::string application;
};

class WindowDetector {
public:
  static std::unique_ptr<WindowDetector> Create();
  virtual ~WindowDetector() = default;
  virtual WindowInfo GetActiveWindow() = 0;
  virtual bool FocusWindow(const std::string &windowTitle) = 0;

  // Helper utilities (exposed for testing)
  static std::string CleanQuotes(const std::string &input);
  static std::string ValidateUtf8(const std::string &input);
};

// X11 implementation
class X11WindowDetector : public WindowDetector {
public:
  WindowInfo GetActiveWindow() override;
  bool FocusWindow(const std::string &windowTitle) override;

  // Exposed for testing
  static std::string ParseXpropWmClass(const std::string &input);

private:
  bool IsX11Available();
};

// Wayland implementations
class WaylandWindowDetector : public WindowDetector {
public:
  WindowInfo GetActiveWindow() override;
  bool FocusWindow(const std::string &windowTitle) override;

private:
  WindowInfo TryGnomeWayland();
  WindowInfo TrySwayWayland();
  WindowInfo TryKdeWayland();
  WindowInfo TryKdeWaylandScript();
  WindowInfo TryKdeWaylandDebugInfo();
  WindowInfo TryWlrootsWayland();

public:
  static WindowInfo ParseKdeJournalOutput(const std::string &journal_out,
                                          const std::string &request_token);
  static WindowInfo ParseGnomeEval(const std::string &title_res,
                                   const std::string &app_res);
  static WindowInfo ParseSwayTree(const std::string &tree_json);
};

// Fallback implementation
class FallbackWindowDetector : public WindowDetector {
public:
  WindowInfo GetActiveWindow() override;
  bool FocusWindow(const std::string &windowTitle) override;

  // Exposed for testing
  static WindowInfo ParsePsOutput(const std::string &ps_output,
                                  const std::string &cmdline_output);
};

#endif // WINDOW_DETECTOR_H_
