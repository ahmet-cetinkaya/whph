#include "window_detector_win.h"
#include <iostream>
#include <vector>
#include <codecvt>
#include <locale>

WindowInfo WindowsWindowDetector::GetActiveWindow() {
    WindowInfo info{"unknown", "unknown"};
    
    // Get the handle of the foreground window
    HWND foregroundWindow = GetForegroundWindow();
    if (foregroundWindow == nullptr) {
        return info;
    }
    
    // Get window title
    wchar_t windowTitle[256];
    if (GetWindowTextW(foregroundWindow, windowTitle, sizeof(windowTitle) / sizeof(wchar_t)) > 0) {
        info.title = WStringToString(std::wstring(windowTitle));
    }
    
    // Get process ID
    DWORD processId = 0;
    GetWindowThreadProcessId(foregroundWindow, &processId);
    
    if (processId != 0) {
        info.application = GetProcessName(processId);
    }
    
    return info;
}

std::string WindowsWindowDetector::GetProcessName(DWORD processId) {
    std::string processName = "unknown";
    
    HANDLE processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
    if (processHandle != nullptr) {
        wchar_t processPath[MAX_PATH];
        if (GetModuleFileNameExW(processHandle, nullptr, processPath, MAX_PATH) > 0) {
            std::wstring fullPath(processPath);
            
            // Extract just the filename without extension
            size_t lastSlash = fullPath.find_last_of(L"\\");
            if (lastSlash != std::wstring::npos) {
                fullPath = fullPath.substr(lastSlash + 1);
            }
            
            size_t lastDot = fullPath.find_last_of(L".");
            if (lastDot != std::wstring::npos) {
                fullPath = fullPath.substr(0, lastDot);
            }
            
            processName = WStringToString(fullPath);
        }
        CloseHandle(processHandle);
    }
    
    return processName;
}

std::wstring WindowsWindowDetector::StringToWString(const std::string& str) {
    if (str.empty()) return std::wstring();
    
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), nullptr, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

std::string WindowsWindowDetector::WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, nullptr, nullptr);
    return strTo;
}
