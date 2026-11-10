import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'detektor_layout.dart';
import 'model_layout.dart';

/// Satu wilayah mentah — hanya tipe primitif, supaya aman dikirim antar
/// isolate.
typedef WilayahMentah = ({
  String kelas,
  double skor,
  double x1,
  double y1,
  double x2,
  double y2,
});

typedef LayoutMentah = ({
  List<WilayahMentah> wilayah,
  int lebar,
  int tinggi,
  int durasiMs,
});

/// Permukaan `OcrKit` yang dipakai aplikasi. Antarmuka ini ada supaya urutan
/// init -> deteksi -> `releaseLayout()` bisa diuji dengan tiruan tanpa
/// perpustakaan native; adaptor nyatanya (`PermukaanOcrKitAsli`) tipis dan
/// hanya mendelegasikan.
abstract interface class PermukaanOcrKit {
  void init(String modelPath);

  /// Melempar bila native melaporkan galat.
  LayoutMentah detectLayout(String imagePath, {double confThreshold});

  void releaseLayout();
}

/// Satu deteksi, sinkron: init, deteksi, lalu `releaseLayout()` di `finally`
/// — baik deteksi berhasil maupun melempar. Model ONNX + OpenCV memakai
/// ratusan MB native; yang tidak dilepas tertahan sampai proses mati.
LayoutMentah deteksiLayoutSinkron(
  PermukaanOcrKit kit, {
  required String modelPath,
  required String imagePath,
  double ambang = 0.5,
}) {
  try {
    kit.init(modelPath);

    return kit.detectLayout(imagePath, confThreshold: ambang);
  } finally {
    kit.releaseLayout();
  }
}

/// Menjalankan [deteksiLayoutSinkron] di luar isolate UI.
abstract interface class MesinLayout {
  Future<LayoutMentah> deteksi({
    required String modelPath,
    required String imagePath,
    double ambang,
  });
}

/// Mesin nyata: `Isolate.run` + adaptor `OcrKit`. [bikinPermukaan] dipanggil
/// DI DALAM isolate (tiap isolate punya statik `OcrKit` sendiri).
class MesinLayoutIsolate implements MesinLayout {
  const MesinLayoutIsolate(this._bikinPermukaan);

  final PermukaanOcrKit Function() _bikinPermukaan;

  @override
  Future<LayoutMentah> deteksi({
    required String modelPath,
    required String imagePath,
    double ambang = 0.5,
  }) {
    final bikin = _bikinPermukaan;

    return Isolate.run(
      () => deteksiLayoutSinkron(
        bikin(),
        modelPath: modelPath,
        imagePath: imagePath,
        ambang: ambang,
      ),
    );
  }
}

/// Detektor tata letak berbasis `flutter_ocr_kit` (ONNX PP-DocLayout-L),
/// Android saja. Foto ditulis sementara ke direktori cache aplikasi, dibaca
/// native, lalu dihapus — tidak ada jaringan di jalur ini (unduhan MODEL
/// adalah satu-satunya akses jaringan, dan tanpa foto).
class DetektorLayoutOcrKit implements DetektorLayout {
  DetektorLayoutOcrKit({
    required PengelolaModelLayout model,
    required MesinLayout mesin,
    required Future<Directory> Function() direktoriSementara,
    required bool platformDidukung,
    this.ambang = 0.5,
  }) : _model = model,
       _mesin = mesin,
       _tmp = direktoriSementara,
       _didukung = platformDidukung;

  final PengelolaModelLayout _model;
  final MesinLayout _mesin;
  final Future<Directory> Function() _tmp;
  final bool _didukung;
  final double ambang;

  @override
  bool get tersedia => _didukung;

  @override
  Future<void> siapkan({
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) async {
    if (!_didukung) {
      throw const LayoutGagal(SebabLayoutGagal.platformTakDidukung);
    }
    await _model.pastikan(kemajuan: kemajuan, izinUnduh: izinUnduh);
  }

  @override
  Future<HasilLayout> deteksi(
    Uint8List jpeg, {
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) async {
    if (!_didukung) {
      throw const LayoutGagal(SebabLayoutGagal.platformTakDidukung);
    }

    final modelPath = await _model.pastikan(
      kemajuan: kemajuan,
      izinUnduh: izinUnduh,
    );

    kemajuan?.call(TahapLayout.mendeteksi, null);
    final dir = await _tmp();
    final berkas = File(
      '${dir.path}/layout_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    try {
      await berkas.writeAsBytes(jpeg, flush: true);
      final mentah = await _mesin.deteksi(
        modelPath: modelPath,
        imagePath: berkas.path,
        ambang: ambang,
      );

      return HasilLayout(
        lebar: mentah.lebar,
        tinggi: mentah.tinggi,
        durasiMs: mentah.durasiMs,
        wilayah: [
          for (final w in mentah.wilayah)
            WilayahLayout(
              kelas: w.kelas,
              skor: w.skor,
              kotak: Rect.fromLTRB(w.x1, w.y1, w.x2, w.y2),
            ),
        ],
      );
    } on LayoutGagal {
      rethrow;
    } catch (e) {
      throw LayoutGagal(SebabLayoutGagal.deteksiGagal, '$e');
    } finally {
      try {
        if (await berkas.exists()) await berkas.delete();
      } catch (_) {
        // Sisa berkas cache dibersihkan sistem; bukan alasan menggagalkan.
      }
    }
  }
}
