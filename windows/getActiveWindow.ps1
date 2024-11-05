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

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
}
"@

# Get the handle of the active window
$foregroundWindow = [WindowHelper]::GetForegroundWindow()

# Create a StringBuilder to hold the window title
$titleBuilder = New-Object System.Text.StringBuilder 256
[WindowHelper]::GetWindowText($foregroundWindow, $titleBuilder, $titleBuilder.Capacity) | Out-Null
$title = $titleBuilder.ToString()

# Get the process ID of the active window
$processId = 0
[WindowHelper]::GetWindowThreadProcessId($foregroundWindow, [ref] $processId)

# Get the process associated with the active window
$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
$processName = if ($process) { $process.Name } else { "" }

# Output the results
Write-Output "$title,$processName"
