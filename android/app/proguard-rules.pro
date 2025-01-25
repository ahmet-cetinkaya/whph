
# App Usage Plugin
-keep class dk.cachet.app_usage.** { *; }
-keepclassmembers class dk.cachet.app_usage.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep auto_start_flutter classes
-keep class co.techFlow.auto_start_flutter.** { *; }
-keepclassmembers class co.techFlow.auto_start_flutter.** { *; }

# General Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# App Usage Plugin
-keep class dk.cachet.app_usage.** { *; }
-keepclassmembers class dk.cachet.app_usage.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Keep auto_start_flutter classes
-keep class co.techFlow.auto_start_flutter.** { *; }
-keepclassmembers class co.techFlow.auto_start_flutter.** { *; }

# General Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**
