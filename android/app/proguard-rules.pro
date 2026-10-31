# Plugins call into their Pigeon-generated Java/Kotlin classes by name. Keep the
# plugin packages intact so a release build cannot strip a method the Dart side
# (or the platform channel) looks up at runtime.
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# R8 renamed kotlin.coroutines.Continuation, but the platform-channel bridge
# looks the suspend methods up with their original JVM descriptors. Without
# this, the release build fails on the first plugin call (SharedPreferences).
-dontobfuscate
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
