import java.util.Properties

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

// Kunci penanda tangan rilis — dibaca dari `android/key.properties`.
//
// ## Kenapa ini nggak boleh tetap pakai kunci debug
//
// Sampai sebelum ini blok `release` di bawah masih memakai TODO bawaan Flutter
// (`signingConfig = signingConfigs.getByName("debug")`). Yang bikin itu
// berbahaya khusus di aplikasi ini: `AndroidManifest.xml` mendeklarasikan
// `REQUEST_INSTALL_PACKAGES` karena aplikasinya TIDAK diedarkan lewat Play
// Store — dia mengunduh penggantinya sendiri lalu memanggil pemasang Android
// (`lib/services/pengunduh_apk.dart` + `penyiap_update.dart`).
//
// Android hanya mengizinkan pemasangan di atas aplikasi yang sudah ada kalau
// SERTIFIKAT PENANDA TANGANNYA SAMA. Runner CI mulai dari VM bersih tiap run,
// dan Android Gradle Plugin membuat `debug.keystore` baru di situ: alias dan
// passwordnya memang selalu sama, tapi key material-nya acak tiap kali dibuat.
// Jadi tiap rilis bersertifikat beda dari rilis sebelumnya, dan tiap teknisi
// yang menekan "Update" ditolak dengan konflik signature. Yang kelihatan buat
// dia: aplikasinya rusak. Jalan keluarnya cuma uninstall manual — yang
// menghapus token di secure storage dan foto profil lokal.
//
// ## Kenapa absennya kunci TIDAK menggagalkan build di sini
//
// Karena berkas ini juga dipakai jalur yang memang nggak butuh kunci produksi:
//
//   - `flutter run --release` di laptop, yang justru dilindungi TODO aslinya;
//   - `build-tes-mock.yml`, yang membangun `flutter build apk --release
//     --dart-define=USE_MOCK=true` — paket uji coba berdata palsu.
//
// Paket mock itu malah TIDAK BOLEH ditandatangani kunci produksi: kalau iya,
// APK berdata palsu bisa menimpa aplikasi asli di HP teknisi tanpa perlawanan
// apa pun dari Android.
//
// Penjagaannya karena itu ditaruh di tempat yang tahu bedanya, yaitu workflow
// `apk-rilis-cloud.yml` — dia GAGAL di detik pertama kalau secret keystore-nya
// belum dipasang, dan memverifikasi sidik jari sertifikat APK-nya sesudah
// dibangun. Pola yang sama persis dengan penjagaan `API_BASE_URL` di sana.
val berkasKunciRilis = rootProject.file("key.properties")

val kunciRilis =
    Properties().apply {
        if (berkasKunciRilis.exists()) {
            berkasKunciRilis.inputStream().use { load(it) }
        }
    }

// Semua-atau-tidak-sama-sekali. `key.properties` yang terisi separuh bikin
// Gradle gagal jauh di dalam `:app:packageRelease` dengan pesan soal keystore
// yang nggak nyebut kunci mana yang bolong.
val adaKunciRilis =
    berkasKunciRilis.exists() &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
            !kunciRilis.getProperty(it).isNullOrBlank()
        }

if (!adaKunciRilis) {
    logger.lifecycle(
        "[sidik] android/key.properties nggak ada — build release jatuh ke kunci DEBUG. " +
            "Sah buat run lokal & paket mock; JANGAN dibagikan ke teknisi, " +
            "update-sendiri bakal ditolak Android. Lihat docs/rilis-tanda-tangan-apk.md.",
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

    signingConfigs {
        // Dibuat cuma kalau kuncinya memang ada. Signing config kosong bikin
        // Gradle gagal walau jalur yang dipakai nggak pernah menyentuhnya.
        if (adaKunciRilis) {
            create("rilis") {
                // Jalurnya diselesaikan relatif ke `android/`, tempat
                // `key.properties` sendiri duduk — bukan ke `android/app/`.
                // Jalur mutlak juga dilewatkan apa adanya oleh `file()`.
                storeFile = rootProject.file(kunciRilis.getProperty("storeFile"))
                storePassword = kunciRilis.getProperty("storePassword")
                keyAlias = kunciRilis.getProperty("keyAlias")
                keyPassword = kunciRilis.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Kunci produksi kalau ada; kalau nggak, jatuh ke debug supaya
            // `flutter run --release` dan paket mock tetap bisa dibangun.
            // Alasan lengkap kenapa absennya nggak digagalin DI SINI ada di
            // komentar `berkasKunciRilis` di atas — penjagaannya di
            // `apk-rilis-cloud.yml`, yang tahu bedanya rilis dan uji coba.
            signingConfig =
                if (adaKunciRilis) {
                    signingConfigs.getByName("rilis")
                } else {
                    signingConfigs.getByName("debug")
                }

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
