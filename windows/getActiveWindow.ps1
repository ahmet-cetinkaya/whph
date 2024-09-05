# Add a class to access Windows API functions
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowHelper
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
"@

# Get the handle of the active window
$hwnd = [WindowHelper]::GetForegroundWindow()

# Create a StringBuilder to hold the window title
$titleBuilder = New-Object System.Text.StringBuilder 256
[WindowHelper]::GetWindowText($hwnd, $titleBuilder, $titleBuilder.Capacity) | Out-Null
$title = $titleBuilder.ToString()

# Get the process associated with the active window
$process = Get-Process | Where-Object { $_.MainWindowHandle -eq $hwnd }
$processName = if ($process) { $process.Name } else { "Unknown" }

# Output the results
Write-Output "$title,$processName"
