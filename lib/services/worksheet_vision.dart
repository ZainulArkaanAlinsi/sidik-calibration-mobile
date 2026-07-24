/// Ekstraksi tabel worksheet lewat **AI Vision** (bukan OCR on-device lagi).
///
/// Alurnya: foto worksheet diunggah ke backend, backend manggil model vision
/// (Claude, lihat `SPEC-vision-ai-worksheet-extraction.md`) dan balikin angka
/// per sel **beserta tingkat keyakinannya**. Bedanya besar dari OCR ML Kit yang
/// dulu: AI paham layout tabel & tulisan tangan, jadi nggak perlu lagi nebak
/// posisi angka dari koordinat piksel — itu bagian yang dulu paling sering
/// meleset di lapangan.
///
/// **Tetap wajib dikonfirmasi manusia.** Hasil AI cuma **pra-isi** sel yang
/// masih bisa diedit teknisi; sel keyakinan rendah ditandai biar dicek ekstra.
/// Nggak ada data yang kesimpen tanpa teknisi menekan kirim.
library;

import 'dart:io';

import '../core/utils/parse_list.dart';
import 'api_client.dart';

/// Tingkat keyakinan AI buat satu sel. Sel [rendah] ditandai di layar supaya
/// teknisi ngecek angka itu, bukan seluruh tabel (spec §4.1).
enum TingkatKeyakinan {
  tinggi,
  sedang,
  rendah;

  /// String asing / hilang dianggap [rendah] — lebih aman nyuruh cek daripada
  /// diam-diam ngelolosin angka yang backend sendiri nggak yakin.
  static TingkatKeyakinan fromApi(String? v) => switch (v) {
    'high' || 'tinggi' => TingkatKeyakinan.tinggi,
    'medium' || 'sedang' => TingkatKeyakinan.sedang,
    _ => TingkatKeyakinan.rendah,
  };

  bool get perluDicek => this == TingkatKeyakinan.rendah;
}

/// Satu baris pengulangan di tabel worksheet (Repeat 1..5).
///
/// Panjang [ph] & [suhu] selalu sama dengan jumlah larutan standar (3). `null`
/// berarti sel nggak kebaca — **bukan** nol, dan bukan ditebak.
class BarisTabel {
  const BarisTabel({
    required this.ph,
    required this.suhu,
    this.phKeyakinan = const [],
    this.suhuKeyakinan = const [],
  });

  final List<double?> ph;
  final List<double?> suhu;

  /// Keyakinan per sel, sejajar [ph]/[suhu]. Kosong = anggap [TingkatKeyakinan
  /// .tinggi] (mis. data mock lama / test yang nggak peduli confidence).
  final List<TingkatKeyakinan> phKeyakinan;
  final List<TingkatKeyakinan> suhuKeyakinan;

  TingkatKeyakinan keyakinanPh(int i) =>
      i < phKeyakinan.length ? phKeyakinan[i] : TingkatKeyakinan.tinggi;
  TingkatKeyakinan keyakinanSuhu(int i) =>
      i < suhuKeyakinan.length ? suhuKeyakinan[i] : TingkatKeyakinan.tinggi;

  bool get lengkap => !ph.contains(null) && !suhu.contains(null);
}

/// Hasil ekstraksi AI satu tabel (Before ATAU After adjustment).
class HasilEkstraksiTabel {
  const HasilEkstraksiTabel({
    required this.baris,
    required this.jumlahSelKebaca,
    required this.jumlahSelDiharapkan,
    this.jumlahAngkaTerdeteksi = 0,
  });

  final List<BarisTabel> baris;
  final int jumlahSelKebaca;
  final int jumlahSelDiharapkan;

  /// Berapa angka yang AI lihat di foto, sebelum dipetakan ke sel. Bedanya
  /// sama [jumlahSelKebaca] bikin pesan gagal berguna: terdeteksi 0 = fotonya
  /// bermasalah; terdeteksi banyak tapi sel 0 = fotonya bukan tabel worksheet.
  final int jumlahAngkaTerdeteksi;

  double get kelengkapan =>
      jumlahSelDiharapkan == 0 ? 0 : jumlahSelKebaca / jumlahSelDiharapkan;

  /// Parse respons `POST /raw-measurements/extract-from-photo`.
  ///
  /// Bentuk yang diharapkan (tiap larutan standar satu entri di `ph`/`suhu`,
  /// `null` kalau tak terbaca):
  /// ```json
  /// { "baris": [
  ///   { "ph": [4.01, 7.02, 10.11], "suhu": [22.2, 22.3, 22.1],
  ///     "ph_keyakinan": ["high","medium","low"],
  ///     "suhu_keyakinan": ["high","high","high"] }
  /// ] }
  /// ```
  factory HasilEkstraksiTabel.fromJson(
    Map<String, dynamic> json, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
  }) {
    List<double?> angka(dynamic list) {
      if (list is! List) return const [];
      return list.map((e) => e is num ? e.toDouble() : null).toList();
    }

    List<TingkatKeyakinan> keyakinan(dynamic list) {
      if (list is! List) return const [];
      return list
          .map((e) => TingkatKeyakinan.fromApi(e is String ? e : null))
          .toList();
    }

    final baris = parseListAman<BarisTabel>(json['baris'], (b) {
      return BarisTabel(
        ph: angka(b['ph']),
        suhu: angka(b['suhu']),
        phKeyakinan: keyakinan(b['ph_keyakinan']),
        suhuKeyakinan: keyakinan(b['suhu_keyakinan']),
      );
    });

    var kebaca = 0;
    var terdeteksi = 0;
    for (final b in baris) {
      kebaca += b.ph.whereType<double>().length +
          b.suhu.whereType<double>().length;
      terdeteksi += b.ph.length + b.suhu.length;
    }

    return HasilEkstraksiTabel(
      baris: baris,
      jumlahSelKebaca: kebaca,
      jumlahSelDiharapkan: jumlahBaris * jumlahTitik * 2,
      jumlahAngkaTerdeteksi: terdeteksi,
    );
  }
}

/// Baca satu tabel worksheet dari foto lewat AI Vision di backend.
abstract class WorksheetVisionService {
  /// [sesiId] diisi kalau lagi lanjut draft; sesi baru belum punya id (ekstraksi
  /// jalan sebelum sesi kebentuk), jadi boleh null.
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik,
    int jumlahBaris,
    int? sesiId,
  });

  void dispose();
}

class ApiWorksheetVisionService implements WorksheetVisionService {
  ApiWorksheetVisionService(this._api, this._token);

  final ApiClient _api;

  /// Token diambil lewat closure, bukan diparam, biar tanda tangan [ekstrak]
  /// sama persis dengan jalur lama — layar & test nggak perlu ikut berubah.
  final Future<String?> Function() _token;

  @override
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
    int? sesiId,
  }) async {
    final json = await _api.unggahFile(
      '/raw-measurements/extract-from-photo',
      field: 'foto',
      filePath: foto.path,
      fields: {
        if (sesiId != null) 'calibration_session_id': '$sesiId',
        'jumlah_titik': '$jumlahTitik',
        'jumlah_pengulangan': '$jumlahBaris',
      },
      token: await _token(),
    );

    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return HasilEkstraksiTabel.fromJson(
      data,
      jumlahTitik: jumlahTitik,
      jumlahBaris: jumlahBaris,
    );
  }

  @override
  void dispose() {}
}

/// Pesan hasil foto tabel — **satu tempat**. Foto yang gagal bukan jalan buntu:
/// tiap cabang nutup dengan "kolomnya tetap bisa diketik manual", karena
/// teknisi udah berdiri di depan alat pelanggan — dia butuh jalan maju.
String pesanHasilFotoTabel({
  required int terisi,
  required int diharapkan,
  required int terdeteksi,
  required String takTerbaca,
  required String Function(int) posisiKacau,
  required String Function(int, int) berhasil,
  required String sisa,
}) {
  if (terisi > 0) {
    return terisi < diharapkan
        ? '${berhasil(terisi, diharapkan)} $sisa'
        : berhasil(terisi, diharapkan);
  }
  return terdeteksi == 0 ? takTerbaca : posisiKacau(terdeteksi);
}

/// Aturan penggabungan hasil ekstraksi ke isian yang udah ada di form.
///
/// Ini **aturan paling berbahaya** di seluruh alur foto: teknisi boleh motret
/// berkali-kali buat nambal sel yang kurang, dan angka yang udah dia betulin
/// manual nggak boleh keganti sama jepretan berikutnya. Kalau ketimpa,
/// koreksinya ilang tanpa jejak — dan yang masuk sertifikat justru angka AI
/// yang tadi salah.
class GabungTabel {
  const GabungTabel._();

  /// Nilai baru buat satu sel, atau `null` kalau sel itu nggak boleh diubah.
  /// Sel dianggap kosong kalau isinya spasi doang.
  static String? nilaiBaru(String sekarang, double? hasil) {
    if (hasil == null) return null;
    if (sekarang.trim().isNotEmpty) return null;
    return _rapi(hasil);
  }

  /// Buang nol di belakang: `4.0` → `4`, `22.2` tetap `22.2`, `10.11` tetap
  /// `10.11`. Bukan dibulatkan ke desimal tetap — pH 2 desimal, suhu 1 desimal.
  static String _rapi(double nilai) =>
      nilai.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Data tiruan buat test & jalanin app tanpa backend AI.
///
/// Default-nya pra-isi angka masuk akal biar `USE_MOCK` tetap bisa nyoba
/// alurnya. Sengaja ada satu sel keyakinan rendah supaya penandaan low-confidence
/// keliatan waktu demo.
class MockWorksheetVisionService implements WorksheetVisionService {
  MockWorksheetVisionService({this.hasil, this.gagal = false});

  final HasilEkstraksiTabel? hasil;
  final bool gagal;

  @override
  Future<HasilEkstraksiTabel?> ekstrak(
    File foto, {
    int jumlahTitik = 3,
    int jumlahBaris = 5,
    int? sesiId,
  }) async {
    if (gagal) throw Exception('ekstraksi AI gagal');
    if (hasil != null) return hasil;

    // Data contoh: dua Repeat kebaca, satu sel ditandai keyakinan rendah.
    return HasilEkstraksiTabel(
      baris: [
        BarisTabel(
          ph: List.generate(jumlahTitik, (t) => [4.01, 7.02, 10.11][t % 3]),
          suhu: List.filled(jumlahTitik, 22.2),
          phKeyakinan: List.generate(
            jumlahTitik,
            (t) => t == jumlahTitik - 1
                ? TingkatKeyakinan.rendah
                : TingkatKeyakinan.tinggi,
          ),
          suhuKeyakinan: List.filled(jumlahTitik, TingkatKeyakinan.tinggi),
        ),
      ],
      jumlahSelKebaca: jumlahTitik * 2,
      jumlahSelDiharapkan: jumlahBaris * jumlahTitik * 2,
      jumlahAngkaTerdeteksi: jumlahTitik * 2,
    );
  }

  @override
  void dispose() {}
}
