import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/worksheet_scan.dart';
import '../models/worksheet_template.dart';
import 'pembaca_sel.dart';
import 'pindai_lembar.dart';

/// Kenapa satu pindai berhenti sebelum sampai server.
///
/// Dibedakan supaya layar bisa bilang APA yang harus diperbaiki teknisi.
/// "Gagal memindai" tanpa sebab bikin orang mengulang jepretan yang sama
/// berkali-kali — dan tiga dari empat sebab di bawah nggak akan pernah membaik
/// dengan mengulang.
enum GagalPindai {
  /// Lembar ini belum boleh dipindai (`siap_pindai: false`). Bukan salah foto.
  belumSiap,

  /// Geometrinya belum diukur, jadi nggak ada kotak sel buat dipotong.
  tanpaGeometri,

  /// Empat penanda sudut nggak ketemu — biasanya lembar lama tanpa marker,
  /// fotonya kepotong, atau terlalu gelap.
  markerTidakKetemu,

  /// Penanda ketemu tapi nggak membentuk persegi yang wajar: fotonya terlalu
  /// juling, atau yang kefoto bukan lembar utuh.
  geometriMeleset,
}

class PindaiGagal implements Exception {
  const PindaiGagal(this.sebab);

  final GagalPindai sebab;

  @override
  String toString() => 'PindaiGagal(${sebab.name})';
}

/// Satu foto lembar kerja → hasil baca per sel di server.
///
/// ## Kenapa kelas sendiri
///
/// Potongannya sudah lengkap sejak lama — [PindaiLembar] meratakan foto,
/// [PembacaSel] membaca tiap potongan, [PayloadPindai] menyusun kiriman, dan
/// `PindaiReviewScreen` menampilkan hasilnya — tapi **nggak ada satu pun kode
/// yang menyambung keempatnya**. Tombol "Pindai lembar" di layar teknisi
/// terpasang dengan callback kosong (`() {}`), jadi jalur kamera belum pernah
/// jalan sekali pun.
///
/// Lemnya ditaruh di sini, bukan di layar, karena urutannya yang menentukan
/// benar-salahnya angka: potong pakai kotak dari TEMPLATE, baca per potongan,
/// kirim kunci apa adanya. Ditaruh di widget, urutan itu bakal disalin ulang
/// (dan diubah sedikit) tiap kali ada layar baru yang mau memindai.
class JalankanPindai {
  const JalankanPindai({
    required this.mesin,
    required this.pembaca,
    this.payload = const PayloadPindai(),
  });

  final PindaiLembar mesin;
  final PembacaSel pembaca;
  final PayloadPindai payload;

  /// Baca satu foto jadi payload `POST /api/worksheet-scans`.
  ///
  /// Nggak mengirim sendiri — yang mengirim pemanggilnya, supaya kelas ini
  /// bisa diuji tanpa jaringan.
  Future<Map<String, dynamic>> susun(
    img.Image foto, {
    required WorksheetTemplate template,
    int? calibrationSessionId,
    int? equipmentId,
    Map<String, String>? perangkat,
  }) async {
    if (!template.siapPindai) {
      throw const PindaiGagal(GagalPindai.belumSiap);
    }

    final ukuran = template.ukuranReferensi;

    if (ukuran == null || template.sel.isEmpty) {
      throw const PindaiGagal(GagalPindai.tanpaGeometri);
    }

    final marker = mesin.cariMarker(foto);

    if (marker == null) {
      throw const PindaiGagal(GagalPindai.markerTidakKetemu);
    }

    // Tujuan warp diambil dari template, bukan dari sudut halaman: yang
    // dipakai server buat memotong sel itu ruang template, dan markernya nggak
    // duduk persis di pojok kertas.
    final tujuan = <Sudut>[
      for (final m in template.marker) (x: m.x, y: m.y),
    ];

    if (tujuan.length != 4) {
      throw const PindaiGagal(GagalPindai.tanpaGeometri);
    }

    final warp = mesin.warp(
      foto,
      marker,
      lebar: ukuran.w,
      tinggi: ukuran.h,
      tujuan: tujuan,
    );

    // Ambangnya milik server, tapi yang jelas-jelas rusak dihentikan di sini —
    // mengirim foto yang keempat sudutnya nggak membentuk persegi cuma
    // memindahkan penolakan ke belakang, sesudah teknisi menunggu unggahan.
    if (!warp.residualPx.isFinite || warp.residualPx > 8) {
      throw const PindaiGagal(GagalPindai.geometriMeleset);
    }

    final sel = <String, BacaanSel>{};
    final kotak = <String, ({double x, double y, double w, double h})>{};
    final bukti = <String, ({double titikUkur, int? standardId})>{};

    // Bukti per sel — titik ukur & standar yang DIHARAPKAN template. Server
    // membandingkannya dengan yang dikirim layar; kalau beda, berarti APK-nya
    // memegang lembar versi lain dan seluruh pemetaan dibatalkan.
    for (final t in template.tabel) {
      for (final b in t.baris) {
        for (final r in t.pengulangan) {
          for (final k in t.kolom) {
            bukti['${t.tabelId}|${b.barisKe}|$r|${k.fieldId}'] = (
              titikUkur: b.titikUkur,
              standardId: b.standardId,
            );
          }
        }
      }
    }

    // Kuncinya dari template APA ADANYA. Sel yang nggak ikut bikin seluruh
    // lembar ditolak server, jadi yang dilewati di sini cuma yang memang
    // nggak punya kotak.
    for (final e in template.sel.entries) {
      final b = e.value;

      kotak[e.key] = (x: b.x, y: b.y, w: b.w, h: b.h);

      final potongan = mesin.potongSel(
        warp.citra,
        x: b.x,
        y: b.y,
        w: b.w,
        h: b.h,
      );

      sel[e.key] = await pembaca.baca(potongan);
    }

    final mutu = mesin.mutu(warp.citra);

    // Sudut dihitung dari sisi atas (marker 0 → 1), sama seperti yang
    // diharapkan server sebagai `sudut_kemiringan_deg`.
    final sudut =
        math.atan2(marker[1].y - marker[0].y, marker[1].x - marker[0].x) *
        180 /
        math.pi;

    // Tinggi sel rata-rata di ruang warp — dipakai server buat menilai apakah
    // fotonya cukup rapat untuk dibaca.
    final tinggiSel = template.sel.values.isEmpty
        ? 0.0
        : template.sel.values.map((s) => s.h).reduce((a, b) => a + b) /
              template.sel.length;

    return payload.susun(
      templateId: template.templateId,
      templateVersi: template.versi,
      sel: sel,
      kotak: kotak,
      bukti: bukti,
      marker: marker,
      residualPx: warp.residualPx,
      ukuranReferensi: ukuran,
      mutu: mutu,
      sudutMiringDeg: sudut,
      pxPerSelTinggi: tinggiSel,
      calibrationSessionId: calibrationSessionId,
      equipmentId: equipmentId,
      jumlahPengulangan: template.tabel.isEmpty
          ? null
          : template.tabel.first.pengulangan.length,
      qrIsi: template.qrIsi,
      perangkat: perangkat,
    );
  }
}

/// Hasil pindai yang sudah dibaca server, buat layar review.
typedef HasilKirimPindai = HasilPindai;
