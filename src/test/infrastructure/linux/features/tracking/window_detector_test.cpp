#include "window_detector.h"
#include <iostream>
#include <cassert>
#include <vector>

void test_parse_kde_journal_output() {
    std::string request_token = "WHPH_REQ_12345";
    
    // Test Case 1: Normal valid output
    std::string out1 = "Jan 20 10:00:00 machine kwin_wayland[123]: WHPH_REQ_12345:org.kde.kate::WHPH_SEP::README.md - Kate";
    WindowInfo info1 = WaylandWindowDetector::ParseKdeJournalOutput(out1, request_token);
    assert(info1.application == "org.kde.kate");
    assert(info1.title == "README.md - Kate");
    
    // Test Case 2: No token match
    std::string out2 = "Jan 20 10:00:00 machine kwin_wayland[123]: SOME_OTHER_DATA";
    WindowInfo info2 = WaylandWindowDetector::ParseKdeJournalOutput(out2, request_token);
    assert(info2.application == "unknown");
    
    // Test Case 3: Null/Empty window
    std::string out3 = "Jan 20 10:00:00 machine kwin_wayland[123]: WHPH_REQ_12345:null::WHPH_SEP::null";
    WindowInfo info3 = WaylandWindowDetector::ParseKdeJournalOutput(out3, request_token);
    assert(info3.application == "unknown");

    // Test Case 4: Process IDs and different prefixes
    std::string out4 = "kwin_wayland[2848]: WHPH_REQ_12345:code::WHPH_SEP::workspace-207 - Code";
    WindowInfo info4 = WaylandWindowDetector::ParseKdeJournalOutput(out4, request_token);
    assert(info4.application == "code");
    assert(info4.title == "workspace-207 - Code");

    std::cout << "✅ test_parse_kde_journal_output passed" << std::endl;
}

void test_utils() {
    // Test CleanQuotes
    assert(WindowDetector::CleanQuotes("\"quoted\"") == "quoted");
    assert(WindowDetector::CleanQuotes("'single'") == "single");
    assert(WindowDetector::CleanQuotes("no quotes") == "no quotes");

    // Test ValidateUtf8
    assert(WindowDetector::ValidateUtf8("valid") == "valid");
    // Invalid UTF-8 (0xFF is not a valid start byte)
    std::string invalid = "valid\xFFinvalid";
    std::string validated = WindowDetector::ValidateUtf8(invalid);
    assert(validated != invalid);
    assert(validated.find("valid") != std::string::npos);

    std::cout << "✅ test_utils passed" << std::endl;
}

int main() {
    test_parse_kde_journal_output();
    test_utils();
    return 0;
}
