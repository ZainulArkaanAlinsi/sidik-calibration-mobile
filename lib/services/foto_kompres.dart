import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'foto_untuk_ocr.dart';

/// KOMPRESI FOTO UNTUK SALINAN ARSIP / UNGGAHAN SAJA.
///
/// Keluarannya [SalinanArsip], BUKAN [FotoUntukOcr]: mesin OCR tidak menerima
/// tipe ini (lihat `foto_untuk_ocr.dart`). Modul ini belum punya pemanggil
/// aktif — dipasang lebih dulu supaya kuncinya sudah ada sebelum ada yang
/// mengunggah foto. Hanya mesin Dart murni (paket `image`, sudah menjadi
/// dependensi): tidak menambah paket/biner native, jadi ukuran APK ~tidak
/// berubah. Mesin native (WebP) bisa disuntik lewat [PemampatGambar] kelak.

/// Ruang untuk penanda arsip yang ditambahkan ke byte hasil (EXIF
/// `ImageDescription`, puluhan byte). Target ukuran dihitung SESUDAH penanda.
const _cadanganPenanda = 512;

/// Format keluaran kompresi.
enum FormatFoto {
  webp('image/webp', 'webp'),
  jpeg('image/jpeg', 'jpg');

  const FormatFoto(this.mime, this.ekstensi);

  final String mime;
  final String ekstensi;
}

/// Batas kompresi satu foto. Bawaannya mengikuti perintah pemilik: maksimal
/// 500 KB dan 1920x1080 (sisi panjang 1920, sisi pendek 1080 — orientasi foto
/// tidak dipaksa, jadi potret jadi 1080x1920).
class OpsiKompres {
  const OpsiKompres({
    this.targetByte = 500 * 1024,
    this.sisiPanjangMaks = 1920,
    this.sisiPendekMaks = 1080,
    this.kualitasAwal = 85,
    this.kualitasMin = 30,
    this.langkahKualitas = 10,
    this.maksPenyusutan = 3,
    this.utamakanWebp = true,
  }) : assert(kualitasAwal >= kualitasMin),
       assert(langkahKualitas > 0);

  /// Ukuran akhir yang dikejar, dalam byte.
  final int targetByte;

  /// `null` pada KEDUANYA = ukuran piksel dipertahankan. Dipakai bila yang
  /// menerima foto menghitung koordinat dari ukuran piksel aslinya (citra
  /// hasil warp lembar cetak): mengecilkan citranya menggeser semua kotak.
  final int? sisiPanjangMaks;
  final int? sisiPendekMaks;

  final int kualitasAwal;

  /// Lantai kualitas. Di bawah ini angka tulisan tangan di foto sudah tidak
  /// layak dipakai sebagai bukti audit, jadi penurunan berhenti di sini dan
  /// sisanya ditempuh dengan mengecilkan piksel ([maksPenyusutan]).
  final int kualitasMin;
  final int langkahKualitas;

  /// Berapa kali piksel boleh diperkecil 15% sesudah kualitas mentok di
  /// [kualitasMin]. 0 = tidak pernah; hasilnya bisa melewati [targetByte]
  /// (dilaporkan lewat [MetrikKompres.capaiTarget]), bukan dipotong diam-diam.
  final int maksPenyusutan;

  /// WebP dulu bila ada mesin yang bisa; selain itu JPEG.
  final bool utamakanWebp;

  /// Sisi (lebar, tinggi) hasil untuk foto [lebar]x[tinggi]: dimuat ke kotak
  /// [sisiPanjangMaks] x [sisiPendekMaks] tanpa pernah diperbesar.
  ({int lebar, int tinggi}) ukuranAkhir(int lebar, int tinggi) {
    final panjang = math.max(lebar, tinggi);
    final pendek = math.min(lebar, tinggi);
    var skala = 1.0;
    if (sisiPanjangMaks != null && panjang > sisiPanjangMaks!) {
      skala = math.min(skala, sisiPanjangMaks! / panjang);
    }
    if (sisiPendekMaks != null && pendek > sisiPendekMaks!) {
      skala = math.min(skala, sisiPendekMaks! / pendek);
    }
    if (skala >= 1.0) return (lebar: lebar, tinggi: tinggi);

    return (
      lebar: math.max(1, (lebar * skala).floor()),
      tinggi: math.max(1, (tinggi * skala).floor()),
    );
  }
}

/// Ukur-ukuran satu kompresi — bahan metadata (ukuran asli/akhir, format,
/// kualitas, mesin). Dikembalikan ke pemanggil; menyimpannya ke server
/// bergantung pada kolom yang tersedia di sana.
class MetrikKompres {
  const MetrikKompres({
    required this.asliByte,
    required this.akhirByte,
    required this.lebarAsli,
    required this.tinggiAsli,
    required this.lebarAkhir,
    required this.tinggiAkhir,
    required this.format,
    required this.kualitas,
    required this.mesin,
    required this.iterasi,
    required this.capaiTarget,
    required this.durasi,
    required this.dilewati,
    required this.diprosesPada,
  });

  final int asliByte;
  final int akhirByte;
  final int lebarAsli;
  final int tinggiAsli;
  final int lebarAkhir;
  final int tinggiAkhir;

  /// `null` bila [dilewati] (byte asli dikembalikan apa adanya).
  final FormatFoto? format;
  final int kualitas;
  final String mesin;
  final int iterasi;

  /// [akhirByte] <= target.
  final bool capaiTarget;
  final Duration durasi;

  /// Foto sudah memenuhi batas: dikembalikan tanpa dikodekan ulang.
  final bool dilewati;
  final DateTime diprosesPada;

  /// Berapa persen yang terbuang (0..1).
  double get rasioHemat => asliByte == 0 ? 0 : 1 - akhirByte / asliByte;

  Map<String, Object?> toJson() => {
    'asli_byte': asliByte,
    'akhir_byte': akhirByte,
    'lebar_asli': lebarAsli,
    'tinggi_asli': tinggiAsli,
    'lebar_akhir': lebarAkhir,
    'tinggi_akhir': tinggiAkhir,
    'format': format?.name,
    'kualitas': kualitas,
    'mesin': mesin,
    'iterasi': iterasi,
    'capai_target': capaiTarget,
    'dilewati': dilewati,
    'diproses_pada': diprosesPada.toUtc().toIso8601String(),
  };
}

class HasilKompres {
  const HasilKompres({required this.salinan, required this.metrik});

  /// Salinan arsip (bukan bahan OCR).
  final SalinanArsip salinan;
  final MetrikKompres metrik;

  Uint8List get byte => salinan.byte;
  String get mime => salinan.mime;
  String get ekstensi => salinan.ekstensi;
}

/// Foto yang sudah diputar tegak dan diperkecil ke ukuran akhir, dikemas PNG
/// (lossless) supaya setiap mesin menerima piksel yang sama persis. Mesin
/// hanya mengodekan ulang ke WebP/JPEG pada kualitas tertentu.
class CitraSiap {
  const CitraSiap({
    required this.lebar,
    required this.tinggi,
    required this.png,
  });

  final int lebar;
  final int tinggi;
  final Uint8List png;
}

/// Satu mesin pengodean. Tidak tahu soal target ukuran atau penurunan
/// kualitas — itu urusan [FotoKompres], supaya perilakunya sama di semua
/// mesin dan bisa diuji tanpa platform channel.
abstract interface class PemampatGambar {
  String get nama;

  bool dukung(FormatFoto format);

  /// [kualitas] 1..100. Melempar bila mesin gagal (modul native tidak ada,
  /// format tidak didukung) — [FotoKompres] lalu mencoba mesin berikutnya.
  Future<Uint8List> kodekan(CitraSiap citra, FormatFoto format, int kualitas);
}

/// Mesin Dart murni (paket `image`): jalan di semua platform, termasuk
/// Windows, tapi hanya JPEG (paket `image` tidak punya encoder WebP).
/// Pengodean dijalankan di isolate supaya UI tidak tersendat.
class PemampatDartMurni implements PemampatGambar {
  const PemampatDartMurni();

  @override
  String get nama => 'dart-murni';

  @override
  bool dukung(FormatFoto format) => format == FormatFoto.jpeg;

  @override
  Future<Uint8List> kodekan(
    CitraSiap citra,
    FormatFoto format,
    int kualitas,
  ) async {
    if (format != FormatFoto.jpeg) {
      throw UnsupportedError('Mesin Dart murni hanya mengodekan JPEG.');
    }
    // PNG hasil [FotoKompres] didekode SEKALI per citra (di isolate); tiap
    // iterasi kualitas hanya mengodekan JPEG. Dekode berulang dulu memakan
    // separuh waktu penggelung.
    final pakai = _cacheDekode[citra] ?? await _dekode(citra);

    return Isolate.run(
      () => Uint8List.fromList(img.encodeJpg(pakai, quality: kualitas)),
    );
  }
}

final _cacheDekode = Expando<img.Image>('dekode-foto-kompres');

Future<img.Image> _dekode(CitraSiap citra) async {
  final png = citra.png;
  final g = await Isolate.run(() {
    final d = img.decodePng(png);
    if (d == null) throw const FormatException('PNG sementara rusak');

    return d;
  });
  _cacheDekode[citra] = g;

  return g;
}

/// Layanan kompresi foto: target ukuran + batas piksel, WebP bila ada mesin
/// yang mampu, JPEG sebagai cadangan. TIDAK bergantung pada model OCR atau
/// layar mana pun, jadi bisa dipakai ulang (mis. Studio) lewat injeksi.
///
/// Urutan kerja:
///  1. Foto yang sudah memenuhi batas dikembalikan apa adanya.
///  2. Decode + putar tegak (EXIF) + perkecil — SATU kali, di isolate.
///  3. Kodekan pada kualitas awal; turunkan [OpsiKompres.langkahKualitas]
///     sampai muat [OpsiKompres.targetByte] atau menyentuh lantai.
///  4. Mentok di lantai dan masih besar: perkecil piksel 15%, ulangi.
///  5. Mesin gagal -> mesin berikutnya. Semua gagal -> galat dilempar; JANGAN
///     menelannya jadi "berhasil" (pemanggil memutuskan mengirim aslinya).
class FotoKompres {
  FotoKompres({required List<PemampatGambar> mesin, DateTime Function()? jam})
    : assert(mesin.isNotEmpty),
      _mesin = List.unmodifiable(mesin),
      _jam = jam ?? DateTime.now;

  final List<PemampatGambar> _mesin;
  final DateTime Function() _jam;

  /// Nama mesin urut prioritas — untuk log dan test.
  List<String> get namaMesin => [for (final m in _mesin) m.nama];

  Future<HasilKompres> kompres(
    Uint8List sumber, {
    OpsiKompres opsi = const OpsiKompres(),
  }) async {
    final mulai = Stopwatch()..start();
    final siap = await Isolate.run(() => _siapkan(sumber, opsi));

    // Sudah memenuhi batas: tidak ada alasan menurunkan mutunya.
    if (sumber.length + _cadanganPenanda <= opsi.targetByte &&
        siap.lebarAsli == siap.lebar &&
        siap.tinggiAsli == siap.tinggi &&
        siap.formatSumberDikenal &&
        siap.mimeSumber == 'image/jpeg') {
      // SALINAN byte, bukan `sumber` itu sendiri: salinan arsip ditandai
      // (identitas objek) sebagai terkompresi, dan byte kamera asli tidak
      // boleh ikut tertandai lalu ditolak OCR.
      final salinan = SalinanArsip.dari(
        Uint8List.fromList(sumber),
        mime: siap.mimeSumber,
        ekstensi: siap.ekstensiSumber,
      );

      return HasilKompres(
        salinan: salinan,
        metrik: MetrikKompres(
          asliByte: sumber.length,
          akhirByte: salinan.byte.length,
          lebarAsli: siap.lebarAsli,
          tinggiAsli: siap.tinggiAsli,
          lebarAkhir: siap.lebarAsli,
          tinggiAkhir: siap.tinggiAsli,
          format: null,
          kualitas: 100,
          mesin: 'tanpa-ubah',
          iterasi: 0,
          capaiTarget: true,
          durasi: mulai.elapsed,
          dilewati: true,
          diprosesPada: _jam(),
        ),
      );
    }

    final urutan = opsi.utamakanWebp
        ? const [FormatFoto.webp, FormatFoto.jpeg]
        : const [FormatFoto.jpeg];

    Object? galatTerakhir;

    for (final mesin in _mesin) {
      for (final format in urutan) {
        if (!mesin.dukung(format)) continue;

        try {
          final hasil = await _jalankan(
            mesin,
            format,
            siap,
            sumber.length,
            opsi,
            mulai,
          );
          return hasil;
        } catch (e) {
          galatTerakhir = e;
          // Mesin ini gagal untuk format ini -> format berikutnya / mesin lain.
        }
      }
    }

    throw StateError(
      'Tidak ada mesin kompresi yang berhasil (${namaMesin.join(', ')}): '
      '$galatTerakhir',
    );
  }

  Future<HasilKompres> _jalankan(
    PemampatGambar mesin,
    FormatFoto format,
    _Siap siap,
    int asliByte,
    OpsiKompres opsi,
    Stopwatch jam,
  ) async {
    var citra = siap.citra;
    var iterasi = 0;
    var penyusutan = 0;

    while (true) {
      var kualitas = opsi.kualitasAwal;

      while (true) {
        final byte = await mesin.kodekan(citra, format, kualitas);
        iterasi++;

        final muat = byte.length + _cadanganPenanda <= opsi.targetByte;
        final bisaTurun = kualitas > opsi.kualitasMin;

        if (muat || (!bisaTurun && penyusutan >= opsi.maksPenyusutan)) {
          return _bungkus(
            byte,
            mesin,
            format,
            kualitas,
            iterasi,
            citra,
            siap,
            asliByte,
            opsi,
            jam,
          );
        }
        if (!bisaTurun) break;

        kualitas = math.max(opsi.kualitasMin, kualitas - opsi.langkahKualitas);
      }

      // Kualitas mentok di lantai dan masih besar: perkecil piksel.
      penyusutan++;
      final lama = citra;
      citra = await Isolate.run(() => _susutkan(lama));
    }
  }

  HasilKompres _bungkus(
    Uint8List byte,
    PemampatGambar mesin,
    FormatFoto format,
    int kualitas,
    int iterasi,
    CitraSiap citra,
    _Siap siap,
    int asliByte,
    OpsiKompres opsi,
    Stopwatch jam,
  ) {
    final salinan = SalinanArsip.dari(
      byte,
      mime: format.mime,
      ekstensi: format.ekstensi,
    );

    return HasilKompres(
      salinan: salinan,
      metrik: MetrikKompres(
        asliByte: asliByte,
        akhirByte: salinan.byte.length,
        lebarAsli: siap.lebarAsli,
        tinggiAsli: siap.tinggiAsli,
        lebarAkhir: citra.lebar,
        tinggiAkhir: citra.tinggi,
        format: format,
        kualitas: kualitas,
        mesin: mesin.nama,
        iterasi: iterasi,
        capaiTarget: salinan.byte.length <= opsi.targetByte,
        durasi: jam.elapsed,
        dilewati: false,
        diprosesPada: _jam(),
      ),
    );
  }
}

class _Siap {
  const _Siap({
    required this.citra,
    required this.lebarAsli,
    required this.tinggiAsli,
    required this.lebar,
    required this.tinggi,
    required this.formatSumberDikenal,
    required this.mimeSumber,
    required this.ekstensiSumber,
  });

  final CitraSiap citra;
  final int lebarAsli;
  final int tinggiAsli;
  final int lebar;
  final int tinggi;
  final bool formatSumberDikenal;
  final String mimeSumber;
  final String ekstensiSumber;
}

/// Jalan di isolate: decode, putar tegak, perkecil, kemas PNG.
_Siap _siapkan(Uint8List sumber, OpsiKompres opsi) {
  final decoder = img.findDecoderForData(sumber);
  final gambar = decoder?.decode(sumber);
  if (decoder == null || gambar == null) {
    throw const FormatException('Berkas bukan gambar yang dapat dibaca');
  }

  final tegak = img.bakeOrientation(gambar);
  final ukuran = opsi.ukuranAkhir(tegak.width, tegak.height);
  final akhir = ukuran.lebar == tegak.width && ukuran.tinggi == tegak.height
      ? tegak
      : img.copyResize(
          tegak,
          width: ukuran.lebar,
          height: ukuran.tinggi,
          interpolation: img.Interpolation.average,
        );

  final (mime, ekstensi, dikenal) = switch (decoder) {
    img.JpegDecoder() => ('image/jpeg', 'jpg', true),
    img.PngDecoder() => ('image/png', 'png', true),
    img.WebPDecoder() => ('image/webp', 'webp', true),
    _ => ('application/octet-stream', 'bin', false),
  };

  return _Siap(
    citra: CitraSiap(
      lebar: akhir.width,
      tinggi: akhir.height,
      png: Uint8List.fromList(img.encodePng(akhir, level: 1)),
    ),
    // Ukuran SESUDAH diputar tegak: itulah yang dilihat orang dan yang
    // dibandingkan dengan batas.
    lebarAsli: tegak.width,
    tinggiAsli: tegak.height,
    lebar: akhir.width,
    tinggi: akhir.height,
    formatSumberDikenal: dikenal,
    mimeSumber: mime,
    ekstensiSumber: ekstensi,
  );
}

CitraSiap _susutkan(CitraSiap lama) {
  final gambar = img.decodePng(lama.png);
  if (gambar == null) throw const FormatException('PNG sementara rusak');

  final lebar = math.max(1, (lama.lebar * 0.85).floor());
  final tinggi = math.max(1, (lama.tinggi * 0.85).floor());
  final kecil = img.copyResize(
    gambar,
    width: lebar,
    height: tinggi,
    interpolation: img.Interpolation.average,
  );

  return CitraSiap(
    lebar: lebar,
    tinggi: tinggi,
    png: Uint8List.fromList(img.encodePng(kecil, level: 1)),
  );
}
