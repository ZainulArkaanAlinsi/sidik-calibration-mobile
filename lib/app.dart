import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigasi_global.dart';
import 'core/pengamat_rute.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/kabar_masuk_provider.dart';
import 'providers/draf_lokal_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/pendaftaran_push_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'widgets/lapisan_kabar_masuk.dart';

/// Rentang skala huruf yang dihormati aplikasi (lihat `builder` di bawah).
const batasSkalaHuruf = (min: 1.0, max: 1.3);

class SidikApp extends ConsumerWidget {
  const SidikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Nilainya `void` dan sengaja nggak dipakai — yang dibutuhin efek sampingnya.
    //
    // `pendaftaranPushSyncProvider` yang mendaftarkan token perangkat ke server
    // sesudah login, dan mendaftarkan ulang tiap layanan push merotasinya.
    // Sampai 21 Agt 2026 **nggak ada satu pun berkas di `lib/` yang menyentuh
    // provider ini** — cuma `test/` yang manggil. Provider Riverpod nggak jalan
    // sampai ada yang baca, jadi seluruh isinya nggak pernah dieksekusi di
    // aplikasi asli: token perangkat nggak pernah didaftarkan sama sekali, dan
    // notifikasi push nggak pernah bisa sampai.
    //
    // Diamnya total, dan itu yang bikin dia bertahan lama: test-nya hijau
    // (test manggil providernya langsung), server nggak ngeluh (nggak ada yang
    // minta apa-apa), dan `AuthController.logout` tetap rajin MENCABUT token
    // yang sebenarnya nggak pernah terdaftar.
    //
    // Ditaruh di akar supaya umurnya seumur aplikasi. Kalau ditaruh di layar
    // yang bisa ditutup, langganan rotasinya ikut mati waktu layarnya dibuang —
    // dan rotasi token justru paling sering kejadian pas aplikasi lagi lama
    // nggak dibuka.
    ref.watch(pendaftaranPushSyncProvider);

    // Push saat aplikasi terbuka (`FirebaseMessaging.onMessage`) → toast.
    // Tanpa Firebase (belum ada google-services.json, desktop, mock) sumbernya
    // kosong dan provider ini tidak berbuat apa-apa.
    ref.watch(kabarPushSyncProvider);
    // Pengirim antrean draf offline — alasannya sama: umurnya harus seumur
    // aplikasi supaya draf yang tertahan di HP terkirim waktu aplikasi dibuka,
    // dilanjutkan dari latar, atau sesudah login, bukan cuma waktu layar
    // lembar kerja kebetulan terbuka.
    ref.watch(sinkronDrafLokalProvider);

    return MaterialApp(
      // Dipakai buat mbuka layar tujuan waktu notifikasi sistem diketuk —
      // di situ nggak ada `BuildContext` sama sekali.
      navigatorKey: navigatorKey,
      // Pop-up pembaruan dicoba lagi waktu shell kembali teratas.
      navigatorObservers: [pengamatRute],
      title: 'PT Sidik — Kalibrasi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Default ikut setelan HP; bisa di-override lewat toggle Dark Mode di
      // layar auth (teknisi yang kerja di gudang/lab sering nyalain gelap).
      themeMode: themeMode,
      // Dwibahasa ID/EN. `locale` dipaksa dari provider (default ID) supaya
      // konsisten dan nggak ketarik ke locale device.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Toast kabar masuk di atas semua layar (ikut Navigator, di bawah dialog).
      //
      // Skala huruf HP dijepit ke [batasSkalaHuruf]. HP murah sering dipasang
      // "huruf sangat besar" (1,5–2,0×) oleh pemiliknya; tata letak lembar
      // kerja (kolom angka, dialog titik ukur) di layar 320 dp lalu meluap
      // dan tombol simpan terdorong keluar layar. Sampai 1,3× tetap dihormati
      // — itu yang diuji `skala_huruf_layar_sempit_test.dart`.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: batasSkalaHuruf.min,
        maxScaleFactor: batasSkalaHuruf.max,
        child: LapisanKabarMasuk(child: child ?? const SizedBox.shrink()),
      ),
      home: const AuthGate(),
    );
  }
}
