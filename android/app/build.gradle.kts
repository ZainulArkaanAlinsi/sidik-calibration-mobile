plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ptsidik.kalibrasi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Diminta `flutter_local_notifications`: dia memakai API waktu/tanggal
        // Java 8+ yang belum ada di Android lama, dan desugaring inilah yang
        // menyediakannya. Tanpa baris ini `assembleDebug` GAGAL total —
        // aplikasinya nggak bisa dibangun sama sekali, bukan sekadar
        // notifikasinya nggak jalan.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ptsidik.kalibrasi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pustaka desugaring buat `isCoreLibraryDesugaringEnabled` di atas.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
