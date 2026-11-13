import 'dart:io';

import 'package:image/image.dart' as img;

import '../pembaca_sel.dart';
import '../pembaca_sel_onnx.dart';
import 'ukur_ocr.dart';

/// Hasil bacaan satu crop untuk pengukuran.
typedef BacaanUkur = ({
  String teks,
  double? keyakinan,
  bool dijawab,
  String status,
});

/// Membaca satu crop: ML Kit atau mesin angka.
typedef PembacaUkur =
    Future<BacaanUkur> Function(img.Image crop, LabelUkur label);

final _bukanAlfabet = RegExp(r'[^0-9.,\-]');

/// ML Kit pada crop yang sama dengan mesin angka. Teks disaring ke `0-9 . , -`
/// seperti `muat_foto_nyata.py`; ML Kit tidak memberi skor (`keyakinan` null),
/// dan "menjawab" berarti ada teks tersisa.
PembacaUkur pembacaUkurMlKit(PembacaSel pembaca) => (crop, label) async {
  final b = await pembaca.baca(crop);
  final teks = (b.teks ?? '').replaceAll(_bukanAlfabet, '');

  return (
    teks: teks,
    keyakinan: null,
    dijawab: teks.isNotEmpty,
    status: teks.isEmpty ? 'kosong' : 'terbaca',
  );
};

/// Mesin angka (`PembacaSelOnnx`) pada crop yang sama. Melempar
/// [StateError] bila mesin tidak aktif (tanpa runtime/model): pengukuran
/// berhenti dengan pesan, bukan diam-diam jatuh ke ML Kit.
PembacaUkur pembacaUkurMesinAngka(
  PembacaSelOnnx pembaca, {
  double? ambang,
  int desimalSelKosong = 2,
  bool bertandaSelKosong = false,
}) => (crop, label) async {
  final aturan = label.aturan(
    desimalSelKosong: desimalSelKosong,
    bertandaSelKosong: bertandaSelKosong,
  );
  if (aturan == null) {
    return (teks: '', keyakinan: null, dijawab: false, status: 'tanpa-aturan');
  }

  final h = await pembaca.bacaLengkap(crop, aturan, ambang: ambang);
  if (h == null) {
    throw StateError(
      'Mesin angka tidak aktif: sakelar mati (bangun dengan '
      '--dart-define=PAKAI_MESIN_ANGKA=true) atau runtime/model tidak valid di '
      'perangkat.',
    );
  }

  return (
    teks: h.bacaanMentah,
    keyakinan: h.bacaanMentah.isEmpty ? null : h.jalur,
    dijawab: h.usulan != null,
    status: h.status.name,
  );
};

/// Jalankan [baca] pada tiap crop di [folder] (nama berkas dari `labels.csv`),
/// berurutan, dan ukur waktunya per sel (decode TIDAK dihitung). Satu sel
/// galat tidak menghentikan yang lain: status `galat`, tidak dijawab —
/// kecuali [StateError] (mesin tidak aktif), yang menghentikan semuanya.
///
/// Tidak ada yang dikirim keluar perangkat: crop dibaca dari folder lokal dan
/// hasilnya ditulis oleh pemanggil ke folder yang sama.
Future<List<HasilUkurSel>> jalankanUkurFolder({
  required Directory folder,
  required List<LabelUkur> labels,
  required PembacaUkur baca,
  int? batas,
  void Function(int selesai, int total)? progres,
  bool Function()? dibatalkan,
}) async {
  final daftar = batas == null ? labels : labels.take(batas).toList();
  final hasil = <HasilUkurSel>[];

  for (final (i, label) in daftar.indexed) {
    if (dibatalkan?.call() ?? false) break;

    final berkas = File('${folder.path}/${label.file}');
    img.Image? crop;
    try {
      crop = img.decodeImage(await berkas.readAsBytes());
    } catch (_) {
      crop = null;
    }

    if (crop == null) {
      hasil.add(
        HasilUkurSel(
          label: label,
          teks: '',
          keyakinan: null,
          dijawab: false,
          status: 'galat-baca-berkas',
          milidetik: 0,
        ),
      );
    } else {
      final jam = Stopwatch()..start();
      try {
        final b = await baca(crop, label);
        jam.stop();
        hasil.add(
          HasilUkurSel(
            label: label,
            teks: b.teks,
            keyakinan: b.keyakinan,
            dijawab: b.dijawab,
            status: b.status,
            milidetik: jam.elapsedMicroseconds / 1000,
          ),
        );
      } on StateError {
        rethrow;
      } catch (_) {
        jam.stop();
        hasil.add(
          HasilUkurSel(
            label: label,
            teks: '',
            keyakinan: null,
            dijawab: false,
            status: 'galat',
            milidetik: jam.elapsedMicroseconds / 1000,
          ),
        );
      }
    }

    progres?.call(i + 1, daftar.length);
  }

  return hasil;
}
