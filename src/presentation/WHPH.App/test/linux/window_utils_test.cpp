#include "window_utils.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

void TestShellEscape() {
  std::cout << "Running TestShellEscape..." << std::endl;

  // Test simple string
  assert(ShellEscape("hello") == "'hello'");

  // Test string with spaces
  assert(ShellEscape("hello world") == "'hello world'");

  // Test string with single quote
  // 'don't' -> 'don'\''t'
  std::string res = ShellEscape("don't");
  assert(res == "'don'\\''t'");

  // Test empty string
  assert(ShellEscape("") == "''");

  std::cout << "  Passed" << std::endl;
}

void TestUnescapeGVariant() {
  std::cout << "Running TestUnescapeGVariant..." << std::endl;

  // Test standard GVariant string
  assert(UnescapeGVariantString("('hello',)") == "hello");

  // Test simple quoted string
  assert(UnescapeGVariantString("'hello'") == "hello");

  // Test escaped characters
  // ('don\'t',) -> don't
  assert(UnescapeGVariantString("('don\\'t',)") == "don't");

  // Test no quotes (should return as is if not matching pattern, or maybe
  // handle gracefully) The current implementation expects quotes for stripping,
  // else returns as is
  assert(UnescapeGVariantString("hello") == "hello");

  std::cout << "  Passed" << std::endl;
}

int main() {
  TestShellEscape();
  TestUnescapeGVariant();

  std::cout << "All window_utils tests passed!" << std::endl;
  return 0;
}
