plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Services dipasang CUMA kalau berkasnya ada.
//
// `google-services.json` masuk `.gitignore` (repo ini publik), jadi checkout
// yang bersih NGGAK punya berkas itu. Waktu plugin ini dipasang tanpa syarat,
// akibatnya bukan "push-nya mati" — `assembleDebug` GAGAL TOTAL:
//
//     File google-services.json is missing.
//     The Google Services Plugin cannot function without it.
//
// Artinya siapa pun yang baru clone nggak bisa menjalankan aplikasinya sama
// sekali, cuma karena satu berkas kredensial yang memang sengaja nggak
// di-commit. Harga yang jauh lebih mahal daripada yang dibeli.
//
// Sisi runtime-nya sudah aman duluan: `_nyalakanFirebase()` di `main.dart`
// sengaja menelan kegagalan, dan `FcmSumberTokenPush` balikin token null
// kalau Firebase nggak hidup. Jadi tanpa berkas ini aplikasinya tetap jalan
// penuh — yang nggak ada cuma notifikasi push.
//
// Taruh `android/app/google-services.json` (unduh dari Firebase Console
// proyek `sidik-kalibrasi`) dan push langsung hidup, tanpa mengubah apa pun
// di sini.
val berkasGoogleServices = file("google-services.json")

if (berkasGoogleServices.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "[sidik] google-services.json nggak ada — build jalan terus, " +
            "notifikasi push aja yang mati. Lihat docs/deploy-firebase.md.",
    )
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

            // Tanpa baris ini `flutter build apk --release` GAGAL TOTAL di
            // `:app:minifyReleaseWithR8` — R8 nemu rujukan menggantung ke
            // pengenal teks Mandarin/Jepang/Korea/Devanagari milik ML Kit.
            // Alasan lengkapnya ada di proguard-rules.pro.
            //
            // Kelewat selama ini karena nggak ada yang pernah mbangun release
            // sampai ujung: "Build Android (debug)" di periksa-pr.yml pakai
            // `--debug` (R8 nggak jalan), dan "APK rilis (nyambung server)"
            // selalu mati lebih dulu di penjagaan API_BASE_URL yang belum
            // diisi. Jadi jalur release-nya nggak pernah kelewatan sama sekali.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
