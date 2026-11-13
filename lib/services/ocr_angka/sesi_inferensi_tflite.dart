import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'interpreter_mentah_tflite.dart';
import 'pelari_tflite.dart';
import 'praproses_sel.dart';
import 'sesi_inferensi.dart';

/// [SesiInferensiCtc] di atas model TFLite `rec_en_f32.tflite` (PP-OCRv5 en,
/// hasil konversi `onnx2tf` dari ONNX asli; rig `sidik-ocr-eval`, 13 Nov 2026),
/// dijalankan oleh `tflite_flutter` 0.12.1 / LiteRT 1.4.0 yang SUDAH ada di APK.
///
/// ## Kontrak model
///
///  - masukan `x` `[1,48,320,3]` float32, NHWC, urutan kanal BGR, sudah
///    dinormalisasi `(p/255 - 0,5)/0,5`, sisa kanan kanvas = 0 SETELAH normalisasi;
///  - keluaran `[1,40,438]` float32 = PELUANG softmax per frame (bukan logit;
///    jumlah per frame = 1). `DekoderCtc.ambilKolom` mengenali ini dan tidak
///    men-softmax ulang.
///
/// `PraprosesSel` menghasilkan CHW `[1,3,48,lebar]`; [chwKeNhwc] menata ulang
/// tanpa mengubah nilai. Lebar kanvas model TETAP [lebarTetap] = 320: sel yang
/// hasil resize-nya lebih lebar ditahan `MesinAngka` ([SesiLebarTetap]) sebelum
/// sampai ke sini; ONNX berlebar dinamis mempertahankan aspek, TFLite akan
/// menekannya.
///
/// ## Siklus hidup
///
///  - model dimuat MALAS dan SATU kali, pada [siapkan] / [jalankan] pertama;
///    panggilan bersamaan berbagi satu pemuatan;
///  - kontrak tensor diperiksa sesudah dimuat (bentuk, tipe, ukuran keluaran);
///    tidak cocok = galat, pembaca jatuh ke ML Kit;
///  - [tutup] melepas interpreter dan isolate pekerja; aman dipanggil berulang.
///
/// Semua yang bergantung pada runtime native ada di [PelariTflite]; kelas ini
/// murni Dart dan diuji dengan pelari tiruan.
class SesiInferensiTflite implements SesiInferensiCtc, SesiLebarTetap {
  SesiInferensiTflite({required Future<PelariTflite> Function() muatPelari})
    : _muatPelari = muatPelari;

  /// Pabrik sesi bawaan untuk `muatMesinAngka` / `BuatSesiCtc`: memuat model
  /// SEKARANG (di isolate pekerja) supaya kegagalan runtime/model muncul sebagai
  /// `PenolakanMesin.runtimeGagalDimuat`, bukan di tengah lembar.
  ///
  /// [model] sudah lolos pemeriksaan sha256 oleh pemanggil (`muatMesinAngka`);
  /// karena itu dimuat dari byte (`Interpreter.fromBuffer`), bukan dari aset.
  static Future<SesiInferensiTflite> dariByte(
    Uint8List model, {
    int? thread,
    PabrikInterpreterMentah pabrik = InterpreterMentahTflite.buat,
  }) async {
    final sesi = SesiInferensiTflite(
      muatPelari: () => PelariTfliteIsolate.mulai(
        model,
        pabrik: pabrik,
        thread: thread ?? threadBawaan(),
      ),
    );

    try {
      await sesi.siapkan();
    } catch (_) {
      await sesi.tutup();
      rethrow;
    }

    return sesi;
  }

  static const tinggi = PraprosesSel.tinggi;
  static const kanal = 3;
  static const lebarKanvas = PraprosesSel.lebarMin;
  static const frame = 40;
  static const kelas = 438;

  /// Thread CPU: setengah inti, 2..4. Hemat baterai/panas di HP murah; angka
  /// final ditentukan dari ukuran di tablet, bukan dari tebakan ini.
  static int threadBawaan() =>
      math.min(4, math.max(2, Platform.numberOfProcessors ~/ 2));

  /// Dilepas begitu pemuatan dimulai: penutupnya memegang byte model (7,8 MB di
  /// heap Dart) dan tidak boleh hidup sepanjang sesi.
  Future<PelariTflite> Function()? _muatPelari;

  Future<PelariTflite>? _pelari;
  PelariTflite? _pelariSiap;
  bool _ditutup = false;

  @override
  int get lebarTetap => lebarKanvas;

  /// Pekerja model sudah mati tanpa diminta: sesi ini tidak akan menjawab lagi.
  /// `false` selama model belum selesai dimuat.
  bool get mati => _pelariSiap?.mati ?? false;

  /// Muat model bila belum (idempoten, aman paralel) dan periksa kontraknya.
  /// Melempar bila gagal; kegagalan diingat, tidak dicoba ulang.
  Future<void> siapkan() async {
    if (_ditutup) throw StateError('sesi TFLite sudah ditutup');
    await (_pelari ??= _muat());
  }

  Future<PelariTflite> _muat() async {
    final muat = _muatPelari!;
    _muatPelari = null;
    final pelari = await muat();
    try {
      periksaKontrak(pelari.kontrak);
    } catch (_) {
      await pelari.tutup();
      rethrow;
    }

    _pelariSiap = pelari;
    return pelari;
  }

  /// Bentuk dan tipe tensor harus PERSIS yang diukur di rig. Model lain (mis.
  /// berlebar dinamis, INT8, keluaran logit) menghasilkan angka berbeda tanpa
  /// galat bila dibiarkan lolos.
  static void periksaKontrak(KontrakTensor k) {
    const masuk = [1, tinggi, lebarKanvas, kanal];
    const keluar = [1, frame, kelas];

    if (!_sama(k.bentukMasukan, masuk) || k.tipeMasukan != 'float32') {
      throw StateError(
        'masukan model ${k.bentukMasukan} ${k.tipeMasukan}, '
        'seharusnya $masuk float32',
      );
    }
    if (!_sama(k.bentukKeluaran, keluar) || k.tipeKeluaran != 'float32') {
      throw StateError(
        'keluaran model ${k.bentukKeluaran} ${k.tipeKeluaran}, '
        'seharusnya $keluar float32',
      );
    }
  }

  static bool _sama(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) async {
    if (_ditutup) throw StateError('sesi TFLite sudah ditutup');
    if (lebar != lebarKanvas) {
      // Bukan keadaan normal: MesinAngka menahan sel yang lebih lebar, dan
      // PraprosesSel memberi tepat 320 untuk sisanya.
      throw ArgumentError.value(
        lebar,
        'lebar',
        'model TFLite hanya menerima lebar $lebarKanvas',
      );
    }
    if (masukan.length != kanal * tinggi * lebar) {
      throw ArgumentError.value(
        masukan.length,
        'masukan',
        'panjang tensor harus ${kanal * tinggi * lebar}',
      );
    }

    final pelari = await (_pelari ??= _muat());
    final keluar = await pelari.jalankan(chwKeNhwc(masukan));
    if (keluar.length != frame * kelas) {
      throw StateError(
        'keluaran ${keluar.length} nilai, seharusnya ${frame * kelas}',
      );
    }

    return KeluaranCtc(
      nilai: keluar,
      frame: frame,
      kelas: kelas,
      sudahPeluang: true,
    );
  }

  /// `[3][48][320]` (CHW, keluaran `PraprosesSel`) → `[48][320][3]` (NHWC,
  /// masukan model). Hanya menata ulang: urutan kanal (B,G,R), nilai, dan nol
  /// di kanan kanvas tidak berubah.
  static Float32List chwKeNhwc(Float32List chw) {
    const bidang = tinggi * lebarKanvas;
    if (chw.length != kanal * bidang) {
      throw ArgumentError.value(chw.length, 'chw', 'harus ${kanal * bidang}');
    }

    final nhwc = Float32List(chw.length);
    for (var c = 0; c < kanal; c++) {
      final dasar = c * bidang;
      for (var i = 0; i < bidang; i++) {
        nhwc[i * kanal + c] = chw[dasar + i];
      }
    }

    return nhwc;
  }

  @override
  Future<void> tutup() async {
    if (_ditutup) return;
    _ditutup = true;

    final pelari = _pelari;
    if (pelari == null) return;

    try {
      await (await pelari).tutup();
    } catch (_) {
      // Pemuatan yang gagal sudah menutup dirinya sendiri; gagal menutup tidak
      // boleh menimpa penyebab aslinya.
    }
  }
}

/// Pabrik sesi yang memuat model SEKALI untuk seluruh umur pemiliknya (provider
/// aplikasi), bukan sekali per foto.
///
/// Alur pindai membuat `PembacaSelOnnx` baru untuk TIAP foto dan menutupnya di
/// akhir. Tanpa pabrik ini tiap foto memuat ulang model (spawn isolate, urai
/// flatbuffer) DAN membocorkan ±7,8 MB memori native: `Interpreter.fromBuffer`
/// (tflite_flutter 0.12.1) menyalin model ke heap native dengan `calloc` yang
/// tidak pernah dibebaskan, juga oleh `close()`. Di sini bocornya sekali per
/// proses (dua kali bila pekerja mati dan dimuat ulang).
///
/// ## Umur model
///
/// Sesi yang dikembalikan [buat] tidak menutup model saat `tutup()`; model
/// dilepas oleh [lepas] (saat provider dibuang). Sesudah pindai pertama model
/// (±20 MB memori: salinan native + bobot XNNPACK + isolate; perkiraan, tidak
/// diukur) tetap resident sampai proses berakhir.
///
/// ## Kegagalan diingat, dan jatah dibatasi
///
/// Tiap percobaan memuat yang GAGAL (runtime/model, pustaka native, kontrak
/// tensor) membocorkan ≥ 7,8 MB native, jadi tidak boleh diulang tiap foto:
///
///  - gagal memuat paling banyak [batasGagal] kali per proses; sesudahnya
///    [menyerah] `true` dan [buat] langsung melempar tanpa membuka isolate
///    (pemanggil `muatMesinAngka` yang diberi `menyerah` juga tidak lagi
///    membaca aset);
///  - pekerja yang MATI sesudah berhasil dimuat (sesi `mati`) dibuang dan
///    dimuat ulang paling banyak [batasMuatUlang] kali per proses; kematian
///    berikutnya membuat pabrik menyerah. Tidak ada loop.
///
/// Satu pabrik = satu model: pemuatan pertama yang berhasil dipakai ulang tanpa
/// memeriksa byte-nya lagi.
///
/// ## Yang TIDAK dihilangkan
///
/// Gerbang `muatMesinAngka` tetap berjalan tiap foto SEBELUM [buat]: membaca
/// aset 7,8 MB dan menghitung sha256-nya. Itu satu-satunya biaya per foto yang
/// tersisa (tidak diukur di perangkat). Menyimpan hasil verifikasinya berarti
/// membuat gerbang itu stateful di dua tempat; sengaja tidak dilakukan.
class PabrikSesiTfliteBersama {
  PabrikSesiTfliteBersama([
    Future<SesiInferensiTflite> Function(Uint8List model) pabrik =
        SesiInferensiTflite.dariByte,
  ]) : _pabrik = pabrik;

  /// Percobaan memuat yang gagal sebelum pabrik menyerah.
  static const batasGagal = 2;

  /// Muat ulang karena pekerja mati, per proses.
  static const batasMuatUlang = 1;

  final Future<SesiInferensiTflite> Function(Uint8List model) _pabrik;

  Future<SesiInferensiTflite>? _sesi;
  SesiInferensiTflite? _aktif;
  int _gagal = 0;
  int _muatUlang = 0;
  bool _menyerahMati = false;
  bool _dilepas = false;

  /// Sudah menyerah: pemuatan tidak akan dicoba lagi pada proses ini.
  bool get menyerah => _menyerahMati || _gagal >= batasGagal;

  /// Cocok sebagai `BuatSesiCtc`.
  Future<SesiInferensiCtc> buat(Uint8List model) async {
    if (_dilepas) throw StateError('pabrik sesi TFLite sudah dilepas');

    var sesi = await _ambil(model);
    if (sesi.mati) {
      // Hanya pemanggil pertama yang melihat kematiannya membuang dan
      // menghitung jatah; yang lain ikut sesi hasil muat ulang itu.
      if (identical(_aktif, sesi)) {
        _aktif = null;
        _sesi = null;
        // Jatah dihitung SEBELUM menunggu apa pun: pemanggil lain yang masuk
        // selagi sesi mati ditutup tidak boleh memulai muat ulang kedua.
        final habis = _muatUlang >= batasMuatUlang;
        if (habis) {
          _menyerahMati = true;
        } else {
          _muatUlang++;
        }
        await sesi.tutup();
        if (habis) {
          throw StateError('pekerja TFLite mati dan jatah muat ulang habis');
        }
      }

      sesi = await _ambil(model);
      if (sesi.mati) {
        throw StateError('pekerja TFLite mati lagi sesudah dimuat ulang');
      }
    }

    return _SesiBersama(sesi);
  }

  Future<SesiInferensiTflite> _ambil(Uint8List model) async {
    var muat = _sesi;
    if (muat == null) {
      if (menyerah) {
        throw StateError(
          'mesin angka TFLite menyerah pada proses ini (gagal dimuat '
          '$_gagal kali atau pekerja mati lagi)',
        );
      }
      muat = _sesi = _muat(model);
    }

    try {
      return await muat;
    } catch (_) {
      if (identical(_sesi, muat)) _sesi = null;
      rethrow;
    }
  }

  Future<SesiInferensiTflite> _muat(Uint8List model) async {
    final SesiInferensiTflite sesi;
    try {
      sesi = await _pabrik(model);
    } catch (_) {
      _gagal++;
      rethrow;
    }

    if (_dilepas) {
      await sesi.tutup();
      throw StateError('pabrik sesi TFLite sudah dilepas');
    }
    _aktif = sesi;

    return sesi;
  }

  /// Tutup model sungguhan. Aman diulang; sesudahnya [buat] menolak.
  Future<void> lepas() async {
    _dilepas = true;
    final muat = _sesi;
    _sesi = null;
    _aktif = null;
    if (muat == null) return;

    try {
      await (await muat).tutup();
    } catch (_) {
      // Pemuatan yang gagal sudah menutup dirinya sendiri.
    }
  }
}

/// Pembungkus yang `tutup()`-nya tidak menutup model bersama.
class _SesiBersama implements SesiInferensiCtc, SesiLebarTetap {
  _SesiBersama(this._sesi);

  final SesiInferensiTflite _sesi;

  @override
  int get lebarTetap => _sesi.lebarTetap;

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) =>
      _sesi.jalankan(masukan, lebar);

  @override
  Future<void> tutup() async {}
}
