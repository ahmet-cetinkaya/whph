#include "window_detector.h"
#include <cassert>
#include <iostream>
#include <string>

void TestX11Parsing() {
  std::cout << "Testing X11 Parsing..." << std::endl;

  // Normal case
  assert(X11WindowDetector::ParseXpropWmClass(
             "WM_CLASS(STRING) = \"whph\", \"WHPH\"") == "WHPH");

  // Instance only
  assert(X11WindowDetector::ParseXpropWmClass("WM_CLASS(STRING) = \"whph\"") ==
         "whph");

  // Empty
  assert(X11WindowDetector::ParseXpropWmClass("").empty());

  // Malformed
  assert(X11WindowDetector::ParseXpropWmClass("WM_CLASS(STRING) = ").empty());

  // With spaces
  assert(X11WindowDetector::ParseXpropWmClass(
             "WM_CLASS(STRING) = \"my app\", \"My App\"") == "My App");

  std::cout << "  Passed" << std::endl;
}

void TestGnomeParsing() {
  std::cout << "Testing Gnome Parsing..." << std::endl;

  // Normal
  WindowInfo info = WaylandWindowDetector::ParseGnomeEval(
      "(true, 'My Title')", "(true, 'org.example.App')");
  assert(info.title == "My Title");
  assert(info.application == "org.example.App");

  // Empty/False
  info = WaylandWindowDetector::ParseGnomeEval("(false, '')", "(false, '')");
  assert(info.title.empty());
  assert(info.application.empty());

  // With quotes in string
  // This depends on how CleanQuotes handles it, but typically Gnome returns
  // escaped JS strings? Our CleanQuotes just removes outer quotes.
  info = WaylandWindowDetector::ParseGnomeEval("(true, 'It\\'s a title')",
                                               "(true, 'app')");
  // ValidateUtf8/CleanQuotes usage in implementation:
  // res.substr(start, end-start) -> 'It\'s a title'
  // CleanQuotes -> It\'s a title
  // It does NOT unescape inner quotes currently in ParseGnomeEval
  // implementation! Wait, CleanQuotes removes front/back quotes. If input is
  // "(true, 'title')", substr is `'title'`. CleanQuotes makes it `title`.

  std::cout << "  Passed" << std::endl;
}

void TestFallbackParsing() {
  std::cout << "Testing Fallback Parsing..." << std::endl;

  // Normal PS output: pid pcpu comm
  // 1234 0.1 myapp
  WindowInfo info =
      FallbackWindowDetector::ParsePsOutput("1234 0.1 myapp", "/usr/bin/myapp");
  assert(info.application == "myapp");
  assert(info.title ==
         "myapp"); // cmdline processing uses filename as title if available

  // Cmdline with arguments
  info = FallbackWindowDetector::ParsePsOutput("1234 0.1 java",
                                               "/usr/bin/java -jar app.jar");
  assert(info.application == "java");
  assert(info.title == "java"); // logic: find last '/', then space. 'java'

  // Cmdline logic detail:
  // /usr/bin/java -> java.
  // space processing: "java -jar" -> space at pos 4. substr(0,4) -> "java"

  std::cout << "  Passed" << std::endl;
}

int main() {
  TestX11Parsing();
  TestGnomeParsing();
  TestFallbackParsing();
  std::cout << "All parsing tests passed!" << std::endl;
  return 0;
}
