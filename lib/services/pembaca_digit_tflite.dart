import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import '../providers/sakelar_ocr_provider.dart' show SakelarOcr;
import 'segmentasi_karakter.dart' show KarakterSel, sisiMnist;

/// Pengenal KARAKTER tunggal 28×28 (keluaran [KarakterSel]) dari model TFLite
/// sendiri — on-device, tanpa jaringan.
///
/// ## Gerbang (semua harus lolos, kalau tidak: tidak ada pembaca)
///
/// 1. sakelar `pakaiModelDigit` MENYALA (bawaan mati);
/// 2. `meta.json` sah dan kelasnya sama dengan [kelasDiharapkan];
/// 3. sha256 berkas model = `meta.json.sha256` (berkas tertukar/rusak ditolak);
/// 4. `asal_data` = `asli`. Model `publik` (MNIST + tanda baca sintetis) atau
///    `sintetis` DITOLAK untuk mengisi sel: akurasinya di set uji publik bukan
///    ramalan untuk tulisan teknisi, dan angka tebakan yang kelihatan wajar
///    lebih berbahaya daripada sel kosong.
///
/// Lolos gerbang pun belum berarti boleh mengisi lembar: hasilnya hanya
/// USULAN dan wajib melewati mode bayangan + pengukuran per lembar dulu
/// (tools/ocr-digit/README.md). Kelas ini tidak dipanggil alur pindai mana pun.
class PembacaDigitTflite {
  PembacaDigitTflite._(this.meta, this._interpreter);

  final MetaModelDigit meta;
  final InterpreterDigit _interpreter;

  /// Urutan kelas yang dipahami aplikasi — sama dengan
  /// `tools/ocr-digit/data_karakter.py` `KELAS`.
  static const kelasDiharapkan = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', //
    ',', '.', '-', 'coretan',
  ];

  /// Periksa gerbang lalu buat pembaca. [buatInterpreter] = pabrik interpreter
  /// (bawaan: tflite_flutter, lihat `interpreter_tflite.dart`); disuntik di test.
  static HasilSiapkan siapkan({
    required SakelarOcr sakelar,
    required Uint8List model,
    required String metaJson,
    required InterpreterDigit Function(Uint8List model) buatInterpreter,
  }) {
    if (!sakelar.pakaiModelDigit) {
      return const (pembaca: null, ditolak: PenolakanModel.sakelarMati);
    }

    final meta = MetaModelDigit.dari(metaJson);
    if (meta == null) {
      return const (pembaca: null, ditolak: PenolakanModel.metaTidakSah);
    }

    if (!_samaUrutan(meta.kelas, kelasDiharapkan)) {
      return const (pembaca: null, ditolak: PenolakanModel.kelasTidakCocok);
    }

    if (sha256.convert(model).toString() != meta.sha256.toLowerCase()) {
      return const (pembaca: null, ditolak: PenolakanModel.sha256TidakCocok);
    }

    if (meta.asalData != 'asli') {
      return (
        pembaca: null,
        ditolak: meta.asalData == 'publik' || meta.asalData == 'sintetis'
            ? PenolakanModel.asalDataBukanAsli
            : PenolakanModel.asalDataTakDikenal,
      );
    }

    // Runtime LiteRT bisa gagal dimuat di HP tertentu (pustaka native tidak
    // terbaca, RAM habis waktu memetakan model). Itu bukan alasan aplikasinya
    // tumbang: pembaca model cuma pelengkap, jadi jatuh ke "tanpa model" dan
    // sel tetap diisi manusia/ML Kit.
    final InterpreterDigit interpreter;
    try {
      interpreter = buatInterpreter(model);
    } catch (_) {
      return const (pembaca: null, ditolak: PenolakanModel.runtimeGagalDimuat);
    }

    return (pembaca: PembacaDigitTflite._(meta, interpreter), ditolak: null);
  }

  /// Muat `meta.json` + berkas model dari [folder] (mis. folder dukungan app;
  /// model TIDAK dibundel di APK) lalu [siapkan].
  static Future<HasilSiapkan> dariFolder(
    Directory folder, {
    required SakelarOcr sakelar,
    required InterpreterDigit Function(Uint8List model) buatInterpreter,
  }) async {
    if (!sakelar.pakaiModelDigit) {
      return const (pembaca: null, ditolak: PenolakanModel.sakelarMati);
    }

    final berkasMeta = File('${folder.path}/meta.json');
    if (!await berkasMeta.exists()) {
      return const (pembaca: null, ditolak: PenolakanModel.metaTidakSah);
    }
    final metaJson = await berkasMeta.readAsString();
    final meta = MetaModelDigit.dari(metaJson);
    if (meta == null ||
        meta.berkas.contains('/') ||
        meta.berkas.contains(r'\')) {
      return const (pembaca: null, ditolak: PenolakanModel.metaTidakSah);
    }

    final berkasModel = File('${folder.path}/${meta.berkas}');
    if (!await berkasModel.exists()) {
      return const (pembaca: null, ditolak: PenolakanModel.metaTidakSah);
    }

    return siapkan(
      sakelar: sakelar,
      model: await berkasModel.readAsBytes(),
      metaJson: metaJson,
      buatInterpreter: buatInterpreter,
    );
  }

  /// Klasifikasi tiap karakter. Hanya USULAN: kelas teratas + peluangnya,
  /// tidak pernah dipakai mengisi sel oleh kelas ini.
  List<({String kelas, double peluang})> klasifikasi(List<KarakterSel> kar) {
    final keluar = <({String kelas, double peluang})>[];

    for (final k in kar) {
      final masukan = Float32List(sisiMnist * sisiMnist);
      for (var i = 0; i < masukan.length; i++) {
        masukan[i] = k.piksel[i] / 255.0;
      }

      final p = _interpreter.jalankan(masukan);
      if (p.length != kelasDiharapkan.length) {
        throw StateError('keluaran model ${p.length} kelas');
      }

      var terbaik = 0;
      for (var i = 1; i < p.length; i++) {
        if (p[i] > p[terbaik]) terbaik = i;
      }
      keluar.add((kelas: kelasDiharapkan[terbaik], peluang: p[terbaik]));
    }

    return keluar;
  }

  void tutup() => _interpreter.tutup();

  static bool _samaUrutan(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

typedef HasilSiapkan = ({PembacaDigitTflite? pembaca, PenolakanModel? ditolak});

enum PenolakanModel {
  sakelarMati,
  metaTidakSah,
  kelasTidakCocok,
  sha256TidakCocok,

  /// `asal_data` = `publik`/`sintetis` — model latihan data orang lain.
  asalDataBukanAsli,
  asalDataTakDikenal,

  /// Runtime LiteRT/interpreter gagal dibuat di HP ini (pustaka native tak
  /// termuat, memori kurang). Model dilewati, aplikasi jalan terus.
  runtimeGagalDimuat,
}

/// Seam interpreter: satu masukan 28×28 float (0..1) → peluang per kelas.
abstract class InterpreterDigit {
  List<double> jalankan(Float32List masukan784);

  void tutup();
}

/// Isi `meta.json` keluaran `tools/ocr-digit/latih_karakter.py`.
class MetaModelDigit {
  const MetaModelDigit({
    required this.versi,
    required this.berkas,
    required this.sha256,
    required this.asalData,
    required this.kelas,
  });

  final String versi;
  final String berkas;
  final String sha256;
  final String asalData;
  final List<String> kelas;

  static MetaModelDigit? dari(String json) {
    try {
      final j = jsonDecode(json);
      if (j is! Map<String, dynamic>) return null;
      final kelas = j['kelas'];
      final versi = j['versi'], berkas = j['berkas'];
      final sha = j['sha256'], asal = j['asal_data'];
      if (versi is! String ||
          berkas is! String ||
          sha is! String ||
          asal is! String ||
          kelas is! List ||
          !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha)) {
        return null;
      }
      return MetaModelDigit(
        versi: versi,
        berkas: berkas,
        sha256: sha,
        asalData: asal,
        kelas: [for (final k in kelas) '$k'],
      );
    } on FormatException {
      return null;
    }
  }
}
