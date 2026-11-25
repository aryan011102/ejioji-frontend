import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key a release is signed with. Google Play re-signs what it ships
// with its own app signing key; this one only proves an upload came from us.
//
// On Codemagic the keystore is uploaded to the team and the workflow's
// android_signing hands it over as CM_KEYSTORE_PATH and friends. On a laptop
// the same four values go in android/key.properties (gitignored, as is every
// .jks), with storeFile relative to android/app:
//
//   storeFile=../upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
//
// With neither, a release build falls back to the debug key, so
// `flutter run --release` still works; Play refuses anything debug-signed, so
// such a build can never reach the store by accident.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

fun signingValue(env: String, property: String): String? =
    System.getenv(env)?.takeIf { it.isNotEmpty() }
        ?: keystoreProperties.getProperty(property)?.takeIf { it.isNotEmpty() }

val uploadStoreFile = signingValue("CM_KEYSTORE_PATH", "storeFile")

android {
    namespace = "com.ejioji"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent once published (Aryan, 2026-09-19). The Kotlin namespace
        // above stays com.ejioji: it is only the code package, never shown.
        applicationId = "com.theonebytwo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        uploadStoreFile?.let { path ->
            create("release") {
                storeFile = file(path)
                storePassword = signingValue("CM_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("CM_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("CM_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val upload = signingConfigs.findByName("release")
            val buildingRelease = gradle.startParameter.taskNames
                .any { it.contains("Release", ignoreCase = true) }
            if (upload == null && buildingRelease) {
                logger.warn(
                    "No upload key (CM_KEYSTORE_PATH or android/key.properties): " +
                        "release is debug-signed and Google Play will refuse it."
                )
            }
            signingConfig = upload ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
