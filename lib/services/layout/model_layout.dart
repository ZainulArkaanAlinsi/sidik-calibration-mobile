import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'detektor_layout.dart';

/// Spesifikasi model layout yang DIKUNCI di kode.
///
/// Model TIDAK dibundel di APK: 129 MB menambah APK ±71 MB menjadi >190 MB
/// dan memaksa tiap pembaruan aplikasi lewat data seluler. Diunduh SEKALI
/// ke direktori aplikasi saat pertama dipakai, dari URL rilis resmi yang
/// dipin ke tag `v1.0.0`, lalu DIPERIKSA sha256-nya sebelum dipakai.
///
/// Mengganti model = mengganti SEMUA nilai di bawah dalam satu PR yang
/// menyebut sumber hash barunya. Hash yang tidak cocok bukan "unduhan
/// gagal": berkas dibuang dan model tidak pernah dimuat.
class SpesifikasiModelLayout {
  const SpesifikasiModelLayout({
    required this.namaBerkas,
    required this.url,
    required this.ukuranByte,
    required this.sha256Hex,
  });

  final String namaBerkas;
  final String url;
  final int ukuranByte;
  final String sha256Hex;

  /// `pp_doclayout_l.onnx`, rilis `v1.0.0` repo `robert008/flutter_ocr_kit`.
  /// sha256 dihitung dari unduhan lokal (10 Nov 2026) dan cocok dengan digest
  /// yang diumumkan GitHub untuk aset itu.
  static const ppDocLayoutL = SpesifikasiModelLayout(
    namaBerkas: 'pp_doclayout_l.onnx',
    url:
        'https://github.com/robert008/flutter_ocr_kit/releases/download/v1.0.0/pp_doclayout_l.onnx',
    ukuranByte: 129271998,
    sha256Hex:
        '1d1ed16b17e79ae08d1a18ea92a3ad134edfdb4455d869907e47b42699f4edb5',
  );
}

typedef IzinUnduh = Future<bool> Function();

/// Menyediakan berkas model di disk: periksa, unduh (lanjutkan bila
/// terputus), verifikasi sha256, pindahkan atomik.
class PengelolaModelLayout {
  PengelolaModelLayout({
    required Future<Directory> Function() direktori,
    http.Client? klien,
    this.spesifikasi = SpesifikasiModelLayout.ppDocLayoutL,
    this.maksCoba = 3,
    Duration Function(int percobaan)? jeda,
  }) : _direktori = direktori,
       _klien = klien ?? http.Client(),
       _jeda = jeda ?? ((n) => Duration(seconds: 2 << n));

  final SpesifikasiModelLayout spesifikasi;
  final int maksCoba;
  final Future<Directory> Function() _direktori;
  final http.Client _klien;
  final Duration Function(int) _jeda;

  /// Berkas yang sudah lolos sha256 di PROSES ini; tidak dihitung ulang tiap
  /// deteksi (129 MB).
  final Set<String> _terverifikasi = {};

  Future<File> _berkas() async =>
      File('${(await _direktori()).path}/${spesifikasi.namaBerkas}');

  /// Apakah berkas model sudah ada dan ukurannya benar (belum diperiksa hash).
  Future<bool> sudahAda() async {
    final f = await _berkas();

    return await f.exists() && await f.length() == spesifikasi.ukuranByte;
  }

  /// Path model yang SUDAH terverifikasi, mengunduhnya dulu bila perlu.
  ///
  /// [izinUnduh] ditanya sekali sebelum unduhan dimulai (mis. konfirmasi
  /// data seluler); `false` -> [SebabLayoutGagal.unduhDitolak].
  Future<String> pastikan({
    KemajuanLayout? kemajuan,
    IzinUnduh? izinUnduh,
  }) async {
    final akhir = await _berkas();

    if (await sudahAda()) {
      if (_terverifikasi.contains(akhir.path)) return akhir.path;

      kemajuan?.call(TahapLayout.memeriksaModel, null);
      if (await _shaCocok(akhir)) {
        _terverifikasi.add(akhir.path);

        return akhir.path;
      }
      // Berkas rusak/diubah: buang, unduh ulang.
      await _hapus(akhir);
    } else if (await akhir.exists()) {
      await _hapus(akhir);
    }

    if (izinUnduh != null && !await izinUnduh()) {
      throw const LayoutGagal(SebabLayoutGagal.unduhDitolak);
    }

    await akhir.parent.create(recursive: true);
    final sebagian = File('${akhir.path}.part');
    Object? galat;

    for (var coba = 0; coba < maksCoba; coba++) {
      if (coba > 0) await Future<void>.delayed(_jeda(coba));

      try {
        kemajuan?.call(TahapLayout.mengunduhModel, 0);
        await _unduh(sebagian, kemajuan);

        kemajuan?.call(TahapLayout.memeriksaModel, null);
        if (!await _shaCocok(sebagian)) {
          // Hash salah: bisa transfer rusak (coba ulang dari nol), bisa
          // berkas diganti. Dua-duanya TIDAK pernah dimuat.
          await _hapus(sebagian);
          galat = const LayoutGagal(SebabLayoutGagal.modelRusak);
          continue;
        }

        await sebagian.rename(akhir.path);
        _terverifikasi.add(akhir.path);

        return akhir.path;
      } on LayoutGagal catch (e) {
        galat = e;
        if (e.sebab == SebabLayoutGagal.modelRusak) await _hapus(sebagian);
      } catch (e) {
        galat = LayoutGagal(SebabLayoutGagal.unduhGagal, '$e');
      }
    }

    throw galat is LayoutGagal
        ? galat
        : LayoutGagal(SebabLayoutGagal.unduhGagal, '$galat');
  }

  /// Hapus berkas model (dan sisa unduhan) — untuk tombol "muat ulang".
  Future<void> buang() async {
    final f = await _berkas();
    _terverifikasi.remove(f.path);
    await _hapus(f);
    await _hapus(File('${f.path}.part'));
  }

  Future<void> _unduh(File sebagian, KemajuanLayout? kemajuan) async {
    var sudah = await sebagian.exists() ? await sebagian.length() : 0;
    if (sudah > spesifikasi.ukuranByte) {
      await _hapus(sebagian);
      sudah = 0;
    }

    final minta = http.Request('GET', Uri.parse(spesifikasi.url));
    if (sudah > 0) minta.headers['Range'] = 'bytes=$sudah-';

    final jawab = await _klien.send(minta).timeout(const Duration(seconds: 60));

    try {
      if (jawab.statusCode == 416) {
        // Sisa unduhan tak cocok dengan berkas di server: mulai dari nol.
        await _hapus(sebagian);
        throw const LayoutGagal(SebabLayoutGagal.unduhGagal, 'HTTP 416');
      }
      if (jawab.statusCode != 200 && jawab.statusCode != 206) {
        throw LayoutGagal(
          SebabLayoutGagal.unduhGagal,
          'HTTP ${jawab.statusCode}',
        );
      }

      // Server mengabaikan Range (200): tulis ulang dari awal.
      final lanjut = jawab.statusCode == 206 && sudah > 0;
      if (!lanjut) sudah = 0;

      final sink = sebagian.openWrite(
        mode: lanjut ? FileMode.append : FileMode.write,
      );
      try {
        var tertulis = sudah;
        await for (final potong in jawab.stream.timeout(
          const Duration(seconds: 60),
        )) {
          sink.add(potong);
          tertulis += potong.length;
          kemajuan?.call(
            TahapLayout.mengunduhModel,
            (tertulis / spesifikasi.ukuranByte).clamp(0.0, 1.0),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      // Isi aliran yang tidak dibaca (galat status) tidak boleh menggantung.
      if (jawab.statusCode != 200 && jawab.statusCode != 206) {
        unawaited(jawab.stream.drain<void>().catchError((_) {}));
      }
    }

    final panjang = await sebagian.length();
    if (panjang != spesifikasi.ukuranByte) {
      // Terpotong (lanjutkan lewat coba berikut) atau kelebihan (buang).
      if (panjang > spesifikasi.ukuranByte) await _hapus(sebagian);
      throw LayoutGagal(
        SebabLayoutGagal.unduhGagal,
        'ukuran $panjang != ${spesifikasi.ukuranByte}',
      );
    }
  }

  Future<bool> _shaCocok(File f) async {
    final jalur = f.path;
    final hex = await Isolate.run(() => hitungSha256Berkas(jalur));

    return hex == spesifikasi.sha256Hex.toLowerCase();
  }

  Future<void> _hapus(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Berkas terkunci: pemanggil berikutnya mencoba lagi.
    }
  }
}

/// sha256 berkas secara streaming (tidak memuat 129 MB ke memori). Top-level
/// supaya bisa dijalankan di isolate.
Future<String> hitungSha256Berkas(String jalur) async =>
    (await sha256.bind(File(jalur).openRead()).first).toString();
