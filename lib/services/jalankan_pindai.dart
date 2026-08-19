import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/worksheet_scan.dart';
import '../models/worksheet_template.dart';
import 'pembaca_qr.dart';
import 'pembaca_sel.dart';
import 'pindai_lembar.dart';

/// Kenapa satu pindai berhenti sebelum sampai server.
///
/// Dibedakan supaya layar bisa bilang APA yang harus diperbaiki teknisi.
/// "Gagal memindai" tanpa sebab bikin orang mengulang jepretan yang sama
/// berkali-kali — dan sebagian sebab di bawah nggak akan pernah membaik dengan
/// mengulang.
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

  /// QR versi lembar nggak kebaca. Lembar lama hasil fotokopi nggak punya QR
  /// sama sekali — mengulang jepretan nggak akan memunculkannya.
  qrTidakKebaca,

  /// QR kebaca, tapi isinya lembar/versi LAIN. Ini bukan salah foto: lembarnya
  /// memang bukan yang dipegang aplikasi.
  qrLembarLain,

  /// Foto buram.
  mutuBuram,

  /// Terlalu gelap.
  mutuGelap,

  /// Terlalu terang sampai angkanya pudar.
  mutuSilau,

  /// Ada pantulan cahaya di lembar.
  mutuPantulan,

  /// Lembarnya kefoto miring.
  mutuMiring,

  /// Fotonya kejauhan — selnya kekecilan buat dibaca.
  mutuKejauhan,
}

class PindaiGagal implements Exception {
  const PindaiGagal(this.sebab);

  final GagalPindai sebab;

  @override
  String toString() => 'PindaiGagal(${sebab.name})';
}

/// Ambang mutu foto — **salinan `config/ocr.php` di server**.
///
/// Yang mutusin tetap server; yang di sini cuma nyegat foto yang jelas-jelas
/// bakal ditolak, supaya teknisi nggak nunggu unggahan cuma buat dapat
/// penolakan. Makanya angkanya identik, dan **nggak boleh dilonggarin biar
/// "lebih jarang gagal"**: gerbang yang lebih longgar dari servernya cuma
/// mindahin penolakan ke belakang, dan gerbang yang lebih ketat bikin foto
/// yang sebenarnya sah ditolak tanpa teknisi tahu kenapa.
class AmbangMutu {
  const AmbangMutu();

  static const blurMin = 90.0;
  static const kecerahanMin = 60.0;
  static const kecerahanMaks = 225.0;
  static const glareMaks = 0.05;
  static const miringMaksDeg = 8.0;
  static const pxPerSelMin = 24;

  /// Sebab foto ini bakal ditolak, atau `null` kalau lolos.
  ///
  /// Dipisah dari [JalankanPindai] biar bisa diadu ke angka persis: lewat
  /// citra, tiap ukuran ikut kegeser sama-sama (menggelapkan foto juga
  /// menurunkan ketajamannya), jadi nggak ada cara nguji satu ambang tanpa
  /// nabrak ambang lain duluan.
  static GagalPindai? periksa(
    ({double blur, double kecerahan, double glare}) mutu, {
    required double sudutMiringDeg,
    required int pxPerSelTinggi,
  }) {
    if (mutu.blur < blurMin) return GagalPindai.mutuBuram;
    if (mutu.kecerahan < kecerahanMin) return GagalPindai.mutuGelap;
    if (mutu.kecerahan > kecerahanMaks) return GagalPindai.mutuSilau;
    if (mutu.glare > glareMaks) return GagalPindai.mutuPantulan;
    if (sudutMiringDeg.abs() > miringMaksDeg) return GagalPindai.mutuMiring;
    if (pxPerSelTinggi < pxPerSelMin) return GagalPindai.mutuKejauhan;

    return null;
  }
}

/// Satu foto lembar kerja → hasil baca per sel di server.
///
/// ## Kenapa kelas sendiri
///
/// Potongannya sudah lengkap sejak lama — [PindaiLembar] meratakan foto,
/// [PembacaSel] membaca tiap potongan, [PayloadPindai] menyusun kiriman, dan
/// `PindaiReviewScreen` menampilkan hasilnya. Lemnya ditaruh di sini, bukan di
/// layar, karena urutannya yang menentukan benar-salahnya angka: baca QR,
/// ratakan, potong pakai kotak dari TEMPLATE, baca per potongan, kirim kunci
/// apa adanya. Ditaruh di widget, urutan itu bakal disalin ulang (dan diubah
/// sedikit) tiap kali ada layar baru yang mau memindai.
class JalankanPindai {
  const JalankanPindai({
    required this.mesin,
    required this.pembaca,
    required this.pembacaQr,
    this.payload = const PayloadPindai(),
  });

  final PindaiLembar mesin;
  final PembacaSel pembaca;

  /// Pembaca QR versi lembar. Wajib — lihat [PembacaQr] soal kenapa isinya
  /// nggak boleh disalin dari template.
  final PembacaQr pembacaQr;

  final PayloadPindai payload;

  /// Baca satu foto jadi payload `POST /api/worksheet-scans`.
  ///
  /// Nggak mengirim sendiri — yang mengirim pemanggilnya, supaya kelas ini
  /// bisa diuji tanpa jaringan. [HasilSusunPindai.citraWarp] ikut dibalikin
  /// buat dilampirkan sebagai `citra_warp`.
  Future<HasilSusunPindai> susun(
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

    // QR dibaca dari CITRA HASIL WARP, bukan foto mentah: di ruang template
    // posisinya sudah pasti dan skalanya seragam, jadi yang tadinya kekecilan
    // di foto jadi kebaca. Isinya diadu ke template — bukan disalin darinya.
    final qr = await pembacaQr.baca(warp.citra);

    if (qr == null) throw const PindaiGagal(GagalPindai.qrTidakKebaca);

    final qrDiharapkan = template.qrIsi;

    if (qrDiharapkan != null && qr != qrDiharapkan) {
      // Sengaja dibedakan dari "nggak kebaca": yang ini foto ulang nggak
      // menolong, lembarnya yang salah.
      throw const PindaiGagal(GagalPindai.qrLembarLain);
    }

    // Sudut dihitung dari sisi atas (marker 0 → 1), sama seperti yang
    // diharapkan server sebagai `sudut_kemiringan_deg`.
    final sudut =
        math.atan2(marker[1].y - marker[0].y, marker[1].x - marker[0].x) *
        180 /
        math.pi;

    final mutu = mesin.mutu(warp.citra);
    final pxPerSel = _pxPerSelTinggi(template, marker, tujuan);

    _gerbangMutu(mutu, sudutMiringDeg: sudut, pxPerSelTinggi: pxPerSel);

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

    return HasilSusunPindai(
      body: payload.susun(
        templateId: template.templateId,
        templateVersi: template.versi,
        sel: sel,
        kotak: kotak,
        bukti: bukti,
        jangkar: await _bacaJangkar(template, warp.citra),
        marker: marker,
        residualPx: warp.residualPx,
        ukuranReferensi: ukuran,
        mutu: mutu,
        sudutMiringDeg: sudut,
        pxPerSelTinggi: pxPerSel,
        calibrationSessionId: calibrationSessionId,
        equipmentId: equipmentId,
        jumlahPengulangan: template.tabel.isEmpty
            ? null
            : template.tabel.first.pengulangan.length,
        qrIsi: qr,
        perangkat: perangkat,
      ),
      citraWarp: warp.citra,
    );
  }

  /// Baca label tercetak (nomor Repeat) dan bandingkan sama yang diharapkan.
  ///
  /// Jangkar yang kotaknya masih `0×0` — keadaan semua berkas geometri rangka
  /// sekarang — **dilewat**, bukan dikirim `cocok: true`. Sel sebesar nol
  /// nggak bisa dipotong, jadi mengaku cocok berarti mematikan penjagaan
  /// "geser satu baris" sambil bikin dia kelihatan hidup.
  Future<List<BacaanJangkar>> _bacaJangkar(
    WorksheetTemplate template,
    img.Image warp,
  ) async {
    final hasil = <BacaanJangkar>[];

    for (final j in template.jangkar) {
      if (!j.bisaDibaca) continue;

      final potongan = mesin.potongSel(
        warp,
        x: j.kotak.x,
        y: j.kotak.y,
        w: j.kotak.w,
        h: j.kotak.h,
      );

      final baca = await pembaca.baca(potongan);
      final teks = baca.teks?.trim() ?? '';

      hasil.add((
        fieldId: j.fieldId,
        repeatNo: j.repeatNo,
        teks: baca.teks,
        // Dibandingkan sesudah spasi dibuang, tapi nggak lebih longgar dari
        // itu: `3` yang kebaca di posisi Repeat 2 memang harus dinyatakan
        // nggak cocok — persis kejadian yang jangkar ini ada buat nangkep.
        cocok: teks == j.teks.trim(),
      ));
    }

    return hasil;
  }

  /// Tinggi satu sel dalam piksel **FOTO**, bukan piksel ruang template.
  ///
  /// Bedanya menentukan: sesudah warp, tinggi sel selalu sama persis dengan
  /// yang tertulis di template — berapa pun jauhnya HP waktu memotret. Angka
  /// dari ruang warp jadi tetap lolos ambang `px_per_sel_min` walau lembarnya
  /// difoto dari seberang meja, dan gerbang "fotonya kejauhan" nggak pernah
  /// nyala. Yang benar: tinggi sel di template dikali seberapa besar lembarnya
  /// tampil di foto.
  int _pxPerSelTinggi(
    WorksheetTemplate template,
    List<Sudut> diFoto,
    List<Sudut> diTemplate,
  ) {
    if (template.sel.isEmpty) return 0;

    final rataTinggi =
        template.sel.values.map((s) => s.h).reduce((a, b) => a + b) /
        template.sel.length;

    double jarak(Sudut a, Sudut b) =>
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

    // Dua sisi diukur (atas & kiri) lalu dirata: foto yang agak juling bikin
    // satu sisi tampak lebih pendek dari yang lain.
    final sisiFoto = jarak(diFoto[0], diFoto[1]) + jarak(diFoto[0], diFoto[3]);
    final sisiTemplate =
        jarak(diTemplate[0], diTemplate[1]) +
        jarak(diTemplate[0], diTemplate[3]);

    if (sisiTemplate <= 0) return 0;

    return (rataTinggi * (sisiFoto / sisiTemplate)).round();
  }

  /// Hentikan foto yang bakal ditolak server, dengan sebab yang sama.
  void _gerbangMutu(
    ({double blur, double kecerahan, double glare}) mutu, {
    required double sudutMiringDeg,
    required int pxPerSelTinggi,
  }) {
    final sebab = AmbangMutu.periksa(
      mutu,
      sudutMiringDeg: sudutMiringDeg,
      pxPerSelTinggi: pxPerSelTinggi,
    );

    if (sebab != null) throw PindaiGagal(sebab);
  }
}

/// Payload siap kirim + citra hasil warp yang jadi lampirannya.
class HasilSusunPindai {
  const HasilSusunPindai({required this.body, required this.citraWarp});

  final Map<String, dynamic> body;

  /// Dilampirkan sebagai `citra_warp`. **Lampiran audit** — boleh gagal naik
  /// tanpa mbatalin hasil pindai; tapi tanpa dia, layar review nggak punya
  /// potongan sel buat diadu sama angkanya, dan teknisi bakal milih ngetik
  /// dari awal.
  final img.Image citraWarp;
}

/// Hasil pindai yang sudah dibaca server, buat layar review.
typedef HasilKirimPindai = HasilPindai;
