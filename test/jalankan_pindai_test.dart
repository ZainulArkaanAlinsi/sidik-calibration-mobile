import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart';
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
void main() {
  late img.Image lembar;
  late WorksheetTemplate template;

  setUpAll(() {
    lembar = img.decodePng(
      File('test/assets/lembar-conductivity-v1.png').readAsBytesSync(),
    )!;

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

    final body = await JalankanPindai(
      mesin: const PindaiLembar(),
      pembaca: pembaca,
    ).susun(lembar, template: template, equipmentId: 7);

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
    final body = await JalankanPindai(
      mesin: const PindaiLembar(),
      pembaca: _PembacaPalsu(),
    ).susun(lembar, template: template);

    final geometri = body['geometri'] as Map<String, dynamic>;

    expect(geometri['marker'], hasLength(4));
    expect(geometri['ukuran_referensi'], {'w': 1654, 'h': 2339});

    // Lembar rata difoto rata: residualnya nol sampai batas double.
    expect(geometri['residual_reproyeksi_px'] as double, lessThan(0.01));

    final kualitas = body['kualitas'] as Map<String, dynamic>;
    expect(kualitas['sudut_kemiringan_deg'] as double, closeTo(0, 0.5));
    expect(kualitas['px_per_sel_tinggi'] as double, greaterThan(0));
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
