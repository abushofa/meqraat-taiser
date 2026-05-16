# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter engine but not used — suppress R8 warnings)
-dontwarn com.google.android.play.core.**

# Agora
-keep class io.agora.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Foreground Task
-keep class com.pravera.flutter_foreground_task.** { *; }

# Keep all annotations
-keepattributes *Annotation*
-keepattributes Signature
