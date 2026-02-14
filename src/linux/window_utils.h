#ifndef WINDOW_UTILS_H_
#define WINDOW_UTILS_H_

#include <string>

// Helper function to execute shell command and get output
std::string ExecuteCommand(const std::string &command);

// Helper function to escape shell arguments to prevent command injection
std::string ShellEscape(const std::string &input);

// Helper function to unescape GVariant strings (e.g. from qdbus)
std::string UnescapeGVariantString(const std::string &input);

#endif // WINDOW_UTILS_H_
