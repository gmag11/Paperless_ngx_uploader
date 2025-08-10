# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Permission Handler
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
-keep class androidx.core.os.** { *; }
-keep class androidx.activity.** { *; }
-keep class androidx.fragment.** { *; }

# Device Info Plus
-keep class android.os.** { *; }
-keep class android.content.** { *; }
-keep class android.provider.** { *; }