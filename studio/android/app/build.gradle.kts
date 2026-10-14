import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Sidik Studio — aplikasi TERPISAH dari app lapangan (`com.ptsidik.kalibrasi`).
//
// applicationId sendiri = sandbox sendiri: token login, prefs, dan berkas tidak
// pernah bercampur dengan app lapangan di tablet yang sama, dan keduanya bisa
// terpasang berdampingan.
//
// TIDAK ada plugin Google Services dan TIDAK ada `google-services.json`:
// Studio tidak memakai push. Plugin firebase_* tetap ikut terdaftar (warisan
// paket `sidik_calibration` lewat path), tapi tidak pernah dinyalakan.

// Kunci penanda tangan rilis Studio — dibaca dari `studio/android/key.properties`
// (storeFile, storePassword, keyAlias, keyPassword). Pola SAMA dengan app
// lapangan (`android/app/build.gradle.kts`), kunci BERBEDA: Studio aplikasi
// lain (`com.ptsidik.studio`), dipakai asli di Windows & tablet lab, tidak
// dipublikasikan (keputusan pemilik 13 Okt 2026).
//
// Berkas itu & keystore-nya DI-GITIGNORE (`studio/android/.gitignore`) dan
// dibuat pemilik lewat skripnya sendiri — tidak pernah ditulis oleh repo ini.
//
// Kenapa wajib kunci tetap: Android hanya memasang versi baru DI ATAS versi
// lama bila sertifikatnya sama. Kunci debug berbeda tiap mesin/runner, jadi
// APK Studio bertanda tangan debug memaksa uninstall tiap pembaruan — dan
// uninstall membuang token & simpanan lokal tablet.
//
// Absennya kunci TIDAK menggagalkan build: `flutter run --release` lokal dan
// build uji tetap jalan dengan kunci debug + peringatan. Yang dibagikan ke
// lab wajib dibangun dengan `key.properties` terpasang.
val berkasKunciRilis = rootProject.file("key.properties")

val kunciRilis =
    Properties().apply {
        if (berkasKunciRilis.exists()) {
            berkasKunciRilis.inputStream().use { load(it) }
        }
    }

// Semua-atau-tidak-sama-sekali: berkas terisi separuh bikin Gradle gagal jauh
// di `:app:packageRelease` tanpa menyebut kunci mana yang bolong.
val adaKunciRilis =
    berkasKunciRilis.exists() &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
            !kunciRilis.getProperty(it).isNullOrBlank()
        }

if (!adaKunciRilis) {
    logger.lifecycle(
        "[sidik-studio] studio/android/key.properties tidak ada / tidak lengkap — " +
            "build release jatuh ke kunci DEBUG. Sah untuk run lokal; JANGAN " +
            "dipasang di tablet lab: pembaruan berikutnya akan ditolak Android.",
    )
}

android {
    namespace = "com.ptsidik.studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Diminta `flutter_local_notifications` (ikut terdaftar lewat paket
        // bersama). Tanpa desugaring `assembleDebug` gagal total — sama
        // dengan app lapangan.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ptsidik.studio"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Dibuat cuma kalau kuncinya lengkap — signing config kosong bikin
        // Gradle gagal walau jalur yang dipakai tidak pernah menyentuhnya.
        if (adaKunciRilis) {
            create("rilis") {
                // Relatif ke `studio/android/`, tempat `key.properties` duduk;
                // jalur mutlak dilewatkan apa adanya oleh `file()`.
                storeFile = rootProject.file(kunciRilis.getProperty("storeFile"))
                storePassword = kunciRilis.getProperty("storePassword")
                keyAlias = kunciRilis.getProperty("keyAlias")
                keyPassword = kunciRilis.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Kunci rilis Studio bila ada; kalau tidak, debug + peringatan
            // (lihat `berkasKunciRilis` di atas).
            signingConfig =
                if (adaKunciRilis) {
                    signingConfigs.getByName("rilis")
                } else {
                    signingConfigs.getByName("debug")
                }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
