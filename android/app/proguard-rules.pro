# ProGuard rules for DocPilot - Production app support

# Play Core (suppress warnings for deferred components - not used in this app)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Firebase
-keepnames class com.firebase.** { *; }
-keepnames class com.google.firebase.** { *; }

# Keep Flutter classes
-keepnames class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Google Sign-In
-keep class com.google.android.gms.** { *; }
-keepnames class com.google.android.gms.auth.** { *; }

# Keep all custom application classes (if using platform channels)
-keep class com.sisir.docpilot.** { *; }

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep Kotlin metadata
-keepattributes *Annotation*
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimization
-optimizationpasses 5
-verbose

# Resource shrinking is handled by resourcesShrinkResources in build.gradle.kts
-keep public class android.app.Activity
-keep public class android.app.Service
-keep public class android.content.BroadcastReceiver
-keep public class android.content.ContentProvider
