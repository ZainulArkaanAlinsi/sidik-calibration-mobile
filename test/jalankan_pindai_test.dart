import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart';
import 'package:sidik_calibration/services/pembaca_qr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pindai_lembar.dart';

/// Lem antara foto dan server: `JalankanPindai`.
///
/// Sebelum ini potongannya lengkap tapi nggak ada yang menyambung — tombol
/// "Pindai lembar" terpasang dengan callback kosong (`() {}`), jadi jalur
/// kamera belum pernah jalan sekali pun. Berkas ini menjaga sambungannya.
///
/// Fotonya lembar cetak asli (`ocr:cetak-lembar conductivity_meter`),
/// geometrinya berkas yang sama yang dipakai server. Yang dipalsukan cuma
/// pembaca selnya — ML Kit butuh perangkat, dan yang diuji di sini bukan
/// ketajaman OCR-nya tapi apakah tiap potongan sampai ke kunci yang benar.
/// Lembar cetak yang dibikin mirip JEPRETAN, bukan berkas rendernya.
///
/// Berkas aslinya PNG hasil render: putihnya 255 pekat, jadi kecerahan
/// rata-ratanya 247 dan hampir semua pikselnya kehitung "kebakar cahaya".
/// Foto kertas beneran nggak pernah begitu. Dipakai apa adanya, gerbang mutu
/// yang baru nolak berkas ini sebagai "terlalu terang" — dan yang keuji jadi
/// bukan pemetaan selnya, tapi bahwa berkas ujinya bukan foto.
img.Image _sepertiJepretan(img.Image asli) {
  final hasil = img.Image.from(asli);

  // Tinta hitam tetap hitam (marker mesti tetap kebaca), kertasnya turun ke
  // sekitar 155 — kecerahan yang wajar buat kertas di bawah lampu ruangan.
  for (var y = 0; y < hasil.height; y++) {
    for (var x = 0; x < hasil.width; x++) {
      final p = hasil.getPixel(x, y);
      hasil.setPixelRgb(
        x,
        y,
        (p.r * 0.62).round(),
        (p.g * 0.62).round(),
        (p.b * 0.62).round(),
      );
    }
  }

  return hasil;
}

void main() {
  late img.Image lembar;
  late WorksheetTemplate template;

  setUpAll(() {
    lembar = _sepertiJepretan(
      img.decodePng(
        File('test/assets/lembar-conductivity-v1.png').readAsBytesSync(),
      )!,
    );

    final geometri =
        jsonDecode(
              File('test/assets/geometri-conductivity-v1.json')
                  .readAsStringSync(),
            )
            as Map<String, dynamic>;

    // Bentuk respons `GET /api/worksheet-templates/{kode}`: bentuk lembar di
    // level atas, berkas geometri utuh di bawah `geometri`.
    final sel = <String, dynamic>{};
    final tabel = <Map<String, dynamic>>[];

    for (final t in geometri['tabel'] as List<dynamic>) {
      final m = t as Map<String, dynamic>;
      sel.addAll(m['sel'] as Map<String, dynamic>);

      tabel.add({
        'tabel_id': m['tabel_id'],
        'judul': m['judul'],
        'baris': [
          for (var i = 1; i <= 4; i++)
            {'baris_ke': i, 'titik_ukur': 25.0 * i, 'standard_id': i},
        ],
        'kolom': [
          {'field_id': 'pembacaan', 'label': 'Reading'},
          {'field_id': 'suhu', 'label': '°C'},
        ],
        'pengulangan': [1, 2, 3, 4, 5],
      });
    }

    template = WorksheetTemplate.fromJson({
      'template_id': geometri['template_id'],
      'versi': geometri['versi'],
      'kode_dokumen': geometri['kode_dokumen'],
      'judul': 'Calibration Worksheet - Conductivity Meter',
      'siap_pindai': true,
      'tabel': tabel,
      'sel': sel,
      'jangkar': geometri['jangkar'],
      'geometri': geometri,
    });
  });

  test('template bawa marker & QR dari geometri', () {
    // Tujuan warp itu POSISI MARKER, bukan pojok halaman. Markernya dicetak
    // agak masuk ke dalam kertas; meratakan ke pojok menggeser seluruh grid
    // sebesar jarak itu.
    expect(template.marker, hasLength(4));
    expect(template.marker.first.x, 90);
    expect(template.marker.first.y, 90);
    expect(template.qrIsi, 'conductivity_meter|v1');
    expect(template.ukuranReferensi, (w: 1654, h: 2339));
  });

  test('satu foto jadi payload berisi SEMUA sel', () async {
    final pembaca = _PembacaPalsu();

    final hasil = await JalankanPindai(
      mesin: const PindaiLembar(),
      pembaca: pembaca,
      pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
    ).susun(lembar, template: template, equipmentId: 7);

    final body = hasil.body;

    expect(body['template_id'], 'conductivity_meter');
    expect(body['template_versi'], 1);
    expect(body['equipment_id'], 7);
    expect((body['qr'] as Map)['isi'], 'conductivity_meter|v1');

    final sel = body['sel'] as List<dynamic>;

    // Semua sel template ikut, termasuk yang kosong: sel yang hilang tanpa
    // suara lebih bahaya daripada scan yang ditolak.
    expect(sel, hasLength(template.sel.length));
    expect(pembaca.dibaca, template.sel.length);

    // Kuncinya dipecah server dari `tabel|baris|repeat|field`; yang dikirim
    // harus cocok dengan kunci template, bukan indeks tampilan.
    final kunci = {
      for (final s in sel.cast<Map<String, dynamic>>())
        '${s['tabel_id']}|${s['baris_ke']}|${s['repeat_no']}|${s['field_id']}',
    };

    expect(kunci, template.sel.keys.toSet());
  });

  test('geometri fotonya ikut dikirim sebagai bukti', () async {
    final body = (await JalankanPindai(
      mesin: const PindaiLembar(),
      pembaca: _PembacaPalsu(),
      pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
    ).susun(lembar, template: template)).body;

    final geometri = body['geometri'] as Map<String, dynamic>;

    expect(geometri['marker'], hasLength(4));
    expect(geometri['ukuran_referensi'], {'w': 1654, 'h': 2339});

    // Lembar rata difoto rata: residualnya nol sampai batas double.
    expect(geometri['residual_reproyeksi_px'] as double, lessThan(0.01));

    final kualitas = body['kualitas'] as Map<String, dynamic>;
    expect(kualitas['sudut_kemiringan_deg'] as double, closeTo(0, 0.5));
    expect(kualitas['px_per_sel_tinggi'] as int, greaterThan(0));
  });

  /// Empat sebab gagal dibedakan supaya layar bisa bilang APA yang harus
  /// diperbaiki. "Gagal memindai" tanpa sebab bikin teknisi mengulang jepretan
  /// yang sama berkali-kali — dan tiga dari empat sebab nggak akan membaik.
  group('gagal yang dibedakan', () {
    test('lembar yang belum boleh dipindai ditolak sebelum kamera dibuka', () {
      final belum = WorksheetTemplate.fromJson({
        'template_id': 'conductivity_meter',
        'siap_pindai': false,
        'alasan_belum_siap': 'geometri_belum_diverifikasi',
      });

      expect(
        () => JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: _PembacaPalsu(),
          pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
        ).susun(lembar, template: belum),
        throwsA(
          isA<PindaiGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindai.belumSiap,
          ),
        ),
      );
    });

    test('foto tanpa penanda sudut dibedakan dari foto miring', () {
      final polos = img.Image(width: 1654, height: 2339);
      img.fill(polos, color: img.ColorRgb8(255, 255, 255));

      expect(
        () => JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: _PembacaPalsu(),
          pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
        ).susun(polos, template: template),
        throwsA(
          isA<PindaiGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindai.markerTidakKetemu,
          ),
        ),
      );
    });
  });

  /// QR-nya WAJIB datang dari fotonya sendiri.
  ///
  /// Server nolak seluruh pindai kalau `qr.terbaca` bukan `true`, dan itu
  /// satu-satunya penjagaan versi lembar: Rev.4 & Rev.5 mirip di mata orang,
  /// beda di mata koordinat. Nyalin `qrIsi` dari respons template ke `qr.isi`
  /// bikin penjagaan itu selalu lolos — nilainya dibandingkan sama dirinya
  /// sendiri.
  group('QR versi lembar', () {
    test('isi yang dikirim datang dari pembacaan, bukan dari template', () async {
      final body = (await JalankanPindai(
        mesin: const PindaiLembar(),
        pembaca: _PembacaPalsu(),
        pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
      ).susun(lembar, template: template)).body;

      expect((body['qr'] as Map)['terbaca'], true);
      expect((body['qr'] as Map)['isi'], 'conductivity_meter|v1');
    });

    test('QR nggak kebaca → berhenti, bukan ngaku terbaca', () {
      expect(
        () => JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: _PembacaPalsu(),
          pembacaQr: MockPembacaQr(),
        ).susun(lembar, template: template),
        throwsA(
          isA<PindaiGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindai.qrTidakKebaca,
          ),
        ),
      );
    });

    test('QR lembar lain dibedakan dari QR yang nggak kebaca', () {
      // Bedanya bukan kosmetik: yang satu foto ulang menolong, yang satu lagi
      // lembarnya yang salah dan foto ulang cuma buang waktu teknisi.
      expect(
        () => JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: _PembacaPalsu(),
          pembacaQr: MockPembacaQr(isi: 'ph_meter|v1'),
        ).susun(lembar, template: template),
        throwsA(
          isA<PindaiGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindai.qrLembarLain,
          ),
        ),
      );
    });
  });

  /// Gerbang mutu dihitung DI HP supaya teknisi nggak nunggu unggahan cuma
  /// buat ditolak. Ambangnya sama persis dengan server — dilonggarkan sedikit
  /// pun, penolakannya cuma pindah ke belakang.
  group('gerbang mutu', () {
    test('tiap ambang punya sebabnya sendiri', () {
      // Diadu ke angka, bukan ke citra: menggelapkan foto juga menurunkan
      // ketajamannya, jadi lewat citra "terlalu gelap" selalu kena gerbang
      // buram duluan dan ambang kecerahannya nggak pernah keuji.
      GagalPindai? sebab({
        double blur = 240,
        double kecerahan = 150,
        double glare = 0.01,
        double miring = 1.0,
        int pxPerSel = 60,
      }) => AmbangMutu.periksa(
        (blur: blur, kecerahan: kecerahan, glare: glare),
        sudutMiringDeg: miring,
        pxPerSelTinggi: pxPerSel,
      );

      expect(sebab(), isNull);
      expect(sebab(blur: 89.9), GagalPindai.mutuBuram);
      expect(sebab(kecerahan: 59.9), GagalPindai.mutuGelap);
      expect(sebab(kecerahan: 225.1), GagalPindai.mutuSilau);
      expect(sebab(glare: 0.051), GagalPindai.mutuPantulan);
      expect(sebab(miring: -8.1), GagalPindai.mutuMiring);
      expect(sebab(pxPerSel: 23), GagalPindai.mutuKejauhan);

      // Ambangnya SAMA PERSIS sama server (`config/ocr.php`). Yang tepat di
      // ambang lolos di dua-duanya — kalau di sini lebih ketat, foto yang
      // sebenarnya sah ditolak tanpa teknisi tahu kenapa.
      expect(sebab(blur: 90), isNull);
      expect(sebab(kecerahan: 60), isNull);
      expect(sebab(kecerahan: 225), isNull);
      expect(sebab(glare: 0.05), isNull);
      expect(sebab(miring: 8), isNull);
      expect(sebab(pxPerSel: 24), isNull);
    });

    test('lembar yang kefoto kekecilan ditolak sebagai kejauhan', () {
      // Ini yang nggak ketangkep kalau px-per-sel diambil dari ruang warp:
      // sesudah diratakan, tinggi selnya selalu sama dengan template, berapa
      // pun jauhnya HP waktu motret. Yang diukur harus piksel FOTO.
      final jauh = img.copyResize(lembar, width: 300);

      expect(
        () => JalankanPindai(
          mesin: const PindaiLembar(),
          pembaca: _PembacaPalsu(),
          pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
        ).susun(jauh, template: template),
        throwsA(
          isA<PindaiGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindai.mutuKejauhan,
          ),
        ),
      );
    });
  });

  /// Jangkar = label Repeat yang TERCETAK di lembar. Penjagaan lain ngukur
  /// geometri; yang ini baca isinya, dan itu satu-satunya yang nangkep grid
  /// yang kegeser satu baris.
  test('jangkar berkotak nol nggak dikirim sebagai "cocok"', () async {
    // Semua berkas geometri sekarang masih rangka: kotak jangkarnya `0×0`.
    // Kotak sebesar nol nggak bisa dipotong, jadi mengaku cocok berarti
    // mematikan penjagaannya sambil bikin dia kelihatan hidup. Yang benar:
    // nggak dikirim sama sekali, biar server yang nolak dengan alasan jujur.
    expect(template.jangkar, hasLength(5));
    expect(template.jangkar.every((j) => !j.bisaDibaca), isTrue);

    final body = (await JalankanPindai(
      mesin: const PindaiLembar(),
      pembaca: _PembacaPalsu(),
      pembacaQr: MockPembacaQr(isi: 'conductivity_meter|v1'),
    ).susun(lembar, template: template)).body;

    expect(body.containsKey('sel_jangkar'), isFalse);
  });
}


/// Pembaca sel palsu — ML Kit butuh perangkat, dan yang diuji di sini
/// pemetaannya, bukan ketajaman OCR-nya.
class _PembacaPalsu implements PembacaSel {
  int dibaca = 0;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    dibaca++;

    return (teks: null, keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async {}
}
