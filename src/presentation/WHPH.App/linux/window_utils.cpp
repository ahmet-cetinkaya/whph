#include "window_utils.h"
#include <array>
#include <cstdio>
#include <iostream>
#include <memory>
#include <vector>

// Helper function to escape shell arguments to prevent command injection
std::string ShellEscape(const std::string &input) {
  std::string escaped;
  escaped += "'";

  for (char c : input) {
    if (c == '\'') {
      // End current string, add escaped quote, start new string
      escaped += "'\\''";
    } else {
      escaped += c;
    }
  }

  escaped += "'";
  return escaped;
}

// Helper function to execute shell command and get output
std::string ExecuteCommand(const std::string &command) {
  std::string result;
  FILE *pipe = popen(command.c_str(), "r");
  if (!pipe) {
    // Only log popen failures for non-probe commands (not 'which' or 'pgrep')
    if (command.find("which ") != 0 && command.find("pgrep ") != 0) {
      std::cerr << "ExecuteCommand: popen failed for command: " << command
                << std::endl;
    }
    return result;
  }

  char buffer[128];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    result += buffer;
  }
  int status = pclose(pipe);

  // Only log unexpected failures (not probe commands like 'which' or 'pgrep')
  if (status != 0) {
    bool is_probe_command =
        (command.find("which ") == 0 || command.find("pgrep ") == 0 ||
         command.find("2>/dev/null") != std::string::npos ||
         command.find("2>&1") != std::string::npos);
    if (!is_probe_command) {
      std::cerr << "ExecuteCommand: command exited with status " << status
                << ": " << command << std::endl;
    }
  }

  // Remove trailing newline
  if (!result.empty() && result.back() == '\n') {
    result.pop_back();
  }

  return result;
}

// Helper function to unescape GVariant strings (e.g. from qdbus)
std::string UnescapeGVariantString(const std::string &input) {
  std::string result = input;

  // Check for GVariant string wrapper: ('string content',) or ('string
  // content')
  if (result.size() >= 5 && result.substr(0, 2) == "('" &&
      result.substr(result.size() - 3) == "',)") {
    result = result.substr(2, result.size() - 5);
  } else if (result.size() >= 4 && result.substr(0, 2) == "('" &&
             result.substr(result.size() - 2) == "')") {
    result = result.substr(2, result.size() - 4);
  }
  // Check for simpler GVariant string wrapper: 'string content'
  else if (result.size() >= 2 && result.front() == '\'' &&
           result.back() == '\'') {
    result = result.substr(1, result.size() - 2);
  }

  // Helper to replace all occurrences of a substring
  auto replaceAll = [](std::string &str, const std::string &from,
                       const std::string &to) {
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
      str.replace(start_pos, from.length(), to);
      start_pos += to.length();
    }
  };

  // Unescape common sequences
  replaceAll(result, "\\'", "'");
  replaceAll(result, "\\\"", "\"");
  replaceAll(result, "\\\\", "\\");
  replaceAll(result, "\\n", "\n");

  return result;
}
