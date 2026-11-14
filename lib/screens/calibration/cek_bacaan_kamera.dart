import 'package:flutter/widgets.dart';

/// Status satu sel isian terhadap gerbang "wajib dicek".
///
/// Tiga keadaan, dan hanya tiga:
///  - [tanpaTanda]: bukan hasil kamera, atau sel kosong (sel kosong tetap
///    kosong dan tidak ada yang perlu dicek).
///  - [perluCek]: angkanya datang dari kamera dan BELUM dilihat teknisi. Tulisan
///    tangan tidak pernah naik ke "sudah dicek" sendirian.
///  - [sudahDicek]: teknisi menekan konfirmasi pada sel INI, atau mengubah
///    nilainya.
enum StatusCekSel { tanpaTanda, perluCek, sudahDicek }

/// Jenis sel yang bisa ditandai. Dipakai untuk menyusun label dan sasaran
/// lompat; bukan untuk memutuskan boleh-tidaknya kirim.
enum JenisSelCek { tabel, matriks, grid, isian }

/// Baris mana di dalam set point grid (Enclosure) yang diperiksa. Judulnya
/// disusun di lapisan tampilan lewat l10n, bukan di state.
enum PeranSelGrid { termokopel, indikator, suhuRuang, nomorTermokopel }

/// Catatan tambahan untuk sel-sel hasil kamera satu jenis, berkunci sama
/// dengan penanda "dari kamera"-nya (mis. `LembarKerjaState.selRendahKeyakinan`).
///
/// Penanda (set kunci) menjawab "sel ini datang dari kamera?". Kelas ini
/// menjawab "sudah dilihat teknisi?" dengan dua catatan:
///
///  - [teksAwal]: isi sel saat mesin menaruhnya. Berubah dari isi ini = teknisi
///    sudah mengubah nilainya = dia sudah melihatnya.
///  - konfirmasi eksplisit: teknisi menekan "Sudah saya cek" pada sel itu.
///
/// Statusnya DIHITUNG dari isi sel sekarang, bukan disimpan: tidak ada
/// pendengar yang bisa terlewat, dan tidak ada jalur yang bisa menandai sel
/// "dicek" tanpa aksi teknisi. Kalau nilainya dikembalikan ke isi awal mesin,
/// sel kembali "perlu dicek" (konfirmasi eksplisit tetap berlaku).
class CatatanCek extends ChangeNotifier {
  final Map<String, String> _awal = {};
  final Set<String> _konfirmasi = {};

  /// Mesin menaruh [teksAwal] di sel [kunci]: sel jadi "perlu dicek" lagi,
  /// konfirmasi lama (untuk isi sebelumnya) tidak berlaku.
  void tandai(String kunci, String teksAwal) {
    _awal[kunci] = teksAwal;
    _konfirmasi.remove(kunci);
    notifyListeners();
  }

  /// Teknisi menekan konfirmasi pada sel [kunci].
  void konfirmasi(String kunci) {
    if (_konfirmasi.add(kunci)) notifyListeners();
  }

  /// Ganti nama kunci SEMUA catatan lewat [peta] (`null` = sel itu hilang,
  /// catatannya dibuang). Dipakai waktu baris tabel pindah kunci: isi sel ikut
  /// pindah, jadi catatannya (isi awal + konfirmasi) wajib pindah bersamanya —
  /// kalau tidak, sel yang bergeser tampak "sudah dicek" tanpa aksi.
  ///
  /// Semua kunci dipetakan sekaligus dari salinan: penggeseran berantai
  /// (1000 -> 1001, 1001 -> 1002) tidak saling menimpa.
  void petakanUlang(String? Function(String kunci) peta) {
    final awalBaru = <String, String>{};
    for (final e in _awal.entries) {
      final baru = peta(e.key);
      if (baru != null) awalBaru[baru] = e.value;
    }

    final konfirmasiBaru = <String>{for (final k in _konfirmasi) ?peta(k)};

    _awal
      ..clear()
      ..addAll(awalBaru);
    _konfirmasi
      ..clear()
      ..addAll(konfirmasiBaru);

    notifyListeners();
  }

  /// Buang catatan semua kunci yang [buang] -nya benar. Hanya memberi tahu
  /// pendengar bila ada yang terbuang.
  void buangJika(bool Function(String kunci) buang) {
    final sebelum = _awal.length + _konfirmasi.length;
    _awal.removeWhere((k, _) => buang(k));
    _konfirmasi.removeWhere(buang);

    if (_awal.length + _konfirmasi.length != sebelum) notifyListeners();
  }

  /// Lupakan catatan sel [kunci] (penandanya dilepas).
  void lepas(String kunci) {
    _awal.remove(kunci);
    _konfirmasi.remove(kunci);
    notifyListeners();
  }

  void kosongkan() {
    _awal.clear();
    _konfirmasi.clear();
    notifyListeners();
  }

  bool sudahDikonfirmasi(String kunci) => _konfirmasi.contains(kunci);

  /// Status sel [kunci]. [ditandai] = sel ini hasil kamera; [teks] = isi sel
  /// sekarang.
  StatusCekSel status(
    String kunci, {
    required bool ditandai,
    required String teks,
  }) {
    if (!ditandai) return StatusCekSel.tanpaTanda;
    if (teks.trim().isEmpty) return StatusCekSel.tanpaTanda;
    if (_konfirmasi.contains(kunci)) return StatusCekSel.sudahDicek;

    // Tanpa isi awal (salinan lama) tidak ada pembanding: tetap perlu dicek.
    final awal = _awal[kunci];
    if (awal != null && !samaNilaiCek(awal, teks)) {
      return StatusCekSel.sudahDicek;
    }

    return StatusCekSel.perluCek;
  }

  Map<String, dynamic> toJson() => {
    if (_awal.isNotEmpty) 'awal': Map.of(_awal),
    if (_konfirmasi.isNotEmpty) 'sudah': [..._konfirmasi],
  };

  void pulihkan(Object? json) {
    kosongkan();
    if (json is! Map) return;

    final awal = json['awal'];
    if (awal is Map) {
      for (final e in awal.entries) {
        _awal['${e.key}'] = '${e.value}';
      }
    }

    final sudah = json['sudah'];
    if (sudah is List) {
      for (final k in sudah) {
        _konfirmasi.add('$k');
      }
    }

    notifyListeners();
  }
}

/// Dua isi sel dianggap sama kalau angkanya sama (`7,02` = `7.020`); kalau
/// salah satunya bukan angka, bandingkan teksnya.
bool samaNilaiCek(String a, String b) {
  double? angka(String t) => double.tryParse(t.trim().replaceAll(',', '.'));

  final x = angka(a);
  final y = angka(b);
  if (x != null && y != null) return x == y;

  return a.trim() == b.trim();
}

/// Satu sel bacaan kamera, dilihat dari luar state: bahan untuk panel
/// gerbang, tautan lompat, dan payload.
class SelCek {
  const SelCek({
    required this.kunci,
    required this.jenis,
    required this.judul,
    required this.teks,
    required this.status,
    required this.sasaranLompat,
    this.nomor,
    this.bagianKode,
    this.peranGrid,
    this.setPoint,
    this.urutanBaris,
  });

  /// Kunci unik lintas jenis (`tabel|…`, `matriks|…`, `grid|…`, `isian|…`).
  final String kunci;
  final JenisSelCek jenis;

  /// Nama sel yang terbaca manusia (data lembar: label titik, baris, kolom).
  /// Untuk sel grid: nilai set point yang diketik teknisi (boleh kosong); kata-
  /// katanya disusun dari [peranGrid], [setPoint], dan [urutanBaris] lewat l10n.
  final String judul;

  /// Hanya sel grid: baris yang diperiksa, nomor set point (1-based), dan
  /// nomor urut termokopel (1-based; null untuk indikator/suhu ruang).
  final PeranSelGrid? peranGrid;
  final int? setPoint;
  final int? urutanBaris;

  /// Nomor pengulangan / titik waktu (1-based), kalau sel punya.
  final int? nomor;

  /// Isi sel sekarang, apa adanya.
  final String teks;
  final StatusCekSel status;

  /// Kode `TandaLompat` sel ini.
  final String sasaranLompat;

  /// `BagianLembarKerja.kode` pemilik sel — menentukan halaman yang harus
  /// dibuka sebelum selnya dicari.
  final String? bagianKode;
}

/// Jalur reaktif satu sel hasil kamera: dipasang di widget sel supaya tanda
/// berubah begitu teknisi mengubah isinya atau menekan konfirmasi, tanpa
/// membangun ulang seluruh lembar tiap ketukan.
///
/// Statusnya dihitung dari isi [controller] sekarang + [catatan], jadi tidak
/// ada keadaan kedua yang bisa basi.
class PemantauCek {
  const PemantauCek({
    required this.controller,
    required this.catatan,
    required this.kunci,
    required this.sasaranLompat,
  });

  final TextEditingController controller;
  final CatatanCek catatan;

  /// Kunci sel di [catatan].
  final String kunci;

  /// Kode `TandaLompat` sel ini.
  final String sasaranLompat;

  Listenable get dengarkan => Listenable.merge([controller, catatan]);

  StatusCekSel get status =>
      catatan.status(kunci, ditandai: true, teks: controller.text);
}

/// Kode `TandaLompat` untuk sel dengan kunci unik [kunciUnik] ([SelCek.kunci]).
String kodeLompatCek(String kunciUnik) => 'cek:$kunciUnik';
