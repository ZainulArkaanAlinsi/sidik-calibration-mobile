import 'package:image/image.dart' as img;

import 'aturan_format_sel.dart';
import 'dekoder_ctc.dart';
import 'keputusan_sel.dart';
import 'meta_model.dart';
import 'pagar_tinta.dart';
import 'praproses_sel.dart';
import 'sesi_inferensi.dart';

/// Satu sel angka: pagar tinta → praproses → model → dekode CTC → gerbang
/// format + ambang. Murni Dart di atas [SesiInferensiCtc]; bisa diuji tanpa
/// runtime native memakai sesi palsu.
///
/// Foto tidak pernah keluar perangkat: seluruh langkah jalan di memori proses
/// ini. Hasilnya hanya USULAN ([HasilSelAngka.usulan]); sel kosong tetap kosong.
class MesinAngka {
  MesinAngka({required SesiInferensiCtc sesi, required this.meta})
    : _sesi = sesi;

  final SesiInferensiCtc _sesi;
  final MetaModelOcr meta;

  /// Baca satu crop sel. [ambang] menimpa ambang di meta (layar diagnostik).
  Future<HasilSelAngka> baca(
    img.Image potongan,
    AturanFormatSel aturan, {
    double? ambang,
  }) async {
    if (!PraprosesSel.ukuranWajar(potongan.width, potongan.height)) {
      return const HasilSelAngka.kosong(AlasanSelAngka.ukuranTakWajar);
    }

    if (!PagarTinta.adaTinta(PagarTinta.ukur(potongan))) {
      return const HasilSelAngka.kosong(AlasanSelAngka.tintaKosong);
    }

    // Model berlebar tetap (TFLite 320): sel yang lebih lebar harus ditekan
    // aspeknya, dan bacaan hasil tekanan tidak pernah diukur. Ditahan, tidak
    // dijalankan. Setelah pagar tinta: sel lebar yang kosong tetap `tintaKosong`.
    if (_sesi case SesiLebarTetap(lebarTetap: final batas)
        when PraprosesSel.lebarHasilResize(potongan.width, potongan.height) >
            batas) {
      return const HasilSelAngka.kosong(AlasanSelAngka.ukuranTakWajar);
    }

    final tensor = PraprosesSel.proses(potongan);
    final keluar = await _sesi.jalankan(tensor.data, tensor.lebar);
    final mentah = DekoderCtc.ambilKolom(
      keluar.nilai,
      keluar.frame,
      keluar.kelas,
      meta.kolom,
      sudahPeluang: keluar.sudahPeluang,
    );

    return putuskanSelAngka(
      dekode: DekoderCtc.dekode(mentah, keluar.frame),
      aturan: aturan,
      ambang: ambang ?? meta.ambangJalur,
    );
  }

  Future<void> tutup() => _sesi.tutup();
}
