# General rules
-keep class com.google.android.gms.** { *; }

# Kotlin metadata compatibility fixes
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.* { *; }
-dontwarn kotlin.Metadata
-keep class kotlin.Unit { *; }
-keep class kotlin.jvm.internal.* { *; }

# Flutter plugins compatibility
-keep class io.flutter.plugins.** { *; }
-keep class me.ahmetcetinkaya.whph.** { *; }

# Suppress R8 warnings about Kotlin metadata
-assumenosideeffects class kotlin.Metadata {
    public static <methods>;
}
