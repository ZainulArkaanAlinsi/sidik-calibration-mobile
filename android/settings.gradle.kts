pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Google Services — yang membaca `android/app/google-services.json` dan
    // menanamkan identitas proyek Firebase ke APK. Tanpa ini, `firebase_core`
    // terpasang tapi `Firebase.initializeApp()` gagal waktu aplikasi jalan.
    id("com.google.gms.google-services") version "4.4.3" apply false
    // Crashlytics — mengunggah berkas mapping R8 supaya jejak crash rilis
    // terbaca. v3 butuh Gradle 8 + AGP 8.1 + google-services 4.4.1 (terpenuhi).
    // Diterapkan bersyarat di app/build.gradle.kts, sama seperti google-services.
    id("com.google.firebase.crashlytics") version "3.0.8" apply false
}

include(":app")
