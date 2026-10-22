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
    // Crashlytics ikut syarat yang sama: tanpa google-services.json dia tidak
    // punya app id, dan Firebase memang mati di build itu (laporan crash
    // dimatikan juga di sisi Dart — `PelaporGalat` cuma hidup kalau Firebase
    // hidup).
    apply(plugin = "com.google.firebase.crashlytics")
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

// Hemat ukuran APK (syarat pemilik, 20 Okt 2026):
//
// 1. ML Kit text recognition & barcode UNBUNDLED. Plugin Flutter menarik
//    artefak BUNDLED (`com.google.mlkit:text-recognition` 16.0.1 +
//    `text-recognition-bundled-common`; `com.google.mlkit:barcode-scanning`
//    17.3.0) yang membawa model + .so sendiri. Kelas API yang dipakai plugin
//    (`TextRecognition`, `latin.TextRecognizerOptions`, `BarcodeScanning`, ...)
//    ada di artefak `play-services-mlkit-*`, jadi plugin tidak perlu di-fork.
//    Modelnya diunduh Google Play Services (meta-data `DEPENDENCIES` di
//    manifest); sebelum terunduh, Dart menerima `ModulPembacaTeksBelumSiap`.
//    Inferensi tetap di HP (K-50-11).
// 2. LiteRT GPU delegate dibuang: `tflite_flutter` hanya membuka
//    `libtensorflowlite_gpu_jni.so` bila GpuDelegate dipakai, dan kita tidak.
configurations.all {
    exclude(group = "com.google.mlkit", module = "text-recognition")
    exclude(group = "com.google.mlkit", module = "text-recognition-bundled-common")
    exclude(group = "com.google.mlkit", module = "barcode-scanning")
    exclude(group = "com.google.ai.edge.litert", module = "litert-gpu")
}

dependencies {
    // Pustaka desugaring buat `isCoreLibraryDesugaringEnabled` di atas.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Pengganti unbundled (lihat catatan di atas `configurations.all`).
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    implementation("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")
}
