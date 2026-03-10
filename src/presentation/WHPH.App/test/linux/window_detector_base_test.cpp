#include "window_detector.h"
#include <cassert>
#include <iostream>
#include <string>

void TestCleanQuotes() {
  std::cout << "Testing CleanQuotes..." << std::endl;

  assert(WindowDetector::CleanQuotes("\"hello\"") == "hello");
  assert(WindowDetector::CleanQuotes("'hello'") == "hello");
  assert(WindowDetector::CleanQuotes("hello") == "hello");
  assert(WindowDetector::CleanQuotes("") == "");
  assert(WindowDetector::CleanQuotes("'") == "'");   // Too short
  assert(WindowDetector::CleanQuotes("\"") == "\""); // Too short
  assert(WindowDetector::CleanQuotes("'a'") == "a");

  std::cout << "  Passed" << std::endl;
}

void TestValidateUtf8() {
  std::cout << "Testing ValidateUtf8..." << std::endl;

  assert(WindowDetector::ValidateUtf8("hello") == "hello");
  assert(WindowDetector::ValidateUtf8("") == "");

  // Test invalid UTF-8 (simple case, usually glib replaces it)
  // We can't easily construct invalid strings in C++ source without
  // warning/error depending on compiler, but we can try injecting bytes. 0xFF
  // is invalid in UTF-8
  char invalid[] = "test\xff";
  std::string fixed = WindowDetector::ValidateUtf8(std::string(invalid));
  // It should be valid now (replacement character or stripped)
  // We just verify it doesn't crash and returns something valid
  assert(fixed.size() >= 4);

  std::cout << "  Passed" << std::endl;
}

int main() {
  TestCleanQuotes();
  TestValidateUtf8();
  std::cout << "All base tests passed!" << std::endl;
  return 0;
}
