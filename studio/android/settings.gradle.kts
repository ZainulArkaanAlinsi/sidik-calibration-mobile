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

// Versi AGP & Kotlin SENGAJA sama dengan app lapangan (`android/settings.gradle.kts`
// di akar repo), bukan versi template `flutter create` 3.44 (AGP 9 / Kotlin 2.3):
// plugin native yang dibangun di sini persis plugin yang sama (Firebase, ML Kit,
// notifikasi lokal, ...) dan kombinasi ini yang sudah terbukti membangunnya.
// Tanpa plugin Google Services: Studio tidak memakai Firebase.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
