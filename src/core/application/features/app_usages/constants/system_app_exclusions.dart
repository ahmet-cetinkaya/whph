class SystemAppExclusions {
  static const List<String> android = [
    // System UI and Shell
    'com.android.systemui',
    'com.android.launcher3',
    'com.google.android.googlequicksearchbox', // Google Search/Launcher overlay
    'com.android.launcher',
    'com.sec.android.app.launcher', // Samsung Launcher
    'com.miui.home', // MIUI Launcher
    'com.huawei.android.launcher', // Huawei Launcher
    'com.oppo.launcher', // Oppo Launcher
    'com.oneplus.launcher', // OnePlus Launcher

    // Core Android System
    'android',
    'com.android.settings',
    'com.android.providers.contacts',
    'com.android.providers.media',
    'com.android.providers.downloads',
    'com.android.providers.telephony',
    'com.android.phone',
    'com.android.dialer',
    'com.android.contacts',
    'com.android.mms',
    'com.android.inputmethod.latin',
    'com.android.documentsui',
    'com.android.permissioncontroller',
    'com.android.packageinstaller',
    'com.android.vending', // Google Play Store background
    'com.android.bluetooth',
    'com.android.nfc',
    'com.android.server.telecom',

    // Google Play Services and Core Apps
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.google.android.apps.maps', // When used as background service
    'com.google.android.webview',
    'com.google.android.tts',
    'com.google.android.inputmethod.latin',
    'com.google.android.syncadapters.contacts',
    'com.google.android.syncadapters.calendar',
    'com.google.android.partnersetup',

    // Accessibility and Input Services
    'com.android.server.accessibility',
    'com.google.android.accessibility.suite',
    'com.samsung.android.accessibility',

    // Background Services and Daemons
    'com.android.shell',
    'com.android.sharedstoragebackup',
    'com.android.printspooler',
    'com.android.managedprovisioning',
    'com.android.cellbroadcastreceiver',
    'com.android.emergency',
    'com.android.keychain',
    'com.android.carrierconfig',
    'com.android.proxyhandler',

    // OEM System Apps (Samsung)
    'com.samsung.android.dialer',
    'com.samsung.android.messaging',
    'com.samsung.android.contacts',
    'com.samsung.android.oneui.home',
    'com.sec.android.emergencymode.service',

    // OEM System Apps (Xiaomi/MIUI)
    'com.miui.securitycenter',
    'com.miui.systemAdSolution',
    'com.xiaomi.account',

    // OEM System Apps (Huawei)
    'com.huawei.systemmanager',
    'com.huawei.hwid',

    // Common Background Processes
    'system_server',
    'zygote',
    'kernel',
    'init',
  ];

  static const List<String> windows = [
    // Windows System Processes
    'explorer',
    'dwm', // Desktop Window Manager
    'winlogon',
    'csrss', // Client Server Runtime Process
    'smss', // Session Manager Subsystem
    'wininit',
    'services',
    'lsass', // Local Security Authority Subsystem Service
    'svchost',
    'spoolsv', // Print Spooler
    'conhost', // Console Window Host
    'fontdrvhost', // Font Driver Host
    'sihost', // Shell Infrastructure Host
    'runtimebroker', // Runtime Broker
    'taskhostw', // Task Host Window
    'backgroundtaskhost', // Background Task Host
    'searchui', // Windows Search
    'startmenuexperiencehost', // Start Menu
    'shellexperiencehost', // Shell Experience Host
    'searchapp', // Windows Search App
    'cortana', // Cortana
    'textinputhost', // Text Input Host
    'lockapp', // Windows Lock Screen
    'winlogon', // Windows Logon
    'userinit', // User Initialization
    'logonui', // Logon UI
    'lsaiso', // LSA Isolated Process

    // Windows Security and Updates
    'securityhealthsystray', // Windows Security
    'securityhealthservice', // Windows Security Service
    'msmpeng', // Windows Defender Antimalware Service
    'smartscreen', // Windows SmartScreen
    'wuauclt', // Windows Update
    'trustedinstaller', // Windows Modules Installer
    'tiworker', // Windows Modules Installer Worker

    // System Utilities
    'taskmgr', // Task Manager (when used for monitoring)
    'mmc', // Microsoft Management Console
    'regedit', // Registry Editor
    'cmd', // Command Prompt (when used for system tasks)
    'powershell', // PowerShell (when used for system tasks)
    'notepad', // Notepad (when used briefly)
    'calc', // Calculator (when used briefly)

    // Audio and Input Services
    'audiodg', // Windows Audio Device Graph Isolation
    'ctfmon', // CTF Loader (Touch Keyboard and Handwriting Panel)

    // Network and Communication
    'csrss', // Client Server Runtime Subsystem
    'lsm', // Local Session Manager
    'sppsvc', // Software Protection Platform Service

    // File System
    'msiexec', // Windows Installer
    'dllhost', // COM Surrogate
    'rundll32', // Run DLL as an App
    'regsvr32', // Register Server

    // Drivers and Hardware
    'system', // System Process
    'registry', // Registry Process
    'memory compression', // Memory Compression
    'system interrupts', // System Interrupts
    'idle', // System Idle Process
  ];

  static const List<String> linux = [
    // Core System Processes
    'systemd',
    'kernel',
    'kthread',
    'init',
    'ksoftirqd',
    'migration',
    'rcu_',
    'watchdog',
    'systemd-',

    // Desktop Environment (GNOME)
    'gnome-shell',
    'gnome-session',
    'gnome-settings-daemon',
    'nautilus', // When running in background
    'evolution-data-server',
    'gvfsd', // GNOME Virtual File System
    'gvfs-',
    'tracker-', // GNOME Search indexing
    'dconf-service',
    'at-spi-bus-launcher',
    'at-spi2-registryd',

    // Desktop Environment (KDE)
    'plasmashell',
    'kwin_x11',
    'kwin_wayland',
    'kded5',
    'kdeinit5',
    'klauncher',
    'kglobalaccel5',
    'kactivitymanagerd',
    'baloo_file', // KDE Search indexing
    'akonadi_', // KDE PIM backend

    // Desktop Environment (XFCE)
    'xfce4-session',
    'xfce4-panel',
    'xfwm4',
    'xfdesktop',
    'thunar', // When running in background

    // Window Managers and Display
    'xorg',
    'x11',
    'wayland',
    'weston',
    'mutter',
    'compton',
    'picom',
    'xcompmgr',
    'awesome',
    'i3',
    'dwm',
    'openbox',
    'fluxbox',

    // Audio System
    'pulseaudio',
    'pipewire',
    'wireplumber',
    'alsa',
    'jackd',

    // Network and Hardware Management
    'networkmanager',
    'nm-applet',
    'wpa_supplicant',
    'dhcpcd',
    'systemd-networkd',
    'systemd-resolved',
    'systemd-timesyncd',
    'bluetoothd',
    'upowerd', // Power management
    'udisksd', // Disk management
    'polkitd', // Policy kit

    // System Services
    'dbus',
    'dbus-daemon',
    'systemd-logind',
    'systemd-udevd',
    'systemd-journald',
    'rsyslog',
    'cron',
    'crond',
    'atd',
    'anacron',
    'systemd-user',

    // Package Management
    'packagekitd',
    'snap',
    'snapd',
    'flatpak',
    'appimaged',

    // Security and Monitoring
    'fail2ban',
    'aide',
    'rkhunter',
    'chkrootkit',
    'ossec',
    'samhain',

    // Background Utilities
    'gsd-', // GNOME Settings Daemon components
    'ibus-daemon', // Input method
    'fcitx', // Input method
    'xdg-desktop-portal',
    'xdg-permission-store',
    'fwupd', // Firmware updates
    'thermald', // Thermal management
    'irqbalance', // IRQ balancing
    'mcelog', // Machine check exceptions
    'smartd', // S.M.A.R.T. monitoring
    'accounts-daemon',
    'colord', // Color management
    'geoclue', // Location services
    'avahi-daemon', // Service discovery
    'cups', // Printing
    'cupsd', // CUPS daemon

    // Terminal Emulators (when idle/background)
    'gnome-terminal-server',
    'konsole', // When running in background
    'xterm', // When running system commands
    'urxvt', // When running system commands

    // File Managers (when in background)
    'dolphin', // KDE file manager background service
    'pcmanfm', // When running in background
    'thunar', // XFCE file manager background service

    // System Monitoring
    'top',
    'htop',
    'iotop',
    'iftop',
    'vmstat',
    'iostat',
    'sar',
    'pidstat',
    'nmon',
    'atop',

    // Kernel Threads (common patterns)
    'kworker',
    'ksoftirqd',
    'migration',
    'rcu_gp',
    'rcu_par_gp',
    'kcompactd',
    'ksmd',
    'khugepaged',
    'crypto',
    'kintegrityd',
    'kblockd',
    'ata_sff',
    'md',
    'edac-poller',
    'devfreq_wq',
    'kswapd',
    'fsnotify_mark',
  ];

  /// Returns the appropriate exclusion list for the current platform
  static List<String> getForCurrentPlatform() {
    // This will be determined by the platform-specific services
    // For now, return an empty list as a fallback
    return [];
  }

  /// Checks if an app name matches any exclusion pattern for the given platform
  static bool isSystemApp(String appName, List<String> exclusionList) {
    if (appName.isEmpty) return true;

    final lowerAppName = appName.toLowerCase().trim();

    return exclusionList.any((exclusion) {
      final lowerExclusion = exclusion.toLowerCase();

      // Exact match
      if (lowerAppName == lowerExclusion) return true;

      // Pattern matching for entries ending with underscore (like 'rcu_', 'gsd-')
      if (lowerExclusion.endsWith('_') || lowerExclusion.endsWith('-')) {
        return lowerAppName.startsWith(lowerExclusion.substring(0, lowerExclusion.length - 1));
      }

      // Check if the app name contains the exclusion as a substring for system components
      // This helps catch variations like 'systemd-networkd', 'gvfs-metadata', etc.
      if (lowerExclusion.contains('-') || lowerExclusion.contains('_')) {
        return lowerAppName.contains(lowerExclusion);
      }

      return false;
    });
  }
}
