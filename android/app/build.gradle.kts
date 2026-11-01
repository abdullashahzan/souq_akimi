plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.souqakimi.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Public GitHub release identity, registered with Firebase/Google OAuth.
        applicationId = "com.souqakimi.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val path = System.getenv("SOUQ_SIGNING_STORE_FILE")
            if (!path.isNullOrBlank()) {
                storeFile = file(path)
                storePassword = System.getenv("SOUQ_SIGNING_STORE_PASSWORD")
                keyAlias = System.getenv("SOUQ_SIGNING_KEY_ALIAS")
                keyPassword = System.getenv("SOUQ_SIGNING_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            // Never fall back to a debug key for distributable builds.
            signingConfig = signingConfigs.getByName("release")
            // Keep the plugin classes: Pigeon-generated methods are looked up
            // at runtime, and R8 would otherwise strip them from the release.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

val requireReleaseSigning by tasks.registering {
    doLast {
        listOf("STORE_FILE", "STORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD").forEach {
            check(!System.getenv("SOUQ_SIGNING_$it").isNullOrBlank()) {
                "Release signing is required. Use python3 scripts/build_release.py."
            }
        }
    }
}
tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
    dependsOn(requireReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
