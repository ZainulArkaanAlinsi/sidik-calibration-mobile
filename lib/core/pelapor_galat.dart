import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tujuan laporan galat yang tidak tertangkap / galat non-fatal.
///
/// Dipisah jadi antarmuka supaya test tidak butuh Firebase: bawaannya
/// [PelaporGalatDiam] (cuma `debugPrint`), dan [PelaporGalatCrashlytics]
/// hanya dipasang `main.dart` di build rilis setelah Firebase hidup.
///
/// ## Yang BOLEH dan TIDAK BOLEH keluar dari HP
///
/// Yang dikirim cuma NAMA JENIS galat + jejak tumpukan (nama fungsi/berkas
/// kode kita sendiri). Pesan galat (`toString()`) TIDAK dikirim: pesan seperti
/// `FormatException: Invalid number "12,5"` atau galat HTTP bisa membawa
/// bacaan lembar kerja, nama pelanggan, path berkas, atau token. Lihat
/// [GalatTersaring].
abstract class PelaporGalat {
  const PelaporGalat();

  /// Catat galat. [konteks] = label tempat kejadian buatan kode (mis.
  /// `pindai:asli-baca`) — JANGAN isi dengan data pengguna.
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  });
}

/// Bawaan (debug, test, desktop, build tanpa Firebase): cuma ke log lokal.
class PelaporGalatDiam extends PelaporGalat {
  const PelaporGalatDiam();

  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) {
    // LOKAL saja (logcat/konsol pengembang), jadi pesan + tumpukan lengkap
    // boleh dicetak: `PlatformDispatcher.onError` mengembalikan `true`, dan
    // tanpa ini galat async di debug/profile/mock/desktop hilang tanpa jejak.
    // Jalur yang keluar dari HP ([PelaporGalatCrashlytics]) tetap tersaring.
    debugPrint('Galat[${konteks ?? '-'}]: ${galat.runtimeType}: $galat');
    if (tumpukan != null) debugPrint('$tumpukan');
  }
}

/// Pengganti galat asli saat dikirim ke Crashlytics: cuma jenisnya.
@immutable
class GalatTersaring implements Exception {
  const GalatTersaring(this.jenis);

  GalatTersaring.dari(Object galat) : jenis = galat.runtimeType.toString();

  final String jenis;

  @override
  String toString() => jenis;
}

class PelaporGalatCrashlytics extends PelaporGalat {
  PelaporGalatCrashlytics([FirebaseCrashlytics? crashlytics])
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  void catat(
    Object galat,
    StackTrace? tumpukan, {
    String? konteks,
    bool fatal = false,
  }) {
    // Tidak ditunggu, dan galat pelapornya sendiri ditelan: laporan crash
    // yang gagal terkirim tidak boleh menjadi crash kedua.
    _crashlytics
        .recordError(
          GalatTersaring.dari(galat),
          tumpukan,
          reason: konteks,
          fatal: fatal,
          printDetails: false,
        )
        .catchError((Object _) {});
  }
}

/// Pelapor yang aktif. Diganti sekali oleh `main.dart`; test memakai bawaan.
PelaporGalat pelaporGalat = const PelaporGalatDiam();

/// Pasang penangkap galat global + [ErrorWidget.builder] yang ramah.
///
/// - `FlutterError.onError` — galat framework (build/layout/paint). Tetap
///   diteruskan ke [FlutterError.presentError] supaya log debug tidak hilang.
/// - `PlatformDispatcher.instance.onError` — galat async yang lolos dari
///   semua `try`. Mengembalikan `true` = sudah ditangani, aplikasi jalan
///   terus (bukan ditutup).
/// - [ErrorWidget.builder] — widget yang gagal dibangun tampil sebagai kartu
///   kecil berbahasa Indonesia, bukan kotak abu-abu (rilis) / merah (debug).
///   Di debug kotak merah bawaan dipertahankan karena detailnya dibutuhkan
///   pengembang ([kartuRamah] `false`).
void pasangPenangkapGalat({
  PelaporGalat? pelapor,
  bool kartuRamah = !kDebugMode,
}) {
  if (pelapor != null) pelaporGalat = pelapor;

  final sebelumnya = FlutterError.onError;
  FlutterError.onError = (detail) {
    if (sebelumnya != null) {
      sebelumnya(detail);
    } else {
      FlutterError.presentError(detail);
    }
    pelaporGalat.catat(
      detail.exception,
      detail.stack,
      konteks: 'flutter:${detail.library ?? '-'}',
      fatal: false,
    );
  };

  PlatformDispatcher.instance.onError = (galat, tumpukan) {
    pelaporGalat.catat(galat, tumpukan, konteks: 'async', fatal: false);
    return true;
  };

  if (kartuRamah) {
    ErrorWidget.builder = (_) => const KartuGalatRamah();
  }
}

/// Pengganti kotak abu-abu waktu satu widget gagal dibangun.
///
/// Sengaja tidak bergantung pada Theme/Localizations/MediaQuery: dia bisa
/// dibangun di titik pohon mana pun, termasuk di atas `MaterialApp`, dan
/// yang paling buruk adalah kartu galat yang ikut galat.
class KartuGalatRamah extends StatelessWidget {
  const KartuGalatRamah({super.key});

  static const pesan =
      'Bagian ini gagal ditampilkan. Kembali lalu buka lagi; '
      'data yang sudah tersimpan tidak hilang.';

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFF4E5),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: Text(
              pesan,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5F3700),
                fontSize: 14,
                height: 1.3,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
