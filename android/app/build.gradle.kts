plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ucp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store identity: com.ucpuniversity. (The old
        // "com.example.ucp" package is what blocked installs, and
        // com.example.* is invalid for Play anyway.) The namespace stays
        // com.example.ucp — it is only the code package for
        // MainActivity and does not need to match the application id.
        applicationId = "com.ucpuniversity"
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
        // Stable release key (30-year validity). Falls back to the debug
        // key only when the keystore is absent, so `flutter run --release`
        // keeps working everywhere while every release APK from this
        // machine is signed IDENTICALLY — installing one over another
        // never hits "App not installed".
        create("release") {
            val ks = File("/home/ubuntu/ucp-release.keystore")
            // NEVER silently fall back to the debug key. That fallback is what
            // once produced a release artifact signed with the wrong
            // certificate, which Play then rejected. A machine without the
            // keystore must fail loudly instead.
            require(ks.exists()) {
                "Release signing requires /home/ubuntu/ucp-release.keystore, " +
                    "which is missing. Without it a release build would " +
                    "silently sign with the DEBUG key and Play would reject " +
                    "the upload. Restore the keystore (a copy lives in " +
                    "/home/ubuntu/ucp-signing-backup/) or build a debug APK."
            }
            storeFile = ks
            storePassword = "ucp-campus-2026"
            keyAlias = "ucp-release"
            keyPassword = "ucp-campus-2026"
            storeType = "PKCS12"
            // minSdk is 24, so v1 (JAR signing) is not needed for any device
            // we support. v2 covers Android 7.0+; v3 adds proof-of-rotation,
            // so this upload key can later be rotated in place instead of
            // bricking sideloaded installs.
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = false
        }
    }

    buildTypes {
        release {
            // No debug-key fallback: a missing keystore is an error, not a
            // release build signed with the wrong certificate.
            signingConfig = signingConfigs.getByName("release")
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
