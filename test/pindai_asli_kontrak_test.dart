import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/worksheet_scan.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Kontrak HP ↔ server untuk pindai FORMULIR ASLI.
///
/// Sumber kebenarannya bukan dokumen tapi kode server yang sudah LIVE
/// (3222d1b): `WorksheetScanRequest::aturanAsli()` untuk bentuk kiriman,
/// `WorksheetScanController::bentukHasil()` + `PemrosesScanLembarKerja::
/// prosesAsli()` untuk bentuk balasan. Contoh nilai disalin dari laporan
/// B2 (`_agents_workspace/ocr-ph-formulir-asli/03-bangun-B2.md`, "Contoh
/// (dari respons nyata test)").
void main() {
  final template = WorksheetTemplate.fromJson(
    jsonDecode(
          File(
            'test/assets/template-asli-ph_meter-0509.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  group('template ?kertas=asli dibaca', () {
    test('60 sel, 4 isian Env., 9 centang, 93 jangkar — kotak ternormal', () {
      expect(template.kertasAsli, isTrue);
      expect(template.kodeDokumen, 'SIDIK-FM-CAL-0509');
      expect(template.revisi, '4');
      expect(template.modeUji, isTrue);
      expect(template.siapPindai, isFalse);
      expect(template.bolehDipindaiAsli, isTrue);
      expect(template.halamanPt, (w: 792.0, h: 612.0));
      expect(template.selAsli, hasLength(60));
      expect(template.isian.map((i) => i.kode), [
        'suhu_awal',
        'kelembaban_awal',
        'suhu_akhir',
        'kelembaban_akhir',
      ]);
      expect(template.centang, hasLength(9));
      expect(template.jangkarTeks, hasLength(93));
      expect(template.kotakAsliHilang, 0);

      // Kunci & kotak dari server apa adanya (B1: sel pertama).
      final s = template.selAsli.firstWhere(
        (s) => s.kunci == 'sebelum_adjustment|1|1|pembacaan',
      );
      expect(s.tabelId, 'sebelum_adjustment');
      expect(s.barisKe, 1);
      expect(s.repeatNo, 1);
      expect(s.fieldId, 'pembacaan');
      expect(s.kotak!.x, 0.50801);
      expect(s.kotak!.h, 0.03595);

      // `sel` jalur cetak sengaja kosong — kotak 0×0 bukan kotak.
      expect(template.sel, isEmpty);
    });

    test('mode uji mati & belum siap → tombolnya tidak boleh ada', () {
      final mati = WorksheetTemplate.fromJson({
        'data': {..._dataTemplate(), 'mode_uji': false, 'siap_pindai': false},
      });
      expect(mati.bolehDipindaiAsli, isFalse);

      final siap = WorksheetTemplate.fromJson({
        'data': {..._dataTemplate(), 'mode_uji': false, 'siap_pindai': true},
      });
      expect(siap.bolehDipindaiAsli, isTrue);
    });

    test('kotak null = butir yang tidak dibaca, dihitung', () {
      final data = _dataTemplate();
      final isian = [...(data['isian'] as List)];
      isian[0] = {...isian[0] as Map<String, dynamic>, 'kotak': null};

      final t = WorksheetTemplate.fromJson({
        'data': {...data, 'isian': isian},
      });
      expect(t.kotakAsliHilang, 1);
      expect(t.isian.first.kotak, isNull);
    });

    test('respons lembar cetak tetap dibaca seperti dulu', () {
      final cetak = WorksheetTemplate.fromJson({
        'template_id': 'ph_meter',
        'versi': 1,
        'sel': {
          'a|1|1|pembacaan': {'x': 10, 'y': 20, 'w': 30, 'h': 40},
        },
      });
      expect(cetak.kertasAsli, isFalse);
      expect(cetak.sel['a|1|1|pembacaan']!.w, 30);
      expect(cetak.selAsli, isEmpty);
    });
  });

  group('payload POST /worksheet-scans kertas=asli', () {
    Map<String, dynamic> susun({Map<String, double?>? centang}) =>
        const PayloadPindaiAsli().susun(
          template: template,
          kodeTerbaca: 'SIDIK-FM-CAL-0509',
          revisiTerbaca: ': 4',
          jangkarCocok: [
            (
              indeks: 46,
              teksMentah: 'TH-2',
              foto: (x: 1, y: 1),
              template: (x: 1, y: 1),
              kuadran: 0,
            ),
            (
              indeks: 0,
              teksMentah: 'PT.',
              foto: (x: 1, y: 1),
              template: (x: 1, y: 1),
              kuadran: 0,
            ),
          ],
          residualPt: 0.6,
          mutu: (blur: 210.5, kecerahan: 190.2, glare: 0.01),
          sudutMiringDeg: 1.2,
          pxPerSelTinggi: 95,
          sel: {
            'sebelum_adjustment|1|1|pembacaan': (
              teks: '4,01',
              keyakinan: null,
              didalamKotak: true,
            ),
          },
          isian: {
            'suhu_awal': (teks: '25,0', keyakinan: null, didalamKotak: true),
            'kelembaban_awal': (
              teks: '60',
              keyakinan: null,
              didalamKotak: false,
            ),
          },
          centang:
              centang ??
              {
                for (final c in template.centang)
                  c.id: c.pilihan == 'TH-2' ? 0.4 : 0.01,
              },
          calibrationSessionId: 1,
          diambilPada: DateTime.utc(2026, 10, 9, 8),
        );

    test('kunci tingkat atas = aturanAsli + aturan cetak yang berlaku', () {
      final body = susun();

      expect(body.keys.toSet(), {
        'kertas',
        'template_id',
        'template_versi',
        'kode_dokumen_terbaca',
        'revisi_terbaca',
        'calibration_session_id',
        'geometri',
        'kualitas',
        'diambil_pada',
        'sel',
        'isian',
        'centang',
      });
      expect(body['kertas'], 'asli');
      expect(body['template_id'], 'ph_meter');
      // Revisi yang DIPEGANG aplikasi, integer (aturan `integer|between:0,999`).
      expect(body['template_versi'], 4);
      expect(body['kode_dokumen_terbaca'], 'SIDIK-FM-CAL-0509');
      // Formulir asli tidak punya QR — `qr` tidak dikirim sama sekali.
      expect(body.containsKey('qr'), isFalse);
    });

    test('geometri: jangkar_cocok urut indeks + residual pt, TANPA ukuran', () {
      final g = susun()['geometri'] as Map<String, dynamic>;

      expect(g['jangkar_cocok'], [
        {'indeks': 0, 'teks_mentah': 'PT.'},
        {'indeks': 46, 'teks_mentah': 'TH-2'},
      ]);
      expect(g['residual_reproyeksi_pt'], 0.6);
      // `ukuran_referensi.*` divalidasi `integer` — halaman A4 berpecahan
      // akan menolak seluruh kiriman.
      expect(g.containsKey('ukuran_referensi'), isFalse);
      expect(g.containsKey('marker'), isFalse);
    });

    test('SEMUA 60 sel ikut, termasuk yang tidak terbaca', () {
      final sel = susun()['sel'] as List;

      expect(sel, hasLength(60));
      expect(sel.first, {
        'tabel_id': 'sebelum_adjustment',
        'baris_ke': 1,
        'repeat_no': 1,
        'field_id': 'pembacaan',
        'teks_mentah': '4,01',
        'confidence_ocr': null,
        'kotak_teks_di_dalam_sel': true,
        'titik_ukur': 4.0,
        'standard_id': 2,
        'sumber': 'mlkit',
      });

      final kosong = sel.firstWhere(
        (s) => s['tabel_id'] == 'sesudah_adjustment' && s['field_id'] == 'suhu',
      );
      expect(kosong['teks_mentah'], isNull);
    });

    test('isian Env.: bentuk contoh B2, keempatnya ikut', () {
      final isian = susun()['isian'] as List;

      expect(isian.map((i) => i['kode']), [
        'suhu_awal',
        'kelembaban_awal',
        'suhu_akhir',
        'kelembaban_akhir',
      ]);
      expect(isian[0], {
        'kode': 'suhu_awal',
        'teks_mentah': '25,0',
        'confidence_ocr': null,
        'kotak_teks_di_dalam_sel': true,
        'sumber': 'mlkit',
      });
      expect(isian[1]['kotak_teks_di_dalam_sel'], isFalse);
    });

    test(
      'centang: identitas kode+pilihan / kode+baris_ke, rasio apa adanya',
      () {
        final centang = susun()['centang'] as List;

        expect(centang, hasLength(9));
        expect(centang.first, {
          'kode': 'standar_dicek.*.dipakai',
          'baris_ke': 1,
          'rasio_gelap': 0.01,
        });
        expect(centang.firstWhere((c) => c['pilihan'] == 'TH-2'), {
          'kode': 'thermohygro_standard_id',
          'pilihan': 'TH-2',
          'rasio_gelap': 0.4,
        });
      },
    );

    test('rasio tidak terukur dikirim null — bukan 0 karangan', () {
      final centang =
          susun(
                centang: {for (final c in template.centang) c.id: null},
              )['centang']
              as List;

      expect(centang.every((c) => c['rasio_gelap'] == null), isTrue);
    });

    test('teks kepanjangan dipotong ke batas max: server, bukan 422', () {
      final panjang = 'x' * 80;
      final body = const PayloadPindaiAsli().susun(
        template: template,
        kodeTerbaca: 'SIDIK-FM-CAL-0509',
        revisiTerbaca: ': 4 ${'y' * 30}',
        jangkarCocok: const [],
        residualPt: 0.5,
        mutu: (blur: 200, kecerahan: 180, glare: 0),
        sudutMiringDeg: 0,
        pxPerSelTinggi: 90,
        sel: {
          template.selAsli.first.kunci: (
            teks: panjang,
            keyakinan: null,
            didalamKotak: false,
          ),
        },
        isian: {
          'suhu_awal': (teks: panjang, keyakinan: null, didalamKotak: false),
        },
        centang: const {},
      );

      // WorksheetScanRequest: sel/isian teks_mentah max:64, revisi max:20.
      expect((body['sel'] as List).first['teks_mentah'], 'x' * 64);
      expect((body['isian'] as List).first['teks_mentah'], 'x' * 64);
      expect((body['revisi_terbaca'] as String).length, 20);
      expect((body['revisi_terbaca'] as String), startsWith(': 4'));
    });
  });

  group('multipart', () {
    test('boolean jadi 1/0, null dibuang, kunci bersarang bertanda kurung', () {
      final body = const PayloadPindaiAsli().susun(
        template: template,
        kodeTerbaca: 'SIDIK-FM-CAL-0509',
        jangkarCocok: const [],
        residualPt: 0.8,
        mutu: (blur: 200, kecerahan: 180, glare: 0),
        sudutMiringDeg: 0,
        pxPerSelTinggi: 90,
        sel: const {},
        isian: {
          'suhu_awal': (teks: '25,0', keyakinan: null, didalamKotak: true),
          'kelembaban_awal': (teks: '60', keyakinan: null, didalamKotak: false),
        },
        centang: {
          for (final c in template.centang)
            c.id: c.pilihan == 'TH-6' ? null : 0.3,
        },
        diambilPada: DateTime.utc(2026, 10, 9),
      );

      final f = ApiClient.ratakanUntukMultipart(body);

      expect(f['kertas'], 'asli');
      expect(f['template_versi'], '4');
      expect(f['isian[0][kotak_teks_di_dalam_sel]'], '1');
      expect(f['isian[1][kotak_teks_di_dalam_sel]'], '0');
      // `null` dibuang, bukan dikirim "null" — server membaca kunci yang
      // tidak ada sebagai null (teks kosong / rasio tidak terukur).
      expect(f.containsKey('isian[2][teks_mentah]'), isFalse);
      expect(f.containsKey('sel[0][teks_mentah]'), isFalse);
      expect(f['sel[0][kotak_teks_di_dalam_sel]'], '1');

      final iTh6 = template.centang.indexWhere((c) => c.pilihan == 'TH-6');
      final iTh2 = template.centang.indexWhere((c) => c.pilihan == 'TH-2');
      expect(f.containsKey('centang[$iTh6][rasio_gelap]'), isFalse);
      expect(f['centang[$iTh2][pilihan]'], 'TH-2');
      expect(f.containsKey('centang[$iTh2][baris_ke]'), isFalse);
      expect(f['centang[0][baris_ke]'], '1');
      expect(f['geometri[residual_reproyeksi_pt]'], '0.8');
      expect(f.values.contains('null'), isFalse);
    });

    test('kirim: berkas JPEG diberi nama .jpg, kolom asli sampai', () async {
      String? isiPermintaan;

      final api = ApiClient(
        client: MockClient((req) async {
          isiPermintaan = latin1.decode(req.bodyBytes);

          return _json(_balasanB2, 201);
        }),
        baseUrl: 'http://uji/api',
      );

      final hasil = await ApiWorksheetScanService(api).kirim(
        'token',
        {'kertas': 'asli', 'template_id': 'ph_meter'},
        // Awalan JPEG (FF D8).
        citraWarp: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]),
      );

      expect(isiPermintaan, contains('filename="warp.jpg"'));
      expect(isiPermintaan, contains('name="kertas"\r\n\r\nasli'));
      expect(hasil.kertasAsli, isTrue);
    });

    test('kirim: PNG jalur cetak tetap bernama warp.png', () async {
      String? isiPermintaan;

      final api = ApiClient(
        client: MockClient((req) async {
          isiPermintaan = latin1.decode(req.bodyBytes);

          return _json(_balasanB2, 201);
        }),
        baseUrl: 'http://uji/api',
      );

      await ApiWorksheetScanService(api).kirim('token', {
        'template_id': 'ph_meter',
      }, citraWarp: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2]));

      expect(isiPermintaan, contains('filename="warp.png"'));
    });
  });

  group('GET ?kertas=asli', () {
    test('404 = alat belum punya formulir asli → null, bukan error', () async {
      Uri? diminta;
      final api = ApiClient(
        client: MockClient((req) async {
          diminta = req.url;

          return http.Response(
            jsonEncode({
              'message':
                  'Formulir asli lab buat alat ini belum dipetakan. Pakai lembar cetak atau isi manual dulu.',
            }),
            404,
          );
        }),
        baseUrl: 'http://uji/api',
      );

      final t = await ApiWorksheetScanService(
        api,
      ).templateAsli('token', 'timbangan', equipmentId: 7);

      expect(t, isNull);
      expect(diminta!.path, '/api/worksheet-templates/timbangan');
      expect(diminta!.queryParameters, {'kertas': 'asli', 'equipment_id': '7'});
    });

    test('200 → template asli', () async {
      final api = ApiClient(
        client: MockClient(
          (req) async => http.Response.bytes(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsBytesSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: 'http://uji/api',
      );

      final t = await ApiWorksheetScanService(
        api,
      ).templateAsli('token', 'ph_meter');

      expect(t!.kertasAsli, isTrue);
      expect(t.selAsli, hasLength(60));
    });

    test('error selain 404 TIDAK disamarkan jadi "belum dipetakan"', () async {
      final api = ApiClient(
        client: MockClient(
          (req) async => http.Response(jsonEncode({'message': 'x'}), 403),
        ),
        baseUrl: 'http://uji/api',
      );

      expect(
        ApiWorksheetScanService(api).templateAsli('token', 'ph_meter'),
        throwsA(anything),
      );
    });
  });

  group('balasan server dibaca', () {
    test('isian, centang, kertas, mode_uji, wajib_dicek', () {
      final h = HasilPindai.fromJson(_balasanB2);

      expect(h.kertasAsli, isTrue);
      expect(h.modeUji, isTrue);
      expect(h.wajibDicek, isTrue);
      expect(h.isian.single.kunci, 'isian|suhu_awal');
      expect(h.isian.single.nilai, 25);
      expect(h.isian.single.satuan, '°C');
      expect(h.isian.single.vonis, VonisSel.kuning);

      final th2 = h.centang.firstWhere((c) => c.pilihan == 'TH-2');
      expect(th2.kunci, 'centang|thermohygro_standard_id|TH-2');
      expect(th2.dicentang, isTrue);
      expect(th2.rasioGelap, 0.4);
      expect(th2.alasan, ['template_belum_terverifikasi']);

      final ganda = h.centang.firstWhere((c) => c.pilihan == 'TH-6');
      expect(ganda.vonis, VonisSel.merah);
      expect(ganda.pesan, isNotNull);
    });

    test('balasan lembar cetak lama: tanpa kertas → bentuk lama', () {
      final h = HasilPindai.fromJson({
        'scan_id': 3,
        'status': 'ok',
        'ringkasan': const <String, dynamic>{},
        'tabel': const <dynamic>[],
        'boleh_auto_isi': true,
        'wajib_dicek': false,
      });

      expect(h.kertasAsli, isFalse);
      expect(h.isian, isEmpty);
      expect(h.centang, isEmpty);
    });
  });

  test('normalisasi kode sama dengan yang dipakai pencari kode', () {
    expect(normalisasiKodeDokumen(template.kodeDokumen), 'SIDIK-FM-CAL-0509');
  });
}

/// Balasan JSON UTF-8 — `http.Response(String)` cuma menerima latin1, dan
/// kalimat server memuat `—`.
http.Response _json(Object isi, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(isi)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _dataTemplate() => Map<String, dynamic>.from(
  (jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>)['data']
      as Map,
);

/// Balasan `POST /worksheet-scans` formulir asli — bentuk
/// `WorksheetScanController::bentukHasil()` + `vonisCentang()`/`vonisIsian()`
/// (3222d1b), nilai dari contoh B2. Dipangkas ke satu sel/isian; TH-6
/// dibuat `pilihan_ganda` buat menguji kalimat server.
const _balasanB2 = <String, dynamic>{
  'scan_id': 1,
  'status': 'perlu_review',
  'template': {
    'id': 'ph_meter',
    'versi': 4,
    'kode_dokumen': 'SIDIK-FM-CAL-0509',
  },
  'aturan_versi': 'val-1.0.0+asli-1',
  'ringkasan': {
    'total_sel': 4,
    'hijau': 0,
    'kuning': 3,
    'merah': 1,
    'kosong': 0,
  },
  'tabel': <dynamic>[],
  'boleh_auto_isi': false,
  'wajib_dicek': true,
  'kertas': 'asli',
  'mode_uji': true,
  'isian': [
    {
      'kode': 'suhu_awal',
      'kunci': 'isian|suhu_awal',
      'satuan': '°C',
      'teks_mentah': '25,0',
      'nilai': 25,
      'status': 'kuning',
      'alasan': ['template_belum_terverifikasi'],
      'normalisasi': <String>[],
      'kotak': {'x': 0.54272, 'y': 0.28162, 'w': 0.1279, 'h': 0.01552},
    },
  ],
  'centang': [
    {
      'kunci': 'centang|thermohygro_standard_id|TH-2',
      'kode': 'thermohygro_standard_id',
      'pilihan': 'TH-2',
      'baris_ke': null,
      'label': null,
      'rasio_gelap': 0.4,
      'dicentang': true,
      'nilai': 1,
      'status': 'kuning',
      'alasan': ['template_belum_terverifikasi'],
      'pesan': null,
    },
    {
      'kunci': 'centang|thermohygro_standard_id|TH-6',
      'kode': 'thermohygro_standard_id',
      'pilihan': 'TH-6',
      'baris_ke': null,
      'label': null,
      'rasio_gelap': 0.35,
      'dicentang': true,
      'nilai': 1,
      'status': 'merah',
      'alasan': ['pilihan_ganda'],
      'pesan':
          'Lebih dari satu pilihan tercentang (TH-2, TH-6) — cuma satu yang dipakai. Pilih yang benar secara manual.',
    },
  ],
};
