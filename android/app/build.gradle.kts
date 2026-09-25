import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. android/key.properties is gitignored and not committed —
// see android/key.properties.example and docs/RELEASE_SIGNING_SETUP.md for
// how to generate the actual keystore. Falls back to debug signing with a
// loud warning when it's absent, so `flutter run --release` still works for
// local testing without it — but that fallback must never reach an actual
// Play Store upload, which is why it's a printed warning, not silent.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else {
    logger.warn(
        "⚠️  android/key.properties not found — release builds will be signed " +
            "with the DEBUG key. This is fine for local testing, but such a build " +
            "must never be uploaded to the Play Store. See " +
            "docs/RELEASE_SIGNING_SETUP.md to generate a real release keystore."
    )
}

android {
    namespace = "com.namasteneedham.duotask"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications requires this — without it, assembleDebug/
        // assembleRelease fail outright with "requires core library desugaring
        // to be enabled for :app" (CheckAarMetadataWorkAction).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.namasteneedham.duotask"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
