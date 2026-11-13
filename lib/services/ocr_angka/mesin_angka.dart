import 'package:image/image.dart' as img;

import 'aturan_format_sel.dart';
import 'dekoder_ctc.dart';
import 'keputusan_sel.dart';
import 'meta_model.dart';
import 'pagar_tinta.dart';
import 'pemotong_sel.dart';
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

  /// Baca satu hasil [PemotongSel].
  ///
  ///  - tak ada tulisan milik baris ([HasilPotongSel.crop] `null`): `kosong`;
  ///  - kotak terlalu kecil untuk dipotong: `perluCek` (tak bisa dinilai);
  ///  - ADA crop tetapi pagar tinta menolaknya: `perluCek`
  ///    ([AlasanSelAngka.tintaPudar]), BUKAN `kosong`. Pemotong memakai ambang
  ///    tinta 0,78 sedangkan pagar `gelap` memakai 0,70, jadi tinta pudar
  ///    (rasio tinta/kertas 0,70–0,78) lolos pemotong dan jatuh di pagar; dulu
  ///    sel itu hilang diam-diam. Hanya sel yang pemotongnya TIDAK menemukan
  ///    apa pun yang tetap kosong;
  ///  - pemotong tidak yakin: `perluCek` tanpa menjalankan model;
  ///  - selebihnya sama dengan [baca] pada crop hasil potongan.
  Future<HasilSelAngka> bacaPotongan(
    HasilPotongSel potongan,
    AturanFormatSel aturan, {
    double? ambang,
  }) async {
    const takYakin = HasilSelAngka(
      status: StatusSelAngka.perluCek,
      bacaanMentah: '',
      jalur: 0,
      alasan: AlasanSelAngka.pemotongTakYakin,
    );

    final crop = potongan.crop;
    if (crop == null) {
      // Tak ada crop: sel kosong, kecuali kotaknya terlalu kecil untuk dipotong
      // (tak bisa dinilai kosong atau berisi).
      return potongan.takYakin
          ? takYakin
          : const HasilSelAngka.kosong(AlasanSelAngka.tintaKosong);
    }

    if (!PraprosesSel.ukuranWajar(crop.width, crop.height)) {
      return const HasilSelAngka.kosong(AlasanSelAngka.ukuranTakWajar);
    }

    // Pemotong melihat tulisan, pagar tidak: tinta pudar. Teknisi memutuskan.
    if (!PagarTinta.adaTinta(PagarTinta.ukur(crop))) {
      return const HasilSelAngka(
        status: StatusSelAngka.perluCek,
        bacaanMentah: '',
        jalur: 0,
        alasan: AlasanSelAngka.tintaPudar,
      );
    }

    if (potongan.takYakin) return takYakin;

    return _bacaBertinta(crop, aturan, ambang);
  }

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

    return _bacaBertinta(potongan, aturan, ambang);
  }

  /// Crop yang sudah lolos [PraprosesSel.ukuranWajar] dan pagar tinta.
  Future<HasilSelAngka> _bacaBertinta(
    img.Image potongan,
    AturanFormatSel aturan,
    double? ambang,
  ) async {
    // Model berlebar tetap (TFLite 320): sel yang lebih lebar harus ditekan
    // aspeknya, dan bacaan hasil tekanan tidak pernah diukur. Ditahan, tidak
    // dijalankan. Setelah pagar tinta: sel lebar yang kosong tetap `tintaKosong`.
    // Jaring terakhir: `PemotongSel` memangkas crop ke kotak tinta sehingga
    // sel yang melewati pagar ini seharusnya jarang.
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
      // Sudah lolos pagar tinta: model yang diam di sini bukan sel kosong.
      bertinta: true,
    );
  }

  Future<void> tutup() => _sesi.tutup();
}
