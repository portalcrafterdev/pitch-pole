# R8 keep rules for the release build.
#
# Flutter shrinks and obfuscates release builds, and everything here is a class
# that something looks up by name at runtime. R8 cannot see a reflective lookup,
# so it renames or removes the target and the app dies on the first frame with
# an error that names a class nobody in this project wrote.
#
# The symptom this file was written for: a release build crashed on launch with
#
#   Unable to get provider androidx.startup.InitializationProvider:
#     java.lang.RuntimeException: Failed to create an instance of
#     androidx.work.impl.WorkDatabase
#
# Nothing in Pitchpole uses WorkManager or Room. The Google Mobile Ads SDK pulls
# WorkManager in, WorkManager stores its queue in a Room database, and Room
# builds that database by appending "_Impl" to the class name and loading the
# result by reflection. Renaming WorkDatabase_Impl therefore breaks the lookup,
# and because the whole thing runs from an androidx.startup ContentProvider it
# fails during process start, before any Dart code runs.
#
# Keeping the class name is the part that matters. A members-only keep still
# lets R8 rename the class, which is exactly what breaks a lookup by name.

# Room's generated database implementations, kept by name.
-keep class * extends androidx.room.RoomDatabase { *; }

# WorkManager's own internals, including the WorkDatabase_Impl above.
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.WorkManagerInitializer { *; }

# androidx.startup runs the initializers above from a ContentProvider, by name.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }
