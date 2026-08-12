import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload signing credentials, kept out of the repository.
//
// android/key.properties holds the passwords and the path to the keystore, and
// android/.gitignore excludes it along with *.jks and *.keystore. Nothing
// secret is in this file, which is the point of the split: this is reviewable
// and the credentials are not.
//
// Absent, the release build below falls back to the debug key so that a fresh
// clone still builds and `flutter run --release` works. That fallback must
// never reach Play, which is what the check in the release block is for.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.portalcrafter.pitchpole"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent. Google Play ties a listing to this string for the life of
        // the app and will not let it be changed afterwards, so it is also
        // what every Play Games Services credential is issued against.
        applicationId = "com.portalcrafter.pitchpole"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isEmpty) {
                // No credentials on this machine. Still builds, so a fresh
                // clone and `flutter run --release` both work, but what comes
                // out is signed with the shared Android debug key and is not
                // publishable.
                logger.warn(
                    "WARNING: android/key.properties is missing, so this " +
                        "release build is signed with the debug key. Play " +
                        "will reject it. See docs/play-store-checklist.md."
                )
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("upload")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
