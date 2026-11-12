import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

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
/// foto tidak meninggalkan perangkat.
///
/// ## Titik sambung (setelah Fase 1 / `FotoUntukOcr` masuk ke `main`)
///
/// ```dart
/// // adaptor tipis — belum ditulis:
/// pastikanBukanSalinanArsip(citra: foto.citra, jpeg: foto.jpegAsli);
/// final hasil = await registrasiHalamanDiIsolate(
///   foto.citra, halamanPt: template.halamanPt!);
/// switch (hasil) {
///   case RegistrasiHalamanBerhasil():
///     return FotoHasilWarp(hasil.citra); // → _kenali / RegistrasiJangkarTeks
///   case RegistrasiHalamanGagal():
///     return null; // → foto asli + jalur lama / input manual
/// }
/// ```
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
  /// 180° yang benar TIDAK bisa ditentukan dari bentuk, jadi pemanggil yang
  /// tidak menemukan teks cetak di citra ini boleh mencoba putaran lain lewat
  /// parameter `putaranKuadran` (sudut sudah terdeteksi: gunakan
  /// [luruskanHalaman], tidak perlu deteksi ulang).
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
HasilRegistrasiHalaman registrasiHalaman(
  img.Image foto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) {
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
}

/// Luruskan [foto] dari [sudutFoto] yang sudah dideteksi (urutan kiri-atas,
/// kanan-atas, kanan-bawah, kiri-bawah, piksel foto). Memeriksa rasio sudut
/// terhadap [halamanPt] — sudut yang rasionya jauh dari halaman formulir
/// ditolak, bukan diregangkan.
HasilRegistrasiHalaman luruskanHalaman(
  img.Image foto,
  List<TitikHalaman> sudutFoto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
  DiagnostikRegistrasi? diagnostik,
}) {
  assert(sudutFoto.length == 4);
  assert(putaranKuadran == null || (putaranKuadran >= 0 && putaranKuadran < 4));

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
/// State/ref ke isolate lain.
Future<HasilRegistrasiHalaman> registrasiHalamanDiIsolate(
  img.Image foto, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) => Isolate.run(
  () => registrasiHalaman(
    foto,
    halamanPt: halamanPt,
    skala: skala,
    putaranKuadran: putaranKuadran,
    opsi: opsi,
  ),
);

/// Seperti [registrasiHalamanDiIsolate], tetapi dari bita foto (JPEG kamera
/// atau format lain yang dikenal paket `image`): decode, panggang EXIF, dan
/// registrasi semuanya di isolate latar — foto 12 MP tidak pernah menjadi
/// objek di isolate UI.
Future<HasilRegistrasiHalaman> registrasiHalamanDariBitaDiIsolate(
  Uint8List bita, {
  required ({double w, double h}) halamanPt,
  double skala = 3.0,
  int? putaranKuadran,
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) => Isolate.run(() {
  img.Image? foto;
  try {
    foto = img.decodeImage(bita);
  } on Exception catch (e) {
    return RegistrasiHalamanGagal(
      AlasanGagalRegistrasi.fotoTidakTerbaca,
      'decode gagal: $e',
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
});

img.Image _tegakkan(img.Image foto) {
  final ifd = foto.exif.imageIfd;
  if (!ifd.hasOrientation || ifd.orientation == 1) return foto;

  return img.bakeOrientation(foto);
}
