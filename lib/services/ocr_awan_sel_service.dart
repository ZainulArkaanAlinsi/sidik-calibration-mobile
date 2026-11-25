import 'dart:typed_data';

import '../models/ocr_awan.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Klien `POST /ocr/sel-awan` (kontrak `docs/kontrak-api.md` §22B di repo API):
/// OCR awan atas POTONGAN sel angka yang DIUNGGAH HP.
///
/// Yang naik ke server hanya potongan sel angka (berkas kecil per sel) dan kunci
/// selnya. Foto utuh, halaman utuh, sel identitas, tanggal, dan centang tidak
/// pernah menjadi masukan di sini: [OcrAwanSelService.bacaSel] menolak (dengan
/// [ArgumentError], sebelum jaringan) kunci `isian|`/`centang|` dan potongan yang
/// melewati batas ukuran sel. Server menegakkan hal yang sama, tetapi penjagaan
/// klien tidak bergantung padanya.
///
/// Tidak ada kunci Google atau URL Google di aplikasi: semuanya lewat backend.
///
/// Hasilnya USULAN (lihat `ocr_awan.dart`).

/// Batas berkas per permintaan selama server belum menaikkan `max_file_uploads`
/// PHP (bawaan 20; berkas ke-21 dan seterusnya dibuang PHP diam-diam). Batas
/// aplikasi di server 48 belum bisa dipakai penuh (§22B, "Batas PHP").
const maksSelPerPermintaanUnggah = 20;

/// Batas per potongan di server (`ocr.awan_sel`). Tebakan awal yang BELUM
/// diukur pada potongan foto nyata; potongan di atasnya dilewati di HP, bukan
/// diperkecil sampai tulisannya tidak terbaca.
const maksByteSelUnggah = 307200;
const maksPikselSelUnggah = 500000;

/// Format berkas potongan yang diterima server.
enum FormatPotongan { png, jpeg }

/// Kenapa sebuah potongan tidak boleh diunggah.
enum AlasanPotonganDitolak {
  /// Bukan PNG/JPEG yang terbaca (rusak, kosong, sisi nol).
  bukanCitra,

  /// Lebih dari [maksByteSelUnggah] byte.
  kebesaranByte,

  /// Lebar x tinggi lebih dari [maksPikselSelUnggah].
  kebesaranPiksel,
}

/// Satu potongan sel yang akan diunggah.
class PotonganSelAwan {
  const PotonganSelAwan({required this.kunci, required this.isi});

  /// Kunci templat apa adanya dari server (`tabel|baris|repeat|field`).
  final String kunci;

  /// Byte PNG/JPEG satu sel. Tidak disimpan, tidak ditulis ke log.
  final Uint8List isi;
}

/// Bagian templat/alat yang disertakan di tiap permintaan, supaya server menyusun
/// templat yang SAMA dengan yang dipakai HP saat mengambil templat.
class KonteksOcrAwanSel {
  const KonteksOcrAwanSel({
    required this.templateId,
    this.kertas = 'asli',
    this.kodeDokumen,
    this.equipmentId,
    this.jumlahPengulangan,
    this.calibrationSessionId,
  });

  final String templateId;

  /// `cetak` atau `asli`.
  final String kertas;
  final String? kodeDokumen;
  final int? equipmentId;
  final int? jumlahPengulangan;

  /// Menyalakan jatah per sesi di server. `null` = jatah per akun per hari.
  final int? calibrationSessionId;
}

/// Format dari byte awal berkas (bukan dari nama atau tipe MIME). `null` = bukan
/// PNG/JPEG.
FormatPotongan? bacaFormatPotongan(Uint8List b) {
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return FormatPotongan.png;
  }
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return FormatPotongan.jpeg;
  }
  return null;
}

/// Lebar x tinggi dari HEADER saja (tanpa mendekode citra), atau `null` bila
/// header tidak terbaca atau salah satu sisi nol. Sama dengan cara server
/// memeriksanya.
({int w, int h})? bacaUkuranPotongan(Uint8List b) {
  switch (bacaFormatPotongan(b)) {
    case FormatPotongan.png:
      // Signature (8) + panjang chunk (4) + "IHDR" (4) + lebar (4) + tinggi (4).
      if (b.length < 24) return null;
      final data = ByteData.sublistView(b);
      final w = data.getUint32(16);
      final h = data.getUint32(20);
      return w == 0 || h == 0 ? null : (w: w, h: h);
    case FormatPotongan.jpeg:
      return _ukuranJpeg(b);
    case null:
      return null;
  }
}

({int w, int h})? _ukuranJpeg(Uint8List b) {
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    // Penanda tanpa panjang: berdiri sendiri.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      i += 2;
      continue;
    }
    final panjang = (b[i + 2] << 8) | b[i + 3];
    // SOF0..SOF15 kecuali DHT (C4), JPG (C8), DAC (CC).
    final sof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (sof) {
      final h = (b[i + 5] << 8) | b[i + 6];
      final w = (b[i + 7] << 8) | b[i + 8];
      return w == 0 || h == 0 ? null : (w: w, h: h);
    }
    if (panjang < 2) return null;
    i += 2 + panjang;
  }
  return null;
}

/// Potongan ini boleh diunggah? `null` = boleh.
AlasanPotonganDitolak? periksaPotongan(Uint8List isi) {
  final ukuran = bacaUkuranPotongan(isi);
  if (ukuran == null) return AlasanPotonganDitolak.bukanCitra;
  if (isi.length > maksByteSelUnggah) return AlasanPotonganDitolak.kebesaranByte;
  if (ukuran.w * ukuran.h > maksPikselSelUnggah) {
    return AlasanPotonganDitolak.kebesaranPiksel;
  }
  return null;
}

abstract class OcrAwanSelService {
  /// Satu permintaan: 1 sampai [maksSelPerPermintaanUnggah] potongan.
  ///
  /// Melempar [ArgumentError] (bug pemanggil, sebelum jaringan) bila daftar
  /// kosong, lebih dari [maksSelPerPermintaanUnggah], ada kunci kosong / kembar /
  /// `isian|` / `centang|`, atau ada potongan yang gagal [periksaPotongan].
  ///
  /// Galat server: [GalatOcrAwan] bila bentuknya cocok kontrak; selain itu
  /// [ApiException] / `KoneksiException` apa adanya. **Tidak diulang otomatis,
  /// untuk status apa pun.** Pemanggil (lihat `PenjalurSaranAwan`) mengubah semua
  /// galat itu menjadi jatuh ke jalur lama.
  Future<HasilOcrAwan> bacaSel(
    String token, {
    required KonteksOcrAwanSel konteks,
    required List<PotonganSelAwan> sel,
  });
}

/// Pemeriksaan bersama service asli dan mock, supaya tiruan tidak lebih longgar.
void periksaPermintaanOcrAwanSel(List<PotonganSelAwan> sel) {
  if (sel.isEmpty) {
    throw ArgumentError.value(sel, 'sel', 'Daftar potongan kosong.');
  }
  if (sel.length > maksSelPerPermintaanUnggah) {
    throw ArgumentError.value(
      sel.length,
      'sel',
      'Maksimal $maksSelPerPermintaanUnggah potongan per permintaan.',
    );
  }

  final terlihat = <String>{};
  for (final s in sel) {
    if (s.kunci.trim().isEmpty) {
      throw ArgumentError.value(s.kunci, 'kunci', 'Kunci sel kosong.');
    }
    if (kunciSelIdentitas(s.kunci)) {
      throw ArgumentError.value(
        s.kunci,
        'kunci',
        'Sel isian/centang tidak pernah dikirim ke OCR awan.',
      );
    }
    if (!terlihat.add(s.kunci)) {
      throw ArgumentError.value(s.kunci, 'kunci', 'Kunci kembar.');
    }
    final alasan = periksaPotongan(s.isi);
    if (alasan != null) {
      throw ArgumentError.value(
        s.kunci,
        'sel',
        'Potongan tidak boleh diunggah: ${alasan.name}.',
      );
    }
  }
}

class ApiOcrAwanSelService implements OcrAwanSelService {
  ApiOcrAwanSelService(this._api);

  final ApiClient _api;

  /// Lebih lama dari bawaan POST biasa: server membaca hingga 20 potongan
  /// (dua panggilan Google). Menyerah duluan membuat server tetap bekerja dan
  /// jatah tetap terpakai.
  static const batasTunggu = Duration(seconds: 60);

  @override
  Future<HasilOcrAwan> bacaSel(
    String token, {
    required KonteksOcrAwanSel konteks,
    required List<PotonganSelAwan> sel,
  }) async {
    periksaPermintaanOcrAwanSel(sel);

    final berkas = <String, ({String namaBerkas, Uint8List isi})>{};
    for (var n = 0; n < sel.length; n++) {
      final png = bacaFormatPotongan(sel[n].isi) == FormatPotongan.png;
      berkas['sel[$n][gambar]'] = (
        namaBerkas: 'sel_$n.${png ? 'png' : 'jpg'}',
        isi: sel[n].isi,
      );
    }

    try {
      // Tanpa `client_request_id` dengan sengaja, dan `unggahBanyak` tidak
      // mengulang: `429` dan `502` TIDAK boleh diulang diam-diam (tiap panggilan
      // memakai jatah dan biaya, dan jaringan putus bisa berarti kiriman
      // pertama sudah sampai).
      final json = await _api.unggahBanyak(
        '/ocr/sel-awan',
        token: token,
        timeout: batasTunggu,
        body: {
          'template_id': konteks.templateId,
          'kertas': konteks.kertas,
          'kode_dokumen': ?_isiAtauNull(konteks.kodeDokumen),
          'equipment_id': ?konteks.equipmentId,
          'jumlah_pengulangan': ?konteks.jumlahPengulangan,
          'calibration_session_id': ?konteks.calibrationSessionId,
          'sel': [
            for (final s in sel) {'kunci': s.kunci},
          ],
        },
        berkas: berkas,
      );

      return HasilOcrAwan.fromJson(json);
    } on ApiException catch (e) {
      final galat = GalatOcrAwan.dariRespons(e);
      if (galat != null) throw galat;
      rethrow;
    }
  }
}

String? _isiAtauNull(String? teks) {
  final t = teks?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Tiruan buat test & mode mock. Bawaannya meniru produksi sekarang: OCR awan
/// belum aktif ([GalatOcrAwan] `awanBelumSiap`), jadi layar yang memakainya
/// teruji jatuh ke jalur lama.
class MockOcrAwanSelService implements OcrAwanSelService {
  MockOcrAwanSelService({this.hasil, this.galat, this.penjawab});

  /// Jawaban tetap (semua permintaan). `null` dan [penjawab] `null` = galat
  /// `awanBelumSiap`.
  final HasilOcrAwan? hasil;

  /// Bila diisi, dilempar (menang atas [hasil]).
  final Object? galat;

  /// Jawaban per permintaan (mis. meniru server yang membaca tiap potongan).
  final HasilOcrAwan Function(List<PotonganSelAwan> sel)? penjawab;

  /// Kunci yang diminta tiap pemanggilan, sesuai urutan panggilan.
  final List<List<String>> permintaan = [];
  final List<KonteksOcrAwanSel> konteksDiterima = [];

  @override
  Future<HasilOcrAwan> bacaSel(
    String token, {
    required KonteksOcrAwanSel konteks,
    required List<PotonganSelAwan> sel,
  }) async {
    periksaPermintaanOcrAwanSel(sel);

    permintaan.add([for (final s in sel) s.kunci]);
    konteksDiterima.add(konteks);

    final g = galat;
    if (g != null) throw g;
    if (penjawab != null) return penjawab!(sel);
    if (hasil != null) return hasil!;

    throw const GalatOcrAwan(
      status: 503,
      kode: 'ocr_cloud_belum_aktif',
      jenis: JenisGalatOcrAwan.awanBelumSiap,
      pesan: 'OCR awan belum aktif di server.',
    );
  }
}
