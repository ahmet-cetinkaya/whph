#include "window_detector.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

// Mock implementation for abstract methods to instantiate WaylandWindowDetector
// We only need testing static helper methods, but cleaner to have a full class
// if needed. However, ParseKdeJournalOutput is static, so we don't strictly
// need an instance.

void TestKdeJournalParsing() {
  std::cout << "Running TestKdeJournalParsing..." << std::endl;
  std::string delim = "WHPH_KWIN_TEST";

  // Case 1: Valid output
  // Format: ... DELIM|Class|Title
  std::string input1 = "Feb 14 10:00:00 host kwin_wayland[123]: "
                       "WHPH_KWIN_TEST|org.mozilla.firefox|Mozilla Firefox";
  WindowInfo info1 =
      WaylandWindowDetector::ParseKdeJournalOutput(input1, delim);
  assert(info1.application == "org.mozilla.firefox");
  assert(info1.title == "Mozilla Firefox");
  std::cout << "  Passed: Valid output" << std::endl;

  // Case 2: Null application (desktop or nothing focused)
  std::string input2 =
      "Feb 14 10:00:00 host kwin_wayland[123]: WHPH_KWIN_TEST|null|null";
  WindowInfo info2 =
      WaylandWindowDetector::ParseKdeJournalOutput(input2, delim);
  assert(info2.application == "unknown");
  std::cout << "  Passed: Null application" << std::endl;

  // Case 3: Output without delimiter
  std::string input3 =
      "Feb 14 10:00:00 host kwin_wayland[123]: Some other log message";
  WindowInfo info3 =
      WaylandWindowDetector::ParseKdeJournalOutput(input3, delim);
  assert(info3.application == "unknown");
  std::cout << "  Passed: No delimiter" << std::endl;

  // Case 4: Truncated output (no pipe)
  std::string input4 =
      "Feb 14 10:00:00 host kwin_wayland[123]: WHPH_KWIN_TEST|truncated";
  WindowInfo info4 =
      WaylandWindowDetector::ParseKdeJournalOutput(input4, delim);
  assert(info4.application == "unknown"); // Should fail safely
  std::cout << "  Passed: Truncated output" << std::endl;

  // Case 5: Extra whitespace
  std::string input5 = "Feb 14 10:00:00 host kwin_wayland[123]: "
                       "WHPH_KWIN_TEST|  code  |  Visual Studio Code  ";
  WindowInfo info5 =
      WaylandWindowDetector::ParseKdeJournalOutput(input5, delim);
  assert(info5.application == "code");
  assert(info5.title == "Visual Studio Code");
  std::cout << "  Passed: Styles whitespace trimming" << std::endl;
}

int main() {
  TestKdeJournalParsing();
  std::cout << "All tests passed!" << std::endl;
  return 0;
}
