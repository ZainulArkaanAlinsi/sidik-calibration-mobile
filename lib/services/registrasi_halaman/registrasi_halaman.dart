import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../foto_untuk_ocr.dart'
    show FotoTerkompresiDitolak, pastikanBukanSalinanArsip;
import '../registrasi_jangkar_teks.dart' show Homografi, ratakanHalaman;
import 'deteksi_sudut_halaman.dart';
import 'geometri_halaman.dart';
import 'hasil_deteksi_halaman.dart';

export 'deteksi_sudut_halaman.dart' show deteksiSudutHalaman;
export 'geometri_halaman.dart'
    show TitikHalaman, perkirakanRasioHalaman, rasioPanjangSisi;
export 'hasil_deteksi_halaman.dart';

/// PAGE REGISTRATION (Fase 2, PR 3): foto lembar → halaman lurus.
///
/// Modul ini BERDIRI SENDIRI: belum disambung ke alur pindai, tombol pindai,
/// atau `JalankanPindaiAsli`. Tidak ada UI, state, atau jaringan di sini, dan
/// foto tidak meninggalkan perangkat. Keluarannya hanya USULAN geometri: yang
/// dibaca dan dikonfirmasi teknisi tetap angka di sel, bukan modul ini.
///
/// ## Yang dijamin, dan batasnya
///
///  - Setiap kegagalan yang TERDETEKSI (alas terang, tepi terpotong, tepi
///    melengkung, bentuk tak wajar, rasio tak cocok, berkas rusak/terpotong)
///    menjadi [RegistrasiHalamanGagal], tidak pernah sudut tebakan. Fungsi di
///    sini tidak melempar galat pada foto buruk; satu-satunya pengecualian
///    adalah [FotoTerkompresiDitolak] (kesalahan PEMANGGIL: salinan arsip
///    terkompresi tidak boleh masuk jalur OCR).
///  - Itu BUKAN jaminan "tidak pernah salah". Bentuk segi empat saja tidak
///    membedakan halaman dari lembar atau tumpukan kertas LEBIH BESAR dengan
///    rasio yang sama di bawahnya (bantalan, map, tumpukan formulir): tepi luar
///    bantalan lolos semua pemeriksaan di sini, dan sel akan dibaca dari bagian
///    yang salah. Pada foto sintetis, bantalan 6% dan 12% sisi terkunci sebagai
///    halaman (galat 3,5–8% diagonal) tanpa penolakan; lihat uji "batas
///    diketahui". Tidak ada pemeriksaan murah yang andal: garis bingkai cetak
///    formulir tak bisa dibedakan dari garis tepi halaman di atas bantalan.
///  - Maka registrasi jangkar teks / kode formulir (`RegistrasiJangkarTeks` dan
///    pembacaan kode formulir) WAJIB menjadi pemeriksa kedua pada citra hasil
///    modul ini SEBELUM sel dibaca. Jangkar yang tidak ditemukan di tempat
///    yang diharapkan = jatuh ke jalur lama / input manual, bukan membaca sel.
///
/// ## Titik sambung (setelah Fase 1 / `FotoUntukOcr` masuk ke `main`)
///
/// Adaptor memanggil varian bita supaya decode foto 12 MP dan pemanggangan EXIF
/// terjadi di isolate latar. Penjaga salinan arsip Fase 1
/// (`pastikanBukanSalinanArsip`) sudah dipanggil di dalam modul ini, untuk
/// bita sebelum decode dan untuk citra sesudahnya; adaptor tidak perlu
/// mengulanginya.
///
/// ```dart
/// // adaptor tipis — belum ditulis:
/// final hasil = await registrasiHalamanDariBitaDiIsolate(
///   jpegAsli, halamanPt: template.halamanPt!); // atau registrasiHalamanDiIsolate(citra)
/// switch (hasil) {
///   case RegistrasiHalamanBerhasil():
///     // 1) verifikasi ORIENTASI (lihat di bawah), 2) pemeriksa kedua jangkar
///     //    teks / kode formulir, baru 3) FotoHasilWarp → _kenali.
///     return FotoHasilWarp(hasil.citra);
///   case RegistrasiHalamanGagal():
///     return null; // → foto asli + jalur lama / input manual
/// }
/// ```
///
/// ## Arah 90° / 180° TIDAK bisa ditentukan dari bentuk
///
/// Segi empat tidak membedakan halaman tegak dari terbalik 180° (dan, untuk
/// rasio yang cocok dua arah, dari terputar 90°). Mode otomatis hanya memilih
/// putaran 0 atau 1 dari rasio. Adaptor WAJIB memverifikasi arah lewat kode
/// formulir / teks cetak pada citra hasil dan, bila tidak ditemukan, mencoba
/// putaran lain dari sudut YANG SAMA ([luruskanHalaman] dengan
/// `putaranKuadran` 0–3, tanpa deteksi ulang). Tidak ada putaran yang cocok =
/// jatuh ke jalur lama.
///
/// Semua koordinat sudut ([RegistrasiHalamanBerhasil.sudutFoto]) adalah piksel
/// foto SESUDAH orientasi EXIF dipanggang. [luruskanHalaman] TIDAK memanggang
/// EXIF: memberinya foto mentah yang masih membawa orientasi ≠ 1 meluruskan
/// bagian yang salah. Adaptor harus memberi foto yang sudah tegak (mis.
/// `img.bakeOrientation`), bukan foto mentah.
///
/// Keluarannya [RegistrasiHalamanBerhasil.citra] adalah citra BARU hasil
/// `ratakanHalaman` dari foto ASLI resolusi penuh (tidak pernah dikompresi,
/// tanpa EXIF), jadi cocok dengan penjaga kompresi: bukan `SalinanArsip`.

/// Hasil registrasi halaman.
sealed class HasilRegistrasiHalaman {
  const HasilRegistrasiHalaman();
}

final class RegistrasiHalamanBerhasil extends HasilRegistrasiHalaman {
  const RegistrasiHalamanBerhasil({
    required this.citra,
    required this.sudutFoto,
    required this.templateKeFoto,
    required this.halamanPt,
    required this.skala,
    required this.putaranKuadran,
    required this.rasioPerkiraan,
    required this.diagnostik,
    required this.durasiWarpMs,
  });

  /// Halaman lurus: `halamanPt × skala` piksel (3 px/pt bawaan), piksel di luar
  /// foto putih. Siap dibungkus `FotoHasilWarp`.
  final img.Image citra;

  /// Sudut halaman di FOTO ASLI (piksel SESUDAH EXIF dipanggang), urutan
  /// kiri-atas, kanan-atas, kanan-bawah, kiri-bawah menurut HALAMAN (sudah
  /// dipasangkan sesuai [putaranKuadran]).
  final List<TitikHalaman> sudutFoto;

  /// Point halaman → piksel foto asli. Bahan awal bagi registrasi jangkar
  /// teks (residual halus), dan untuk mengukur galat terhadap kunci jawaban.
  final Homografi templateKeFoto;

  final ({double w, double h}) halamanPt;
  final double skala;

  /// Berapa seperempat putaran sudut-sudut digeser dari urutan "paling dekat
  /// ke tegak di foto": 0 = halaman tegak (atau terbalik 180° — bentuk
  /// segi empat tidak membedakan), 1 = sisi atas halaman = sisi KIRI foto,
  /// 2 = atas halaman = bawah foto, 3 = atas halaman = sisi KANAN foto.
  ///
  /// Mode otomatis hanya memilih 0 atau 1 (dari rasio halaman); arah 90° dan
  /// 180° yang benar TIDAK bisa ditentukan dari bentuk. Pemanggil WAJIB
  /// memverifikasi arah lewat kode formulir / teks cetak di citra ini, dan
  /// mencoba putaran lain bila tidak ketemu (sudut sudah terdeteksi: gunakan
  /// [luruskanHalaman], tidak perlu deteksi ulang). Lihat KDoc kepala berkas.
  final int putaranKuadran;

  /// Rasio lebar/tinggi halaman dari sudut terdeteksi (sesudah putaran): yang
  /// lebih dekat ke rasio formulir di antara taksiran perspektif dan taksiran
  /// panjang sisi. Hanya angka kewajaran, bukan pengukuran.
  final double rasioPerkiraan;

  final DiagnostikRegistrasi diagnostik;
  final double durasiWarpMs;
}

final class RegistrasiHalamanGagal extends HasilRegistrasiHalaman {
  const RegistrasiHalamanGagal(this.alasan, this.detail, [this.diagnostik]);

  /// Kegagalan = JANGAN meluruskan: pemanggil memakai foto asli.
  final AlasanGagalRegistrasi alasan;
  final String detail;
  final DiagnostikRegistrasi? diagnostik;

  @override
  String toString() => 'RegistrasiHalamanGagal(${alasan.name}: $detail)';
}

/// Deteksi sudut lalu luruskan. [foto] harus sudah tegak (EXIF dipanggang);
/// kalau masih membawa orientasi EXIF selain 1, dipanggang di sini.
///
/// [halamanPt] = ukuran halaman formulir (dari template atau pilihan jenis
/// lembar). [putaranKuadran] `null` = otomatis (lihat
/// [RegistrasiHalamanBerhasil.putaranKuadran]).
///
/// Tidak melempar pada foto buruk: galat apa pun di dalam (mis. `RangeError`
/// dari data piksel rusak) menjadi [RegistrasiHalamanGagal] dengan alasan
/// `fotoTidakTerbaca`. Pengecualian tunggal: [FotoTerkompresiDitolak] bila
/// [foto] berasal dari salinan arsip terkompresi.
HasilRegistrasiHalaman registrasiHalaman(
  img.Image foto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) {
  // Pintu belakang penjaga kompresi: SEBELUM menyentuh piksel, dan di luar
  // try di bawah supaya tidak ikut tertelan sebagai "gagal".
  pastikanBukanSalinanArsip(citra: foto);

  try {
    final tegak = _tegakkan(foto);
    final deteksi = deteksiSudutHalaman(tegak, opsi: opsi);

    return switch (deteksi) {
      DeteksiHalamanGagal() => RegistrasiHalamanGagal(
        deteksi.alasan,
        deteksi.detail,
        deteksi.diagnostik,
      ),
      DeteksiHalamanBerhasil() => luruskanHalaman(
        tegak,
        deteksi.sudut,
        halamanPt: halamanPt,
        skala: skala,
        putaranKuadran: putaranKuadran,
        opsi: opsi,
        diagnostik: deteksi.diagnostik,
      ),
    };
  } on FotoTerkompresiDitolak {
    rethrow;
  } on Object catch (e) {
    return _gagalTakTerduga(e);
  }
}

/// Luruskan [foto] dari [sudutFoto] yang sudah dideteksi (urutan kiri-atas,
/// kanan-atas, kanan-bawah, kiri-bawah, piksel foto SESUDAH EXIF dipanggang;
/// [foto] sendiri harus sudah tegak, fungsi ini tidak memanggangnya).
/// Memeriksa rasio sudut terhadap [halamanPt] — sudut yang rasionya jauh dari
/// halaman formulir ditolak, bukan diregangkan.
///
/// Masukan yang tidak masuk akal ditolak sebagai [RegistrasiHalamanGagal]
/// (`bentukTidakWajar`), bukan `assert` yang hilang di rilis: bukan empat
/// sudut, koordinat bukan bilangan terhingga, urutan sudut berlawanan arah
/// (luas bertanda ≤ 0: hasil warp akan TERCERMIN), segi empat tidak cembung,
/// [skala] atau [halamanPt] ≤ 0, [putaranKuadran] di luar 0–3.
HasilRegistrasiHalaman luruskanHalaman(
  img.Image foto,
  List<TitikHalaman> sudutFoto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
  DiagnostikRegistrasi? diagnostik,
}) {
  pastikanBukanSalinanArsip(citra: foto);

  final ditolak = _periksaMasukan(
    sudutFoto,
    halamanPt: halamanPt,
    skala: skala,
    putaranKuadran: putaranKuadran,
    diagnostik: diagnostik,
  );
  if (ditolak != null) return ditolak;

  try {
    return _luruskan(
      foto,
      sudutFoto,
      halamanPt: halamanPt,
      skala: skala,
      putaranKuadran: putaranKuadran,
      opsi: opsi,
      diagnostik: diagnostik,
    );
  } on Object catch (e) {
    return _gagalTakTerduga(e, diagnostik);
  }
}

RegistrasiHalamanGagal? _periksaMasukan(
  List<TitikHalaman> sudutFoto, {
  required ({double w, double h}) halamanPt,
  required double skala,
  required int? putaranKuadran,
  required DiagnostikRegistrasi? diagnostik,
}) {
  RegistrasiHalamanGagal tolak(String detail) => RegistrasiHalamanGagal(
    AlasanGagalRegistrasi.bentukTidakWajar,
    'masukan ditolak: $detail',
    diagnostik,
  );

  if (sudutFoto.length != 4) {
    return tolak('butuh 4 sudut, diberi ${sudutFoto.length}');
  }
  if (putaranKuadran != null && (putaranKuadran < 0 || putaranKuadran > 3)) {
    return tolak('putaranKuadran $putaranKuadran di luar 0–3');
  }
  if (!skala.isFinite || skala <= 0) {
    return tolak('skala $skala harus bilangan terhingga > 0');
  }
  if (!halamanPt.w.isFinite ||
      !halamanPt.h.isFinite ||
      halamanPt.w <= 0 ||
      halamanPt.h <= 0) {
    return tolak('ukuran halaman ${halamanPt.w}×${halamanPt.h} tidak sah');
  }
  for (final s in sudutFoto) {
    if (!s.x.isFinite || !s.y.isFinite) {
      return tolak('koordinat sudut bukan bilangan terhingga');
    }
  }

  // Tali sepatu bertanda: urutan kiri-atas → kanan-atas → kanan-bawah →
  // kiri-bawah searah jarum jam di koordinat foto (y ke bawah) = luas positif.
  // Negatif = urutan terbalik; homografinya sah secara matematis tetapi
  // menghasilkan halaman TERCERMIN, yang akan dibaca diam-diam.
  final luas = _luasBertanda(sudutFoto);
  if (!(luas > 0)) {
    return tolak(
      'urutan sudut berlawanan arah / merosot (luas bertanda '
      '${luas.toStringAsFixed(1)})',
    );
  }
  if (!segiEmpatCembung(sudutFoto)) {
    return tolak('segi empat sudut tidak cembung');
  }

  return null;
}

double _luasBertanda(List<TitikHalaman> p) {
  var jumlah = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i];
    final b = p[(i + 1) % p.length];
    jumlah += a.x * b.y - b.x * a.y;
  }

  return jumlah / 2;
}

HasilRegistrasiHalaman _luruskan(
  img.Image foto,
  List<TitikHalaman> sudutFoto, {
  required ({double w, double h}) halamanPt,
  required double skala,
  required int? putaranKuadran,
  required OpsiRegistrasiHalaman opsi,
  required DiagnostikRegistrasi? diagnostik,
}) {
  final rasioHalaman = halamanPt.w / halamanPt.h;

  // Dua penaksir rasio, dan sudut diterima bila SALAH SATUNYA cocok:
  //  - Zhang & He: koreksi perspektif, tetapi mengandaikan titik pokok di
  //    tengah dan sudut yang konsisten dengan kamera lubang-jarum — pada foto
  //    nyaris tegak lurus atau sudut yang sedikit berderau bisa meleset 10%+.
  //  - panjang sisi: tidak mengoreksi perspektif, tetapi tidak pernah liar.
  // Ini cuma pemeriksaan kewajaran "bukan wilayah lain di foto"; ketepatan
  // sudut dijaga tahap deteksi dan registrasi jangkar, bukan rasio.
  final rasioZh = perkirakanRasioHalaman(
    sudutFoto,
    foto.width / 2,
    foto.height / 2,
  );
  final rasioSisi = rasioPanjangSisi(sudutFoto);

  // Sisi atas halaman = sisi atas foto (putaran genap) atau sisi samping
  // (ganjil): rasio efektifnya dibalik.
  double efektif(double rasio, int putaran) =>
      putaran.isEven ? rasio : 1 / rasio;

  double deviasi(double rasio, int putaran) =>
      (efektif(rasio, putaran) / rasioHalaman - 1).abs();

  // Penaksir yang paling dekat ke rasio halaman untuk [putaran] ini.
  double terdekat(int putaran) =>
      deviasi(rasioZh, putaran) <= deviasi(rasioSisi, putaran)
      ? efektif(rasioZh, putaran)
      : efektif(rasioSisi, putaran);

  bool cocok(int putaran) =>
      (terdekat(putaran) / rasioHalaman - 1).abs() <= opsi.toleransiRasio;

  final int putaran;
  if (putaranKuadran != null) {
    putaran = putaranKuadran;
  } else if (cocok(0) &&
      (!cocok(1) ||
          (terdekat(0) / rasioHalaman - 1).abs() <=
              (terdekat(1) / rasioHalaman - 1).abs())) {
    putaran = 0;
  } else if (cocok(1)) {
    putaran = 1;
  } else {
    putaran = 0;
  }

  if (!cocok(putaran)) {
    return RegistrasiHalamanGagal(
      AlasanGagalRegistrasi.rasioTidakCocok,
      'rasio sudut ${efektif(rasioZh, putaran).toStringAsFixed(3)} '
      '(perspektif) / ${efektif(rasioSisi, putaran).toStringAsFixed(3)} '
      '(sisi) vs halaman ${rasioHalaman.toStringAsFixed(3)} '
      '(toleransi ${(opsi.toleransiRasio * 100).toStringAsFixed(0)}%)',
      diagnostik,
    );
  }

  // Geser urutan sudut: putaran 1 → [kiri-bawah, kiri-atas, kanan-atas,
  // kanan-bawah] foto menjadi [kiri-atas … kiri-bawah] halaman.
  final urut = [for (var i = 0; i < 4; i++) sudutFoto[(i - putaran + 4) % 4]];

  final h = Homografi.kuadratTerkecil([
    (x: 0.0, y: 0.0),
    (x: halamanPt.w, y: 0.0),
    (x: halamanPt.w, y: halamanPt.h),
    (x: 0.0, y: halamanPt.h),
  ], urut);
  if (h == null) {
    return RegistrasiHalamanGagal(
      AlasanGagalRegistrasi.bentukTidakWajar,
      'homografi sudut → halaman tidak ada',
      diagnostik,
    );
  }

  final jam = Stopwatch()..start();
  final warp = ratakanHalaman(foto, h, halamanPt: halamanPt, skala: skala);

  return RegistrasiHalamanBerhasil(
    citra: warp,
    sudutFoto: urut,
    templateKeFoto: h,
    halamanPt: halamanPt,
    skala: skala,
    putaranKuadran: putaran,
    rasioPerkiraan: terdekat(putaran),
    diagnostik: diagnostik ?? const DiagnostikRegistrasi(),
    durasiWarpMs: jam.elapsedMicroseconds / 1000,
  );
}

/// [registrasiHalaman] di isolate latar: pelatuk beratnya (perkecil 12 MP,
/// komponen terhubung, warp 4,4 MP) tidak boleh membekukan layar.
///
/// Fungsi tingkat atas; closure-nya hanya memegang argumen, tidak membawa
/// State/ref ke isolate lain. Future TIDAK PERNAH gagal karena foto buruk
/// (hasilnya [RegistrasiHalamanGagal]); satu-satunya Future-error yang
/// disengaja adalah [FotoTerkompresiDitolak], dilempar SEBELUM isolate dibuat.
Future<HasilRegistrasiHalaman> registrasiHalamanDiIsolate(
  img.Image foto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) async {
  // Di isolate pemanggil: penanda identitas objek (Expando) tidak ikut
  // tersalin ke isolate lain, penanda di dalam EXIF ikut.
  pastikanBukanSalinanArsip(citra: foto);

  try {
    return await Isolate.run(
      () => registrasiHalaman(
        foto,
        halamanPt: halamanPt,
        skala: skala,
        putaranKuadran: putaranKuadran,
        opsi: opsi,
      ),
    );
  } on FotoTerkompresiDitolak {
    rethrow;
  } on Object catch (e) {
    return _gagalTakTerduga(e);
  }
}

/// Seperti [registrasiHalamanDiIsolate], tetapi dari bita foto (JPEG kamera
/// atau format lain yang dikenal paket `image`): decode, panggang EXIF, dan
/// registrasi semuanya di isolate latar — foto 12 MP tidak pernah menjadi
/// objek di isolate UI. Ini varian yang dipakai adaptor.
///
/// Bita yang memuat penanda salinan arsip ditolak SEBELUM decode
/// ([FotoTerkompresiDitolak]). Bita kosong, terpotong, atau rusak (decoder
/// `image` melempar `RangeError`/`FormatException`) menjadi
/// [RegistrasiHalamanGagal] `fotoTidakTerbaca`, bukan Future-error.
Future<HasilRegistrasiHalaman> registrasiHalamanDariBitaDiIsolate(
  Uint8List bita, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) async {
  pastikanBukanSalinanArsip(jpeg: bita);

  try {
    return await Isolate.run(
      () => _registrasiDariBita(
        bita,
        halamanPt: halamanPt,
        skala: skala,
        putaranKuadran: putaranKuadran,
        opsi: opsi,
      ),
    );
  } on FotoTerkompresiDitolak {
    rethrow;
  } on Object catch (e) {
    return _gagalTakTerduga(e);
  }
}

/// Isi isolate [registrasiHalamanDariBitaDiIsolate]: decode lalu registrasi.
/// Sampai di sini bita sudah lolos penjaga salinan arsip; citra hasil decode
/// diperiksa lagi (penanda di EXIF) oleh [registrasiHalaman].
HasilRegistrasiHalaman _registrasiDariBita(
  Uint8List bita, {
  required ({double w, double h}) halamanPt,
  required double skala,
  required int? putaranKuadran,
  required OpsiRegistrasiHalaman opsi,
}) {
  img.Image? foto;
  try {
    foto = img.decodeImage(bita);
  } on Object catch (e) {
    // JPEG kosong/terpotong/rusak: decoder melempar RangeError (sebuah Error,
    // bukan Exception), jadi `on Exception` saja meloloskannya.
    return RegistrasiHalamanGagal(
      AlasanGagalRegistrasi.fotoTidakTerbaca,
      'decode gagal: ${_ringkas(e)}',
    );
  }
  if (foto == null) {
    return const RegistrasiHalamanGagal(
      AlasanGagalRegistrasi.fotoTidakTerbaca,
      'format tidak dikenal',
    );
  }

  return registrasiHalaman(
    foto,
    halamanPt: halamanPt,
    skala: skala,
    putaranKuadran: putaranKuadran,
    opsi: opsi,
  );
}

RegistrasiHalamanGagal _gagalTakTerduga(
  Object e, [
  DiagnostikRegistrasi? diagnostik,
]) => RegistrasiHalamanGagal(
  AlasanGagalRegistrasi.fotoTidakTerbaca,
  'galat tak terduga: ${_ringkas(e)}',
  diagnostik,
);

String _ringkas(Object e) {
  final pesan = '$e';

  return '${e.runtimeType}: '
      '${pesan.length > 160 ? pesan.substring(0, 160) : pesan}';
}

img.Image _tegakkan(img.Image foto) {
  final ifd = foto.exif.imageIfd;
  if (!ifd.hasOrientation || ifd.orientation == 1) return foto;

  return img.bakeOrientation(foto);
}
