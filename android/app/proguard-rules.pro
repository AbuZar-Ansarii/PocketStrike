# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep all JNI native methods and classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep ALL write4me / llama native classes and methods
-keep class com.write4me.** { *; }
-keepclassmembers class com.write4me.** { *; }
-keep class com.write4me.llama_flutter_android.** { *; }
-keepclassmembers class com.write4me.llama_flutter_android.** { *; }
-keep class com.pocketstrike.** { *; }
-keepclassmembers class com.pocketstrike.** { *; }

# Keep Flutter Local Notifications & Desugaring
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn java.lang.invoke.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
