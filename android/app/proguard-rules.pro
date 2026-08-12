# R8 keep rules for the release build.
#
# Flutter shrinks and obfuscates release builds. Everything kept here is
# something that is looked up by name at runtime: R8 cannot see a reflective
# lookup, so it renames or removes the target, and the app dies with an error
# naming a class nobody in this project wrote.
#
# The crash this file was written for, on the first release build:
#
#   Unable to get provider androidx.startup.InitializationProvider:
#     java.lang.RuntimeException: Failed to create an instance of
#     androidx.work.impl.WorkDatabase
#
# Nothing in Pitchpole uses WorkManager or Room. The Google Mobile Ads SDK
# pulls WorkManager in, WorkManager keeps its queue in a Room database, and
# Room builds that database by appending "_Impl" to the class name and loading
# the result by reflection. Renaming WorkDatabase_Impl breaks the lookup, and
# because it all runs from an androidx.startup ContentProvider it fails during
# process start, before a line of Dart executes.
#
# Keeping the class NAME is the part that matters throughout this file. A
# members-only keep still lets R8 rename the class, which is exactly what
# breaks a lookup by name.

# ---------------------------------------------------------------------------
# Flutter engine and embedding
# ---------------------------------------------------------------------------
# The engine calls into these over JNI, and the plugin registrant is generated
# and referenced by name.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# androidx.startup, Room and WorkManager
# ---------------------------------------------------------------------------
# Not used directly. They arrive with the ads SDK, and they are the reason the
# first release build crashed on launch.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-dontwarn androidx.room.**

-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkManagerInitializer { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# ---------------------------------------------------------------------------
# google_mobile_ads, and the Play services it sits on
# ---------------------------------------------------------------------------
# The SDK is initialised from the manifest and instantiates mediation adapters
# by class name, so obfuscating them breaks ad loading rather than the build.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep public class com.google.android.gms.ads.MobileAds { public *; }
# Adapters are named in configuration and reflected on.
-keep class * extends com.google.android.gms.ads.mediation.Adapter { *; }
-keep class * implements com.google.android.gms.ads.mediation.MediationAdapter { *; }
-dontwarn com.google.android.gms.**

# The ads SDK asks whether Firebase is present and carries on without it. That
# question is a reflective lookup of a class this app does not depend on.
-dontwarn com.google.firebase.**

# ---------------------------------------------------------------------------
# games_services, and Play Games underneath it
# ---------------------------------------------------------------------------
# The Play Games SDK reads the project number out of the manifest at process
# start, through a provider, the same way the ads SDK does.
-keep class com.google.android.gms.games.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.abedalkareem.games_services.** { *; }

# ---------------------------------------------------------------------------
# audioplayers and flame_audio
# ---------------------------------------------------------------------------
# The sound pools and the background player both reach the platform through
# these, and audioplayers uses a foreground service on some paths.
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ExoPlayer / media3, which audioplayers can delegate to. Both name their
# renderers and extractors reflectively.
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# ---------------------------------------------------------------------------
# shared_preferences
# ---------------------------------------------------------------------------
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ---------------------------------------------------------------------------
# webview_flutter_wkwebview's Android sibling
# ---------------------------------------------------------------------------
# Pulled in by google_mobile_ads for ad rendering. JavaScript interfaces are
# bound by name from the web page side, so they cannot be renamed.
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ---------------------------------------------------------------------------
# Kotlin, and the annotations the libraries above are compiled against
# ---------------------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn org.jetbrains.annotations.**
-dontwarn javax.annotation.**

# ---------------------------------------------------------------------------
# Keep enough of a stack trace to be worth reading
# ---------------------------------------------------------------------------
# Without this a crash report from the store is a list of one letter class
# names. The mapping file in build/app/outputs/mapping/release/ is what turns
# an obfuscated trace back into a readable one, so upload it with the bundle.
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile
