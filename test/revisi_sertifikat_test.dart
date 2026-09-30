import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/screens/certificate/revisi_sertifikat_screen.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Revisi & pembatalan sertifikat, sisi LAB (kontrak A1–A3, 1 Okt 2026).
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
///
/// ## Yang dijaga
///
/// - **Field baru boleh hilang** (server lama): model tidak melempar, lencana
///   diturunkan dari `status`, dan tak ada tombol apa pun.
/// - **Siapa melihat tombol apa.** Hanya admin, dan hanya kalau server bilang
///   `bisa_direvisi` / `bisa_dibatalkan`. Super admin, teknisi, dan viewer tidak.
/// - **Revisi mengirim HANYA kunci yang berubah**, menolak "tidak ada yang
///   berubah" dan `berlaku_sampai` sebelum `tanggal_kalibrasi` sebelum sampai
///   server, dan menampilkan 422 per kolom.
/// - **Batal bergaya merusak**, menampilkan dampak jadwal, dan menahan dialog
///   tetap terbuka saat server menolak.
const _admin = 'mock-token-1';
const _teknisi = 'mock-token-2';
const _superAdmin = 'mock-token-5';

List<Override> _semua({
  required MockCertificateService service,
  String token = _admin,
}) => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  certificateServiceProvider.overrideWithValue(service),
];

Widget _app(
  Widget layar, {
  required MockCertificateService service,
  String token = _admin,
}) => ProviderScope(
  overrides: _semua(service: service, token: token),
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: layar,
  ),
);

Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<CertificateDetail> _dasar({bool aksi = false}) =>
    MockCertificateService(bolehAksi: aksi).detail('t', 1);

void main() {
  group('model', () {
    test('fromJson membaca semua field baru kontrak A1', () {
      final c = CertificateDetail.fromJson(
        jsonDecode('''
{
  "id": 44, "nomor": "CAL/2026/09/0007-R1", "status": "terbit",
  "status_dokumen": "berlaku", "revisi_ke": 1,
  "revisi_dari": {"id": 30, "nomor": "CAL/2026/09/0007"},
  "digantikan_oleh": {"id": 51, "nomor": "CAL/2026/09/0007-R2", "status": "menunggu_generate"},
  "alasan_revisi": "Salah ketik nomor seri",
  "dibatalkan_pada": "2026-10-01T02:15:00Z",
  "dibatalkan_oleh": {"id": 2, "nama": "Hendra Wijaya"},
  "alasan_pembatalan": "Data alat keliru",
  "catatan_pelanggan": "Nomor seri diperbaiki.",
  "bisa_direvisi": true, "bisa_dibatalkan": true,
  "pdf_url": "https://x/api/certificates/44/download",
  "data_cetak": {"pemilik": "PT Contoh Jaya", "alamat": "Jl. Contoh 1",
    "merk": "Hanna", "tipe": "HI2211", "nomor_seri": "HI2211-0419",
    "lokasi_kalibrasi": "Lab", "tanggal_kalibrasi": "2026-09-24",
    "berlaku_sampai": "2027-09-24"},
  "dampak_pembatalan": {"jadwal_dikosongkan": false,
    "jatuh_ke": {"id": 30, "nomor": "CAL/2026/09/0007", "berlaku_sampai": "2027-01-10"}}
}''')
            as Map<String, dynamic>,
      );

      expect(c.statusDokumen, StatusDokumen.berlaku);
      expect(c.revisiKe, 1);
      expect(c.adalahRevisi, isTrue);
      expect(c.revisiDari!.nomor, 'CAL/2026/09/0007');
      expect(c.digantikanOleh!.status, 'menunggu_generate');
      expect(c.digantikanOleh!.masihDiproses, isTrue);
      expect(c.dibatalkanOleh, 'Hendra Wijaya');
      expect(c.dibatalkanPada, DateTime.utc(2026, 10, 1, 2, 15));
      expect(c.bisaDirevisi, isTrue);
      expect(c.dataCetak![KunciDataCetak.nomorSeri], 'HI2211-0419');
      expect(c.dampakPembatalan!.jadwalDikosongkan, isFalse);
      expect(c.dampakPembatalan!.jatuhKe!.berlakuSampai, '2027-01-10');
    });

    test('server lama tanpa field baru: tidak melempar, bawaan aman', () {
      final terbit = CertificateDetail.fromJson(const {
        'id': 1,
        'nomor': 'CAL/1',
        'status': 'terbit',
      });
      expect(terbit.statusDokumen, StatusDokumen.berlaku);
      expect(terbit.revisiKe, 0);
      expect(terbit.adalahRevisi, isFalse);
      expect(terbit.bisaDirevisi, isFalse);
      expect(terbit.bisaDibatalkan, isFalse);
      expect(terbit.dataCetak, isNull);
      expect(terbit.digantikanOleh, isNull);

      final menunggu = CertificateDetail.fromJson(const {
        'id': 2,
        'nomor': 'CAL/2',
        'status': 'menunggu_generate',
      });
      expect(menunggu.statusDokumen, StatusDokumen.belumTerbit);

      final batal = CertificateDetail.fromJson(const {
        'id': 3,
        'nomor': 'CAL/3',
        'status': 'dibatalkan',
      });
      expect(batal.statusDokumen, StatusDokumen.dibatalkan);
      // Arsip lab tetap bisa diunduh walau dibatalkan.
      expect(batal.bisaUnduh, isTrue);
      expect(batal.siap, isFalse);
    });

    test('nilai aneh (null / bentuk salah) tidak melempar', () {
      final c = CertificateDetail.fromJson(const {
        'id': 1,
        'nomor': 'CAL/1',
        'status': 'terbit',
        'status_dokumen': 'kode-baru',
        'revisi_dari': 'bukan objek',
        'digantikan_oleh': {'nomor': 'tanpa id'},
        'data_cetak': [],
        'dibatalkan_oleh': 7,
      });
      expect(c.revisiDari, isNull);
      expect(c.digantikanOleh, isNull);
      expect(c.dataCetak, isNull);
      expect(c.dibatalkanOleh, isNull);
      // Kode asing → turunan dari `status`.
      expect(c.statusDokumen, StatusDokumen.berlaku);
    });

    test('GalatAksi memilah errors per kunci', () {
      final g = GalatAksi.dariBody('m', {
        'errors': {
          'perubahan.nomor_seri': ['bentrok'],
          'alasan': 'wajib',
        },
      });
      expect(g.untuk('perubahan.nomor_seri'), 'bentrok');
      expect(g.untuk('alasan'), 'wajib');
      expect(g.adaGalatIsian, isTrue);
      expect(GalatAksi.dariBody('m', const {}).adaGalatIsian, isFalse);
    });
  });

  group('ApiCertificateService', () {
    (ApiCertificateService, List<http.Request>) buat(
      http.Response Function(http.Request) jawab,
    ) {
      final rekam = <http.Request>[];
      final client = MockClient((r) async {
        rekam.add(r);
        return jawab(r);
      });
      return (
        ApiCertificateService(
          ApiClient(client: client, baseUrl: 'http://x/api'),
          baseUrl: 'http://x/api',
        ),
        rekam,
      );
    }

    http.Response json(Object o, [int kode = 200]) => http.Response(
      jsonEncode(o),
      kode,
      headers: {'content-type': 'application/json'},
    );

    test('revisi: POST /revisi, 202 membawa baris revisi baru', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'message': 'Revisi sedang diterbitkan.',
          'data': {
            'id': 51,
            'nomor': 'CAL/2026/09/0011-R1',
            'status': 'menunggu_generate',
            'revisi_ke': 1,
          },
        }, 202),
      );

      final hasil = await svc.revisi(
        't',
        41,
        perubahan: {'nomor_seri': 'HI2211-0419'},
        alasan: '  Salah ketik  ',
        catatanPelanggan: '   ',
      );

      expect(rekam.single.method, 'POST');
      expect(rekam.single.url.path, '/api/certificates/41/revisi');
      final badan = jsonDecode(rekam.single.body) as Map<String, dynamic>;
      expect(badan['perubahan'], {'nomor_seri': 'HI2211-0419'});
      expect(badan['alasan'], 'Salah ketik');
      // Catatan kosong tidak dikirim.
      expect(badan.containsKey('catatan_pelanggan'), isFalse);
      expect(hasil.nomor, 'CAL/2026/09/0011-R1');
      expect(hasil.status, 'menunggu_generate');
    });

    test('revisi: 422 validasi jadi GalatAksi dengan errors per kunci', () async {
      final (svc, _) = buat(
        (_) => json({
          'message': 'Data yang dikirim tidak valid.',
          'errors': {
            'perubahan.nomor_seri': ['Nomor seri sudah dipakai.'],
          },
        }, 422),
      );

      await expectLater(
        svc.revisi('t', 41, perubahan: {'nomor_seri': 'X'}, alasan: 'a'),
        throwsA(
          isA<GalatAksi>().having(
            (e) => e.untuk('perubahan.nomor_seri'),
            'pesan',
            'Nomor seri sudah dipakai.',
          ),
        ),
      );
    });

    test('revisi: 422 {message} tanpa errors = galat keadaan', () async {
      final (svc, _) = buat(
        (_) => json({'message': 'Sertifikat sudah digantikan.'}, 422),
      );

      await expectLater(
        svc.revisi('t', 41, perubahan: {'merk': 'X'}, alasan: 'a'),
        throwsA(
          isA<GalatAksi>()
              .having((e) => e.pesan, 'pesan', 'Sertifikat sudah digantikan.')
              .having((e) => e.adaGalatIsian, 'adaGalatIsian', isFalse),
        ),
      );
    });

    test('batalkan: POST /batalkan membawa alasan & catatan', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'message': 'Dibatalkan.',
          'data': {
            'id': 41,
            'nomor': 'CAL/2026/09/0011',
            'status': 'dibatalkan',
            'status_dokumen': 'dibatalkan',
          },
        }),
      );

      final hasil = await svc.batalkan(
        't',
        41,
        alasan: 'Data alat keliru',
        catatanPelanggan: 'Mohon abaikan sertifikat ini.',
      );

      expect(rekam.single.url.path, '/api/certificates/41/batalkan');
      final badan = jsonDecode(rekam.single.body) as Map<String, dynamic>;
      expect(badan['alasan'], 'Data alat keliru');
      expect(badan['catatan_pelanggan'], 'Mohon abaikan sertifikat ini.');
      expect(hasil.statusDokumen, StatusDokumen.dibatalkan);
    });

    test('403 (bukan admin) tidak diubah jadi galat validasi', () async {
      final (svc, _) = buat(
        (_) => json({'message': 'Kamu nggak punya akses ke sini.'}, 403),
      );
      await expectLater(
        svc.batalkan('t', 41, alasan: 'a'),
        throwsA(isNot(isA<GalatAksi>())),
      );
    });
  });

  group('detail sertifikat: status dokumen', () {
    testWidgets('berlaku: lencana Berlaku tanpa tombol (server lama)', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const SertifikatScreen(certificateId: 1),
          service: MockCertificateService(),
        ),
      );

      expect(find.byKey(const ValueKey('info-dokumen-sertifikat')), findsOne);
      expect(find.text('Berlaku'), findsOneWidget);
      expect(find.byKey(const ValueKey('tindakan-admin-sertifikat')), findsNothing);
    });

    testWidgets(
      'digantikan: tautan ke revisi + statusnya bila masih diproses',
      (tester) async {
        final dasar = await _dasar();
        final svc = MockCertificateService(
          khusus: {
            1: dasar.salin(
              statusDokumenKode: 'digantikan',
              digantikanOleh: const RujukanSertifikat(
                id: 900,
                nomor: '012-CAL-524-R1',
                status: 'menunggu_generate',
              ),
            ),
          },
        );
        await _pasang(
          tester,
          _app(const SertifikatScreen(certificateId: 1), service: svc),
        );

        expect(find.text('Digantikan'), findsOneWidget);
        expect(find.text('012-CAL-524-R1'), findsOneWidget);
        // Revisi yang belum terbit ikut tampil bersama statusnya.
        expect(find.text('Sedang dibuat'), findsOneWidget);

        // Mengetuk tautan membuka sertifikat penggantinya.
        await tester.tap(find.byKey(const ValueKey('tautan-digantikan-oleh')));
        await tester.pumpAndSettle();
        expect(
          find.byType(SertifikatScreen, skipOffstage: false),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('revisi: "Revisi ke-1 · menggantikan <nomor>" + tautan', (
      tester,
    ) async {
      final dasar = await _dasar();
      final svc = MockCertificateService(
        khusus: {
          1: dasar.salin(
            revisiKe: 1,
            revisiDari: const RujukanSertifikat(id: 7, nomor: '012-CAL-523'),
            alasanRevisi: 'Salah ketik nomor seri',
            catatanPelanggan: 'Nomor seri diperbaiki.',
          ),
        },
      );
      await _pasang(
        tester,
        _app(const SertifikatScreen(certificateId: 1), service: svc),
      );

      expect(find.textContaining('Revisi ke-1'), findsOneWidget);
      expect(find.textContaining('menggantikan'), findsOneWidget);
      expect(find.text('012-CAL-523'), findsOneWidget);
      expect(find.text('Salah ketik nomor seri'), findsOneWidget);
      expect(find.text('Nomor seri diperbaiki.'), findsOneWidget);
    });

    testWidgets('dibatalkan: tanggal, oleh, alasan internal, catatan; PDF tetap', (
      tester,
    ) async {
      final dasar = await _dasar();
      final svc = MockCertificateService(
        khusus: {
          1: dasar.salin(
            status: 'dibatalkan',
            statusDokumenKode: 'dibatalkan',
            dibatalkanPada: DateTime.utc(2026, 10, 1, 5),
            dibatalkanOleh: 'Hendra Wijaya',
            alasanPembatalan: 'Data alat keliru',
            catatanPelanggan: 'Mohon abaikan sertifikat ini.',
          ),
        },
      );
      await _pasang(
        tester,
        _app(const SertifikatScreen(certificateId: 1), service: svc),
      );

      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(find.text('Hendra Wijaya'), findsOneWidget);
      expect(find.text('Data alat keliru'), findsOneWidget);
      expect(find.text('Mohon abaikan sertifikat ini.'), findsOneWidget);
      expect(find.textContaining('1 Okt 2026'), findsOneWidget);
      // Arsip lab: bilah unduh tetap ada.
      expect(find.text('PDF'), findsOneWidget);
    });
  });

  group('tombol admin di detail sertifikat', () {
    testWidgets('admin + bisa_direvisi/dibatalkan: dua tombol muncul', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const SertifikatScreen(certificateId: 1),
          service: MockCertificateService(bolehAksi: true),
        ),
      );

      expect(find.byKey(const ValueKey('tombol-revisi-sertifikat')), findsOne);
      expect(find.byKey(const ValueKey('tombol-batal-sertifikat')), findsOne);
      expect(find.text('Revisi sertifikat'), findsOneWidget);
      expect(find.text('Batalkan sertifikat'), findsOneWidget);
    });

    testWidgets('admin tapi server tidak mengizinkan: tidak ada tombol', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const SertifikatScreen(certificateId: 1),
          service: MockCertificateService(),
        ),
      );
      expect(find.byKey(const ValueKey('tombol-revisi-sertifikat')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-batal-sertifikat')), findsNothing);
    });

    testWidgets('teknisi tidak melihat tombol walau server mengizinkan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const SertifikatScreen(certificateId: 1),
          service: MockCertificateService(bolehAksi: true),
          token: _teknisi,
        ),
      );
      expect(find.byKey(const ValueKey('tindakan-admin-sertifikat')), findsNothing);
    });

    testWidgets('super admin membaca saja: tidak ada tombol', (tester) async {
      await _pasang(
        tester,
        _app(
          const SertifikatScreen(certificateId: 1),
          service: MockCertificateService(bolehAksi: true),
          token: _superAdmin,
        ),
      );
      expect(find.byKey(const ValueKey('tindakan-admin-sertifikat')), findsNothing);
      // Kartu status tetap terbaca.
      expect(find.byKey(const ValueKey('info-dokumen-sertifikat')), findsOne);
    });

    testWidgets('data_cetak kosong: revisi tidak ditawarkan, batal tetap', (
      tester,
    ) async {
      final dasar = await _dasar(aksi: true);
      final svc = MockCertificateService(
        khusus: {
          1: CertificateDetail(
            id: 1,
            nomor: dasar.nomor,
            status: 'terbit',
            snapshot: dasar.snapshot,
            pdfUrl: dasar.pdfUrl,
            bisaDirevisi: true,
            bisaDibatalkan: true,
          ),
        },
      );
      await _pasang(
        tester,
        _app(const SertifikatScreen(certificateId: 1), service: svc),
      );
      expect(find.byKey(const ValueKey('tombol-revisi-sertifikat')), findsNothing);
      expect(find.textContaining('belum bisa direvisi'), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-batal-sertifikat')), findsOne);
    });
  });

  group('formulir revisi', () {
    Future<MockCertificateService> buka(
      WidgetTester tester, {
      CertificateDetail? sertifikat,
    }) async {
      final svc = MockCertificateService(bolehAksi: true);
      final s = sertifikat ?? await svc.detail('t', 1);
      await _pasang(tester, _app(RevisiSertifikatScreen(sertifikat: s), service: svc));
      return svc;
    }

    Future<void> ketik(WidgetTester tester, String kunci, String teks) async {
      await tester.enterText(find.byKey(ValueKey('isian-revisi-$kunci')), teks);
      await tester.pump();
    }

    Future<void> kirim(WidgetTester tester) async {
      final tombol = find.byKey(const ValueKey('kirim-revisi-sertifikat'));
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.pumpAndSettle();
    }

    testWidgets('diisi dari data_cetak: delapan isian', (tester) async {
      await buka(tester);

      expect(find.widgetWithText(TextField, 'PT TIRTA CONTOH MANDIRI'), findsOne);
      expect(find.widgetWithText(TextField, 'B628755900'), findsOne);
      expect(find.widgetWithText(TextField, 'Mettler Toledo'), findsOne);
      // Dua tanggal lewat pemilih tanggal, bukan ketikan bebas.
      expect(find.byKey(const ValueKey('isian-revisi-tanggal_kalibrasi')), findsOne);
      expect(find.byKey(const ValueKey('isian-revisi-berlaku_sampai')), findsOne);
      expect(find.textContaining('26 Mei 2024'), findsOneWidget);
    });

    testWidgets('tanpa perubahan: ditolak di klien, tidak ke server', (
      tester,
    ) async {
      final svc = await buka(tester);
      await ketik(tester, 'alasan', 'Salah ketik');
      await kirim(tester);

      expect(find.byKey(const ValueKey('banner-revisi')), findsOneWidget);
      expect(find.textContaining('Tidak ada yang berubah'), findsOneWidget);
      expect(svc.direvisiDengan, isEmpty);
    });

    testWidgets('alasan wajib', (tester) async {
      final svc = await buka(tester);
      await ketik(tester, 'merk', 'Hanna');
      await kirim(tester);

      expect(find.text('Alasan revisi wajib diisi.'), findsOneWidget);
      expect(svc.direvisiDengan, isEmpty);
    });

    testWidgets('isian teks yang dikosongkan ditolak', (tester) async {
      final svc = await buka(tester);
      await ketik(tester, 'tipe', '');
      await ketik(tester, 'alasan', 'Alasan');
      await kirim(tester);

      expect(find.text('Isian ini tidak boleh dikosongkan.'), findsOneWidget);
      expect(svc.direvisiDengan, isEmpty);
    });

    testWidgets('berlaku_sampai harus sesudah tanggal_kalibrasi', (
      tester,
    ) async {
      final svc = MockCertificateService(bolehAksi: true);
      final dasar = await svc.detail('t', 1);
      final s = dasar.salin(
        dataCetak: const DataCetak({
          KunciDataCetak.pemilik: 'PT Contoh Jaya',
          KunciDataCetak.tanggalKalibrasi: '2026-06-20',
          KunciDataCetak.berlakuSampai: '2026-06-25',
        }),
      );
      await _pasang(tester, _app(RevisiSertifikatScreen(sertifikat: s), service: svc));

      // Mundurkan berlaku_sampai ke 10 Juni 2026 (< tanggal kalibrasi).
      await tester.tap(find.byKey(const ValueKey('isian-revisi-berlaku_sampai')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('10'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(DatePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();

      await ketik(tester, 'alasan', 'Salah tanggal');
      await kirim(tester);

      expect(find.text('Harus sesudah tanggal kalibrasi.'), findsOneWidget);
      expect(svc.direvisiDengan, isEmpty);
    });

    testWidgets('mengirim hanya kunci yang berubah, lalu membuka revisi baru', (
      tester,
    ) async {
      final svc = await buka(tester);
      await ketik(tester, 'nomor_seri', 'B628755999');
      await ketik(tester, 'alasan', 'Salah ketik nomor seri');
      await ketik(tester, 'catatan', 'Nomor seri diperbaiki.');
      await kirim(tester);

      expect(svc.direvisiDengan, hasLength(1));
      final kiriman = svc.direvisiDengan.single;
      expect(kiriman.perubahan, {'nomor_seri': 'B628755999'});
      expect(kiriman.alasan, 'Salah ketik nomor seri');
      expect(kiriman.catatan, 'Nomor seri diperbaiki.');

      // Formulir diganti sertifikat revisi yang baru lahir (id 1001).
      expect(find.byType(RevisiSertifikatScreen), findsNothing);
      expect(find.byType(SertifikatScreen), findsOneWidget);
      expect(find.textContaining('012-CAL-524-R1'), findsWidgets);
      expect(find.textContaining('sedang diterbitkan'), findsOneWidget);
    });

    testWidgets('422 per kolom: pesan di bawah kolomnya, formulir tetap', (
      tester,
    ) async {
      final svc = await buka(tester);
      await ketik(tester, 'nomor_seri', MockCertificateService.serialDitolak);
      await ketik(tester, 'alasan', 'Salah ketik');
      await kirim(tester);

      expect(find.text('Nomor seri ini tidak boleh dipakai.'), findsOneWidget);
      expect(find.byType(RevisiSertifikatScreen), findsOneWidget);
      // Isiannya tidak hilang.
      expect(
        find.widgetWithText(TextField, MockCertificateService.serialDitolak),
        findsOneWidget,
      );
      expect(svc.direvisiDengan, isEmpty);
    });

    testWidgets('422 {message} (galat keadaan) tampil di banner atas', (
      tester,
    ) async {
      final svc = _RevisiDitolak();
      final s = await svc.detail('t', 1);
      await _pasang(tester, _app(RevisiSertifikatScreen(sertifikat: s), service: svc));
      await ketik(tester, 'merk', 'Hanna');
      await ketik(tester, 'alasan', 'Salah ketik');
      await kirim(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('banner-revisi')),
          matching: find.text('Sertifikat ini sudah digantikan.'),
        ),
        findsOneWidget,
      );
    });
  });

  group('dialog batal', () {
    Future<MockCertificateService> bukaDialog(
      WidgetTester tester, {
      DampakPembatalan? dampak,
      MockCertificateService? service,
      String token = _admin,
    }) async {
      final svc = service ?? MockCertificateService(bolehAksi: true, dampak: dampak);
      await _pasang(
        tester,
        _app(const SertifikatScreen(certificateId: 1), service: svc, token: token),
      );
      final tombol = find.byKey(const ValueKey('tombol-batal-sertifikat'));
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.pumpAndSettle();
      return svc;
    }

    testWidgets('satu-satunya sertifikat sah: peringatan jadwal dikosongkan', (
      tester,
    ) async {
      await bukaDialog(
        tester,
        dampak: const DampakPembatalan(jadwalDikosongkan: true),
      );

      expect(find.byKey(const ValueKey('dialog-batal-sertifikat')), findsOne);
      expect(
        find.byKey(const ValueKey('peringatan-jadwal-dikosongkan')),
        findsOneWidget,
      );
      expect(find.textContaining('dikosongkan'), findsOneWidget);
    });

    testWidgets('ada sertifikat sebelumnya: info jatuh_ke, bukan peringatan', (
      tester,
    ) async {
      await bukaDialog(
        tester,
        dampak: const DampakPembatalan(
          jatuhKe: RujukanSertifikat(
            id: 7,
            nomor: '012-CAL-523',
            berlakuSampai: '2027-01-10',
          ),
        ),
      );

      expect(find.byKey(const ValueKey('info-jatuh-ke')), findsOneWidget);
      expect(find.textContaining('012-CAL-523'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('peringatan-jadwal-dikosongkan')),
        findsNothing,
      );
    });

    testWidgets('alasan wajib: tanpa alasan tidak ada panggilan', (tester) async {
      final svc = await bukaDialog(tester);
      await tester.tap(find.byKey(const ValueKey('kirim-batal-sertifikat')));
      await tester.pumpAndSettle();

      expect(find.text('Alasan pembatalan wajib diisi.'), findsOneWidget);
      expect(svc.dibatalkanDengan, isEmpty);
      expect(find.byKey(const ValueKey('dialog-batal-sertifikat')), findsOne);
    });

    testWidgets('berhasil: dialog menutup, sertifikat jadi Dibatalkan', (
      tester,
    ) async {
      final svc = await bukaDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('isian-batal-alasan')),
        'Data alat keliru',
      );
      await tester.enterText(
        find.byKey(const ValueKey('isian-batal-catatan')),
        'Mohon abaikan sertifikat ini.',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-batal-sertifikat')));
      await tester.pumpAndSettle();

      expect(svc.dibatalkanDengan.single.alasan, 'Data alat keliru');
      expect(svc.dibatalkanDengan.single.catatan, 'Mohon abaikan sertifikat ini.');
      expect(find.byKey(const ValueKey('dialog-batal-sertifikat')), findsNothing);
      expect(find.text('Dibatalkan'), findsOneWidget);
      // Tombol admin hilang: `bisa_dibatalkan` sudah false.
      expect(find.byKey(const ValueKey('tombol-batal-sertifikat')), findsNothing);
    });

    testWidgets('422 {message}: dialog tetap terbuka dan menjelaskan', (
      tester,
    ) async {
      await bukaDialog(tester, service: _BatalDitolak());
      await tester.enterText(
        find.byKey(const ValueKey('isian-batal-alasan')),
        'Data alat keliru',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-batal-sertifikat')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog-batal-sertifikat')), findsOne);
      expect(find.text('Sertifikat ini sudah digantikan.'), findsOneWidget);
      // Isiannya tidak hilang.
      expect(find.widgetWithText(TextField, 'Data alat keliru'), findsOneWidget);
    });
  });

  test('sertifikatAksiProvider menyegarkan detail sesudah batal', () async {
    final svc = MockCertificateService(bolehAksi: true);
    final container = ProviderContainer(
      overrides: _semua(service: svc),
    );
    addTearDown(container.dispose);
    container.listen(certificateDetailProvider(1), (_, _) {});

    final sebelum = await container.read(certificateDetailProvider(1).future);
    expect(sebelum.bisaDibatalkan, isTrue);

    await container
        .read(sertifikatAksiProvider)
        .batalkan(1, alasan: 'Data alat keliru');
    final sesudah = await container.read(certificateDetailProvider(1).future);
    expect(sesudah.status, 'dibatalkan');
  });
}

/// Server menolak revisi dengan galat keadaan (`{message}` tanpa `errors`).
class _RevisiDitolak extends MockCertificateService {
  _RevisiDitolak() : super(bolehAksi: true);

  @override
  Future<CertificateDetail> revisi(
    String token,
    int certificateId, {
    required Map<String, String> perubahan,
    required String alasan,
    String? catatanPelanggan,
  }) async => throw const GalatAksi('Sertifikat ini sudah digantikan.');
}

class _BatalDitolak extends MockCertificateService {
  _BatalDitolak() : super(bolehAksi: true);

  @override
  Future<CertificateDetail> batalkan(
    String token,
    int certificateId, {
    required String alasan,
    String? catatanPelanggan,
  }) async => throw const GalatAksi('Sertifikat ini sudah digantikan.');
}
