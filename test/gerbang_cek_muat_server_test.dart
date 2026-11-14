import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_aliran.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_enclosure.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_dimensi.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;
import 'package:sidik_calibration/services/peta_tabel_foto.dart';
import 'package:sidik_calibration/services/verifikasi_sel_service.dart';

/// Draf yang dimuat dari SERVER tidak boleh kehilangan gerbang "wajib dicek".
///
/// Simpan draf online menghapus salinan HP (`_selesaiTersimpanDiServer`), jadi
/// "Lanjutkan draf" di HP yang SAMA memuat dari server. Server sudah menyimpan
/// asal-kamera per baris (`ocr_raw_text`, `is_verified=false`): yang dipulihkan
/// di sini hanya apa yang sudah ada di server, tanpa perubahan API.
void main() {
  const alat = EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
  );

  LembarKerjaState isianBaru() =>
      LembarKerjaState(
          bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
          clientRequestId: 'uji-muat-server',
        )
        ..alat = alat
        ..isiDariAlat();

  TabelHasil tabelSesudah(LembarKerjaState s) => s.bentuk.bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.tahap == 'sesudah_adjustment');

  /// Meniru server: tiap pembacaan di payload jadi satu baris mentah; baris
  /// ber-`ocr[]` lahir `is_verified=false` dengan `ocr_raw_text`.
  List<RawMeasurement> bacaDariPayload(Map<String, dynamic> payload) {
    final baris = <RawMeasurement>[];
    var id = 1;
    var titikKe = 0;

    for (final m in payload['measurements'] as List<dynamic>) {
      titikKe++;
      final titik = m as Map<String, dynamic>;
      final pembacaan = titik['pembacaan'] as List<dynamic>;
      final suhu = titik['suhu'] as List<dynamic>;
      final ocr = (titik['ocr'] as List<dynamic>?) ?? const [];

      for (var i = 0; i < pembacaan.length; i++) {
        if (pembacaan[i] == null) continue;

        final meta = i < ocr.length ? ocr[i] as Map<String, dynamic>? : null;
        baris.add(
          RawMeasurement.fromJson({
            'id': id++,
            'titik_ke': titikKe,
            'titik_ukur': titik['titik_ukur'],
            'pembacaan_ke': i + 1,
            'pembacaan': pembacaan[i],
            'tahap': 'sesudah_adjustment',
            'suhu': suhu[i],
            'input_source': meta == null ? 'manual' : 'ocr',
            'is_verified': meta == null,
            'ocr_raw_text': meta?['raw_text'],
            'ocr_confidence': meta?['confidence'],
          }),
        );
      }
    }

    return baris;
  }

  LembarKerjaState dariFoto() {
    final s = isianBaru();
    s.terapkanHasilFotoTabel(<SelTabelFoto>[
      for (final (t, v) in [(4.0, '4,01'), (7.0, '7,02'), (10.01, '10,00')])
        (
          titikUkur: t,
          repeatNo: 1,
          fieldId: 'pembacaan',
          teks: v,
          keyakinan: 0.99,
        ),
    ], tabel: tabelSesudah(s));

    return s;
  }

  group('muat draf dari server', () {
    test('simpan draf online lalu muat ulang: gerbang tetap', () {
      final a = dariFoto();
      expect(a.jumlahPerluCek, 3, reason: 'prasyarat');

      // Tengah-tengah: teknisi sudah mengecek satu sel sebelum menyimpan draf.
      a.konfirmasiSelCek(a.selCekBerikutnya()!.kunci);
      expect(a.jumlahPerluCek, 2);

      final tersimpan = a.toSubmission(draft: true).toJson();
      final baris = bacaDariPayload(tersimpan);

      // HP yang sama, salinan HP sudah dihapus: lembar baru dari server saja.
      final b = isianBaru();
      final kebuang = b.terapkanPembacaan(baris);

      expect(kebuang, 0);
      expect(
        b.jumlahPerluCek,
        3,
        reason:
            'konfirmasi lama tidak ikut (server tidak menyimpannya): dicek '
            'ulang, arah aman',
      );
      expect(b.adaBacaanKamera, isTrue);
      expect(b.toSubmission(draft: false).toJson()['input_method'], 'ocr');
    });

    test('simpan ulang dari draf yang dimuat tetap membawa ocr[] per sel', () {
      final a = dariFoto();
      final b = isianBaru()
        ..terapkanPembacaan(
          bacaDariPayload(a.toSubmission(draft: true).toJson()),
        );

      final ulang = b.toSubmission(draft: true).toJson();
      final titik7 = (ulang['measurements'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['titik_ukur'] == 7.0);

      expect(titik7['ocr'], isNotNull, reason: 'asal-kamera tidak hilang');
      expect((titik7['ocr'] as List<dynamic>).first['raw_text'], '7,02');
    });

    test(
      'baris ketikan tangan atau yang sudah terverifikasi tidak ditandai',
      () {
        final b = isianBaru();

        b.terapkanPembacaan([
          RawMeasurement.fromJson({
            'id': 1,
            'titik_ke': 1,
            'titik_ukur': 7.0,
            'pembacaan_ke': 1,
            'pembacaan': 7.01,
            'input_source': 'manual',
            'is_verified': true,
          }),
          RawMeasurement.fromJson({
            'id': 2,
            'titik_ke': 1,
            'titik_ukur': 7.0,
            'pembacaan_ke': 2,
            'pembacaan': 7.02,
            'input_source': 'ocr',
            'is_verified': true, // sudah dikonfirmasi teknisi sebelumnya
            'ocr_raw_text': '7.02',
          }),
        ]);

        expect(b.jumlahPerluCek, 0);
        expect(b.adaBacaanKamera, isFalse);
      },
    );

    test('sel yang sudah diketik teknisi tidak ditimpa dan tidak ditandai', () {
      final b = isianBaru();
      b.titik[7.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '7,5';

      b.terapkanPembacaan([
        RawMeasurement.fromJson({
          'id': 1,
          'titik_ke': 1,
          'titik_ukur': 7.0,
          'pembacaan_ke': 1,
          'pembacaan': 7.02,
          'input_source': 'ocr',
          'is_verified': false,
          'ocr_raw_text': '7.02',
        }),
      ]);

      expect(b.jumlahPerluCek, 0);
    });

    test(
      'draf lama tanpa field baru dari server: tidak crash, tidak ditandai',
      () {
        final baris = RawMeasurement.fromJson({
          'id': 1,
          'titik_ke': 1,
          'titik_ukur': '7.00000000',
          'pembacaan_ke': 1,
          'pembacaan': 7.02,
        });

        expect(baris.ocrRawText, isNull);
        expect(baris.dariKameraBelumDicek, isFalse);

        final b = isianBaru();
        expect(() => b.terapkanPembacaan([baris]), returnsNormally);
        expect(b.jumlahPerluCek, 0);
      },
    );

    test('RawMeasurement membaca ocr_raw_text dan ocr_confidence', () {
      final baris = RawMeasurement.fromJson({
        'id': 1,
        'titik_ke': 1,
        'titik_ukur': 7,
        'pembacaan_ke': 1,
        'pembacaan': 7.02,
        'is_verified': false,
        'ocr_raw_text': '7.02',
        'ocr_confidence': '0.42',
      });

      expect(baris.ocrRawText, '7.02');
      expect(baris.ocrConfidence, 0.42);
      expect(baris.dariKameraBelumDicek, isTrue);
    });
  });

  // ----------------------------------------- pasangan, grid, dan deret bernama

  group('muat dari server: lembar berpasangan, grid, deret bernama', () {
    int teksKe = 0;
    String teksUnik() => '${20 + (teksKe++)},5';

    /// Isi SEMUA sel (repeat pertama) lewat alamat posisi.
    void isiSemua(LembarKerjaState s) {
      final semua = [for (final b in s.bentuk.bagian) ...b.tabel];
      String idTabel(TabelHasil t) {
        final dasar = t.grup ?? t.tahap;
        final kembar =
            semua.where((o) => (o.grup ?? o.tahap) == dasar).length > 1;

        return kembar ? '${dasar}_${t.tahap}' : dasar;
      }

      s.terapkanHasilFotoAsli([
        for (final t in semua)
          for (var i = 0; i < s.barisTabel(t).length; i++)
            for (final k in t.kolom)
              (
                tabelId: idTabel(t),
                tahap: t.tahap,
                barisKe: i + 1,
                repeatNo: t.pengulangan.first,
                fieldId: k.kode,
                teks: teksUnik(),
                keyakinan: 0.99,
              ),
      ]);
    }

    LembarKerjaState baru(Map<String, dynamic> json) =>
        LembarKerjaState(
            bentuk: LembarKerja.fromJson(json),
            clientRequestId: 'uji-server-lain',
          )
          ..alat = alat
          ..isiDariAlat();

    test('pasangan (Thermocouple): standar dan UUT ditandai lagi', () {
      final a = baru(contohBentukLembarKerjaThermocouple());
      addTearDown(a.dispose);
      isiSemua(a);
      expect(a.jumlahPerluCek, greaterThan(0), reason: 'prasyarat');

      // Meniru server: tiap deret `standar` / `uut` jadi baris mentah; yang
      // ber-`*_ocr` lahir belum terverifikasi dengan `ocr_raw_text`.
      final payload = a.toSubmission(draft: true).toJson();
      final baris = <RawMeasurement>[];
      var id = 1;
      var titikKe = 0;

      for (final m in payload['measurements'] as List<dynamic>) {
        titikKe++;
        final titik = m as Map<String, dynamic>;

        for (final peran in ['standar', 'uut']) {
          final nilai = (titik[peran] as List<dynamic>?) ?? const [];
          final ocr = (titik['${peran}_ocr'] as List<dynamic>?) ?? const [];

          for (var i = 0; i < nilai.length; i++) {
            if (nilai[i] == null) continue;

            final meta = i < ocr.length
                ? ocr[i] as Map<String, dynamic>?
                : null;
            baris.add(
              RawMeasurement.fromJson({
                'id': id++,
                'titik_ke': titikKe,
                'titik_ukur': titik['titik_ukur'],
                'pembacaan_ke': i + 1,
                'pembacaan': nilai[i],
                'peran_sensor': peran,
                'satuan': titik['satuan'],
                'input_source': meta == null ? 'manual' : 'ocr',
                'is_verified': meta == null,
                'ocr_raw_text': meta?['raw_text'],
              }),
            );
          }
        }
      }

      final dariKamera = baris.where((b) => b.dariKameraBelumDicek).length;
      expect(dariKamera, a.jumlahPerluCek, reason: 'prasyarat: baris server');

      final b = baru(contohBentukLembarKerjaThermocouple());
      addTearDown(b.dispose);

      expect(
        b.terapkanPembacaan(baris),
        0,
        reason: 'tidak ada baris yang hilang',
      );
      expect(b.jumlahPerluCek, dariKamera);
      expect(b.adaBacaanKamera, isTrue);
    });

    test(
      'grid (Oven): pembacaan, indikator, dan nomor termokopel ditandai',
      () {
        final b = baru(contohBentukLembarKerjaOven());
        addTearDown(b.dispose);

        Map<String, dynamic> baris(
          int id,
          String peran,
          int ke, {
          int? sensor,
          bool kamera = true,
        }) => {
          'id': id,
          'titik_ke': 1,
          'titik_ukur': 100,
          'pembacaan_ke': ke,
          'pembacaan': 100 + ke / 10,
          'peran_sensor': peran,
          'sensor_ke': ?sensor,
          'input_source': kamera ? 'ocr' : 'manual',
          'is_verified': !kamera,
          'ocr_raw_text': kamera ? '${100 + ke / 10}' : null,
        };

        final rows = [
          for (var k = 1; k <= 3; k++)
            RawMeasurement.fromJson(baris(k, 'termokopel', k, sensor: 1)),
          for (var k = 1; k <= 3; k++)
            RawMeasurement.fromJson(baris(10 + k, 'termokopel', k, sensor: 2)),
          for (var k = 1; k <= 2; k++)
            RawMeasurement.fromJson(baris(20 + k, 'indikator', k)),
          // Termokopel 3 ketikan tangan: tidak boleh ikut ditandai.
          for (var k = 1; k <= 3; k++)
            RawMeasurement.fromJson(
              baris(30 + k, 'termokopel', k, sensor: 3, kamera: false),
            ),
        ];

        expect(b.terapkanPembacaan(rows), 0);

        final daftar = b.daftarSelCek();
        final termokopel = daftar.where(
          (s) => s.peranGrid == PeranSelGrid.termokopel,
        );
        final indikator = daftar.where(
          (s) => s.peranGrid == PeranSelGrid.indikator,
        );
        final nomor = daftar.where(
          (s) => s.peranGrid == PeranSelGrid.nomorTermokopel,
        );

        expect(termokopel.length, 6);
        expect(indikator.length, 2);
        expect(
          nomor.length,
          2,
          reason:
              'nomor termokopel 1 dan 2 (dari foto), bukan 3 (ketikan tangan)',
        );
        expect(b.jumlahPerluCek, 10);
        expect(b.adaBacaanKamera, isTrue);
      },
    );

    test('deret bernama: sel yang dimuat dari baris kamera ditandai lagi', () {
      var diuji = 0;

      for (final json in [
        contohBentukLembarKerjaAnakTimbangan,
        contohBentukLembarKerjaJangkaSorong,
        contohBentukLembarKerjaFlowmeterTotalizer,
      ]) {
        final a = baru(json());
        addTearDown(a.dispose);

        final tabel = a.tabelDeretBernama.where((t) => t.kolom.length == 1);
        if (tabel.isEmpty) continue;

        isiSemua(a);

        final rows = <RawMeasurement>[];
        var id = 1;
        for (final t in tabel) {
          final peran = t.simpanKe!.substring('measurements[].'.length);
          final barisT = a.barisTabel(t);

          for (var i = 0; i < barisT.length; i++) {
            final st = a.titikUntukBaris(barisT, i, t);
            if (st == null) continue;

            for (var r = 0; r < t.pengulangan.length; r++) {
              final isi = st.teksKotakJikaAda(
                t.kunciTabel,
                t.kolom.first.kode,
                r,
              );
              final angka = double.tryParse((isi ?? '').replaceAll(',', '.'));
              if (angka == null) continue;

              rows.add(
                RawMeasurement.fromJson({
                  'id': id++,
                  'titik_ke': i + 1,
                  'titik_ukur': st.titikUkur,
                  'pembacaan_ke': r + 1,
                  'pembacaan': angka,
                  'peran_sensor': peran,
                  'input_source': 'ocr',
                  'is_verified': false,
                  'ocr_raw_text': isi,
                }),
              );
            }
          }
        }
        if (rows.isEmpty) continue;

        final b = baru(json());
        addTearDown(b.dispose);
        b.terapkanPembacaan(rows);

        expect(
          b.jumlahPerluCek,
          greaterThan(0),
          reason: 'baris kamera belum dicek harus kembali digerbang',
        );
        diuji++;
      }

      expect(
        diuji,
        greaterThan(0),
        reason: 'minimal satu bentuk bernama teruji',
      );
    });
  });

  group('ApiVerifikasiSelService: badan HTTP', () {
    test(
      'mengirim measurement_ids eksplisit ke jalur verify sesi itu',
      () async {
        final klien = _KlienRekam();
        final layanan = ApiVerifikasiSelService(
          ApiClient(client: klien, baseUrl: 'http://uji'),
        );

        await layanan.verifikasi('token-uji', 7, [11, 13]);

        expect(klien.permintaan, hasLength(1));
        final p = klien.permintaan.single;
        expect(p.method, 'POST');
        expect(p.url.path, endsWith('/calibrations/7/measurements/verify'));
        expect(
          jsonDecode(klien.badan.single),
          {
            'measurement_ids': [11, 13],
          },
          reason: 'badan kosong = "semua" di server; tidak boleh terjadi',
        );
      },
    );

    test('daftar id kosong ditolak SEBELUM menyentuh jaringan', () async {
      final klien = _KlienRekam();
      final layanan = ApiVerifikasiSelService(
        ApiClient(client: klien, baseUrl: 'http://uji'),
      );

      await expectLater(
        layanan.verifikasi('token-uji', 7, const []),
        throwsArgumentError,
      );
      expect(klien.permintaan, isEmpty);
    });
  });
}

class _KlienRekam extends http.BaseClient {
  final List<http.BaseRequest> permintaan = [];
  final List<String> badan = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    permintaan.add(request);
    if (request is http.Request) badan.add(request.body);

    return http.StreamedResponse(
      Stream.value('{"data":{"id":7}}'.codeUnits),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
