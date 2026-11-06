import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/models/alur_acuan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/data_acuan/alur_versi_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/simulasi_versi_acuan_screen.dart';
import 'package:sidik_calibration/screens/data_acuan/widgets/hak_alur_acuan.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/data_acuan_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Alur versi data acuan (T2.2/T2.3) di aplikasi lab — dan cermin baca
/// sajanya untuk Sidik Studio ([alurAcuanBacaSajaProvider]).
///
/// Bentuk JSON = `DataAcuanAlurController` (repo API, branch
/// `feat/studio-kendali-olah-data`). Angka laporan simulasi di mock adalah
/// FIXTURE STRUKTUR sintetis (nomor `PERAGA`), bukan angka lab.
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
void main() {
  final l10n = AppLocalizationsId();

  group('model: parsing toleran', () {
    test(
      'versi alur: field kontrak, kunci asing diabaikan, tipe salah aman',
      () {
        final v = VersiAlurAcuan.fromJson({
          'id': 9,
          'paket': 'micrometer',
          'jenis': 'data',
          'nomor': '3',
          'status': 'diajukan',
          'kunci_baru_dari_server': {'apa': 1},
          'simulasi': {
            'status': 'kedaluwarsa',
            'id': 4,
            'ringkasan': {
              'sesi_total': 5,
              'terbit_cetak_berubah': 2,
              'catatan_sumber': 'bukan db',
              'jejak_data': {'sesi_jumlah': 5},
            },
            'wajib_diakui': ['terbit_cetak_berubah', 7, null, 'butir_baru'],
          },
          'log': [
            {'aksi': 'ajukan', 'status_dari': 'draf', 'status_ke': 'diajukan'},
            'bukan peta',
            {'aksi': 'simulasi', 'pada': 'bukan-tanggal', 'user_id': 'x'},
          ],
        });

        expect(v.id, 9);
        expect(v.nomor, 3);
        expect(v.simulasi.status, StatusSimulasiAcuan.kedaluwarsa);
        expect(v.simulasi.ringkasan!.sesiTotal, 5);
        expect(v.simulasi.ringkasan!.terbitCetakBerubah, 2);
        expect(v.simulasi.ringkasan!.sesiBerubah, isNull);
        expect(v.simulasi.ringkasan!.catatanSumber, 'bukan db');
        expect(v.simulasi.wajibDiakui, [
          'terbit_cetak_berubah',
          '7',
          'butir_baru',
        ]);
        expect(v.log, hasLength(2));
        expect(v.log.last.pada, isNull);
        expect(v.log.last.userId, isNull);
      },
    );

    test('simulasi hilang / null → belum_ada', () {
      final v = VersiAlurAcuan.fromJson({'id': 1, 'simulasi': null});
      expect(v.simulasi.status, StatusSimulasiAcuan.belumAda);
      expect(v.simulasi.wajibDiakui, isEmpty);
      expect(v.log, isEmpty);
    });

    test(
      'laporan: nilai lama/baru apa adanya, master_lain pakai master/draf',
      () {
        final lap = LaporanSimulasiAcuan.fromJson(
          jsonDecode(
                jsonEncode({
                  'status': 'terbaru',
                  'laporan': {
                    'sesi': [
                      {
                        'sesi_id': 1,
                        'nomor_sertifikat_terbit': ['A/1'],
                        'sudah_terbit': true,
                        'selisih': [
                          {
                            'titik': 1,
                            'kolom': 'u',
                            'lama': 20.0,
                            'baru': 200,
                            'selisih': 180.0,
                          },
                        ],
                        'cetak': [
                          {'titik': 1, 'kolom': 'u', 'lama': null, 'baru': '1'},
                        ],
                      },
                    ],
                    'bersama_antar_varian': {
                      'berlaku': true,
                      'berubah': [
                        {'jalur': 'balok/1.0', 'lama': '1.0', 'baru': '1.1'},
                      ],
                      'master_lain': [
                        {
                          'workbook_master_id': 3,
                          'beda': [
                            {'jalur': 'x', 'master': 1, 'draf': 2},
                          ],
                        },
                      ],
                    },
                  },
                }),
              )
              as Map<String, dynamic>,
        );

        expect(lap.adaLaporan, isTrue);
        final s = lap.sesi.single;
        expect(s.nomorSertifikatTerbit, ['A/1']);
        expect(s.selisih.single.lama, isA<double>());
        expect(s.selisih.single.baru, isA<int>());
        expect(s.cetak.single.lama, isNull);
        expect(lap.bersama!.berubah.single.baru, '1.1');
        expect(lap.bersama!.masterLain.single.beda.single.lama, 1);
        expect(lap.bersama!.masterLain.single.beda.single.baru, 2);
        expect(lap.bersamaAntarPaket, isEmpty);
      },
    );

    test('antar-paket: presisi/string JSON, nullable dan sumber gagal', () {
      final lap = LaporanSimulasiAcuan.fromJson({
        ..._simulasiPaket,
        'laporan': {
          'bersama_antar_paket': [
            ..._bedaPaket,
            {'acuan': 1.25, 'master': false, 'galat': []},
            'bukan objek',
            {'acuan': '', 'master': '"STD-01"'},
          ],
        },
      });

      expect(lap.simulasi.ringkasan!.bersamaAntarPaket, 2);
      expect(lap.bersamaAntarPaket, hasLength(4));
      final beda = lap.bersamaAntarPaket.first;
      expect(beda.paket, 'height_gauge');
      expect(beda.dasar, 'versi berlaku v1 (#1)');
      expect(beda.jalur, 'outside[0].nilai_terkoreksi_mm');
      expect(beda.acuan, '25.000800000000001');
      expect(beda.master, '25.001800000000001');
      expect(lap.bersamaAntarPaket[1].acuan, isNull);
      expect(lap.bersamaAntarPaket[1].master, isNull);
      expect(lap.bersamaAntarPaket[1].galat, 'Master sumber tidak ditemukan.');
      expect(lap.bersamaAntarPaket[2].acuan, isNull);
      expect(lap.bersamaAntarPaket[2].master, isNull);
      expect(lap.bersamaAntarPaket[2].galat, isNull);
      expect(lap.bersamaAntarPaket.last.acuan, '');
      expect(lap.bersamaAntarPaket.last.master, '"STD-01"');
      expect(
        labelButirPengakuan(ButirPengakuanAcuan.bersamaAntarPaket, l10n),
        l10n.alurAcuanButirBersamaPaket,
      );
    });

    test('antar-paket hilang/null/tipe salah tetap kompatibel server lama', () {
      for (final isi in [null, 'bukan daftar', <String, dynamic>{}]) {
        final lap = LaporanSimulasiAcuan.fromJson({
          'ringkasan': {'bersama_antar_paket': []},
          'laporan': {'bersama_antar_paket': isi},
        });
        expect(lap.bersamaAntarPaket, isEmpty);
        expect(lap.simulasi.ringkasan!.bersamaAntarPaket, isNull);
      }
    });

    test('laporan null → adaLaporan false', () {
      final lap = LaporanSimulasiAcuan.fromJson({
        'status': 'belum_ada',
        'laporan': null,
      });
      expect(lap.adaLaporan, isFalse);
      expect(lap.sesi, isEmpty);
      expect(lap.bersamaAntarPaket, isEmpty);
    });
  });

  group('pemetaan galat', () {
    String p(Object e) => pesanGalatAlurAcuan(e, l10n);
    ApiException galat(String kode, {int status = 422, Map? rincian}) =>
        ApiException(
          'teks server mentah',
          status: status,
          body: {'kode': kode, 'rincian': ?rincian},
        );

    test('kode server → kalimat l10n, tidak pernah teks mentah', () {
      expect(
        p(
          galat(
            'pengakuan_wajib',
            rincian: {
              'butir': ['terbit_cetak_berubah', 'sesi_gagal'],
            },
          ),
        ),
        l10n.alurAcuanGalatPengakuan(
          '${l10n.alurAcuanButirTerbit}, ${l10n.alurAcuanButirSesiGagal}',
        ),
      );
      expect(
        p(galat('simulasi_kedaluwarsa')),
        l10n.alurAcuanGalatSimulasiKedaluwarsa,
      );
      expect(
        p(galat('pengesah_ikut_menyunting')),
        l10n.alurAcuanGalatPengesahIkut,
      );
      expect(p(galat('konfirmasi_sandi_salah')), l10n.alurAcuanGalatSandi);
      expect(
        p(galat('berlaku_mulai_lampau')),
        l10n.alurAcuanGalatBerlakuLampau,
      );
      expect(p(galat('rentang_bentrok')), l10n.alurAcuanGalatRentang);
      expect(
        p(galat('simulasi_belum_ada')),
        l10n.alurAcuanGalatSimulasiBelumAda,
      );
      expect(p(galat('simulasi_gagal')), l10n.alurAcuanGalatSimulasiGagal);
      expect(p(galat('status_tidak_sesuai')), l10n.alurAcuanGalatStatus);
      expect(
        p(galat('hanya_super_admin', status: 403)),
        l10n.alurAcuanGalatHanyaSuperAdmin,
      );
      expect(
        p(galat('bukan_aplikasi_ini', status: 403)),
        l10n.alurAcuanGalatBukanAplikasi,
      );
    });

    test('tanpa kode: menurut status; selain ApiException: umum', () {
      ApiException s(int status) =>
          ApiException('mentah', status: status, body: const {});
      expect(p(s(403)), l10n.alurAcuanGalatTidakBerwenang);
      expect(p(s(404)), l10n.alurAcuanGalatTidakDitemukan);
      expect(p(s(429)), l10n.alurAcuanGalatTerlaluSering);
      expect(p(s(422)), l10n.alurAcuanGalatIsian);
      expect(p(s(500)), l10n.alurAcuanGalatUmum);
      expect(p(const KoneksiException('x')), l10n.alurAcuanGalatKoneksi);
      expect(p(Exception('StateError: mentah')), l10n.alurAcuanGalatUmum);
    });
  });

  group('ApiDataAcuanService: rute & badan', () {
    late List<http.Request> masuk;
    late ApiDataAcuanService layanan;

    setUp(() {
      masuk = [];
      layanan = ApiDataAcuanService(
        ApiClient(
          baseUrl: 'http://uji/api',
          client: MockClient((req) async {
            masuk.add(req);
            final body = req.url.path.endsWith('/alur')
                ? {'data': <Object?>[]}
                : req.url.path.endsWith('/simulasi') && req.method == 'GET'
                ? {
                    'data': {'status': 'belum_ada', 'laporan': null},
                  }
                : {'message': 'ok', 'data': <String, Object?>{}};
            return http.Response(
              jsonEncode(body),
              req.method == 'POST' && req.url.path.endsWith('/simulasi')
                  ? 201
                  : 200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    });

    Map<String, dynamic> badan(http.Request r) =>
        r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;

    test('baca', () async {
      await layanan.alur('t', 'micro meter');
      await layanan.laporanSimulasi('t', 4);
      expect(masuk[0].method, 'GET');
      expect(masuk[0].url.path, '/api/data-acuan/paket/micro%20meter/alur');
      expect(masuk[1].url.path, '/api/data-acuan/versi/4/simulasi');
      expect(masuk[0].headers['Authorization'], 'Bearer t');
    });

    test('tulis', () async {
      await layanan.ajukan(
        't',
        4,
        alasan: 'Alasan cukup panjang',
        rujukan: const [RujukanAjuanAcuan(jenis: 'ik', nilai: 'IK-01')],
      );
      await layanan.jalankanSimulasi('t', 4);
      await layanan.tolak('t', 4, alasan: 'Tidak sesuai IK lab');
      await layanan.aktifkan(
        't',
        4,
        berlakuMulai: DateTime(2026, 10, 23, 15),
        password: 'rahasia',
        catatan: '  ',
        pengakuan: const {'terbit_cetak_berubah': 'Sudah dicek manual'},
      );

      expect(
        [for (final r in masuk) '${r.method} ${r.url.path}'],
        [
          'POST /api/data-acuan/versi/4/ajukan',
          'POST /api/data-acuan/versi/4/simulasi',
          'POST /api/data-acuan/versi/4/tolak',
          'POST /api/data-acuan/versi/4/aktifkan',
        ],
      );
      expect(badan(masuk[0]), {
        'alasan': 'Alasan cukup panjang',
        'rujukan': [
          {'jenis': 'ik', 'nilai': 'IK-01'},
        ],
      });
      expect(badan(masuk[2]), {'alasan': 'Tidak sesuai IK lab'});
      expect(badan(masuk[3]), {
        'berlaku_mulai': '2026-10-23',
        'password': 'rahasia',
        'pengakuan': {'terbit_cetak_berubah': 'Sudah dicek manual'},
      });
    });
  });

  group('layar alur: peran & aksi', () {
    testWidgets('admin: Ajukan/Simulasi/Tolak di draf, TANPA Aktifkan', (
      tester,
    ) async {
      await _pasang(tester, token: 'mock-token-1');
      expect(find.byKey(const ValueKey('alur-ajukan-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-simulasi-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-tolak-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-aktifkan-2')), findsNothing);
      // Versi 1 aktif: tidak ada aksi.
      expect(find.byKey(const ValueKey('alur-ajukan-1')), findsNothing);
      expect(find.byKey(const ValueKey('alur-baca-saja')), findsNothing);
    });

    testWidgets('admin: versi diajukan → tidak bisa tolak (super admin saja)', (
      tester,
    ) async {
      final layanan = _Layanan()..statusAwalV2 = 'diajukan';
      await _pasang(tester, token: 'mock-token-1', layanan: layanan);
      expect(find.byKey(const ValueKey('alur-simulasi-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-tolak-2')), findsNothing);
      expect(find.byKey(const ValueKey('alur-aktifkan-2')), findsNothing);
    });

    testWidgets('super admin: diajukan → Tolak & Aktifkan', (tester) async {
      final layanan = _Layanan()
        ..statusAwalV2 = 'diajukan'
        ..sudahDisimulasikan();
      await _pasang(tester, token: 'mock-token-5', layanan: layanan);
      expect(find.byKey(const ValueKey('alur-tolak-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-aktifkan-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-ajukan-2')), findsNothing);
    });

    testWidgets('viewer: lihat alur, tanpa satu pun aksi walau izin terbawa', (
      tester,
    ) async {
      await _pasang(
        tester,
        token: 'mock-token-3',
        izin: Izin(role: UserRole.viewer, boleh: _izinSemua.boleh),
      );
      expect(find.text('v2'), findsOneWidget);
      for (final k in ['ajukan', 'simulasi', 'tolak', 'aktifkan']) {
        expect(find.byKey(ValueKey('alur-$k-2')), findsNothing, reason: k);
      }
    });

    testWidgets('teknisi: server 404 → pesan, tanpa aksi', (tester) async {
      await _pasang(tester, token: 'mock-token-2');
      expect(find.text('Paket data acuan tidak ditemukan.'), findsOneWidget);
      expect(find.byKey(const ValueKey('alur-ajukan-2')), findsNothing);
    });

    testWidgets('mode Studio (baca saja): banner arahan, tanpa aksi', (
      tester,
    ) async {
      await _pasang(
        tester,
        token: 'mock-token-5',
        izin: _izinSemua,
        bacaSaja: true,
      );
      expect(find.byKey(const ValueKey('alur-baca-saja')), findsOneWidget);
      expect(find.text(l10n.alurAcuanBacaSajaJudul), findsOneWidget);
      for (final k in ['ajukan', 'simulasi', 'tolak', 'aktifkan']) {
        expect(find.byKey(ValueKey('alur-$k-2')), findsNothing, reason: k);
      }
    });

    testWidgets('izin server belum menyebut alur → admin tanpa aksi', (
      tester,
    ) async {
      await _pasang(
        tester,
        token: 'mock-token-1',
        izin: const Izin(
          role: UserRole.admin,
          boleh: {NamaIzin.dataAcuanLihat},
        ),
      );
      expect(find.byKey(const ValueKey('alur-ajukan-2')), findsNothing);
    });

    testWidgets('Ajukan: alasan pendek ditolak klien; valid → POST ajukan', (
      tester,
    ) async {
      final layanan = _Layanan();
      await _pasang(tester, token: 'mock-token-1', layanan: layanan);

      await tester.tap(find.byKey(const ValueKey('alur-ajukan-2')));
      await _tenang(tester);
      await tester.enterText(find.byKey(const ValueKey('ajukan-alasan')), 'x');
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);
      expect(layanan.panggilanTulis, isEmpty);
      expect(find.text(l10n.alurAcuanAlasanMin), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('ajukan-alasan')),
        'Master 2027 sudah dicek lab',
      );
      await tester.tap(find.byKey(const ValueKey('ajukan-tambah-rujukan')));
      await _tenang(tester);
      await tester.enterText(
        find.byKey(const ValueKey('ajukan-rujukan-nilai-0')),
        'SERT-STD-01',
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);

      expect(layanan.panggilanTulis, ['ajukan:2']);
      expect(layanan.isianTulis['ajukan'], {
        'alasan': 'Master 2027 sudah dicek lab',
        'rujukan': [
          {'jenis': 'sertifikat_standar', 'nilai': 'SERT-STD-01'},
        ],
      });
      expect(find.text(l10n.alurAcuanSuksesAjukan(2)), findsOneWidget);
      // Disegarkan: status sekarang diajukan → tombol ajukan hilang.
      expect(find.byKey(const ValueKey('alur-ajukan-2')), findsNothing);
    });

    testWidgets('Jalankan simulasi → POST simulasi, laporan bisa dibuka', (
      tester,
    ) async {
      final layanan = _Layanan();
      await _pasang(tester, token: 'mock-token-1', layanan: layanan);
      expect(find.byKey(const ValueKey('alur-laporan-2')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('alur-simulasi-2')));
      await _tenang(tester);
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);

      expect(layanan.panggilanTulis, ['simulasi:2']);
      expect(
        find.textContaining(l10n.alurAcuanSimTerbaru, findRichText: true),
        findsWidgets,
      );
      expect(find.text(l10n.alurAcuanButirTerbit), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('alur-laporan-2')));
      await tester.tap(find.byKey(const ValueKey('alur-laporan-2')));
      await _tenang(tester);
      expect(find.byType(SimulasiVersiAcuanScreen), findsOneWidget);
    });

    testWidgets('Tolak: galat server dipetakan, dialog tetap terbuka', (
      tester,
    ) async {
      final layanan = _Layanan()
        ..galatTulis = const ApiException(
          'Hanya draf atau versi diajukan yang bisa ditolak. Status sekarang: aktif.',
          status: 422,
          body: {'kode': 'status_tidak_sesuai'},
        );
      await _pasang(tester, token: 'mock-token-1', layanan: layanan);

      await tester.tap(find.byKey(const ValueKey('alur-tolak-2')));
      await _tenang(tester);
      await tester.enterText(
        find.byKey(const ValueKey('tolak-alasan')),
        'Isi tidak sesuai sertifikat',
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);

      expect(layanan.panggilanTulis, ['tolak:2']);
      expect(find.text(l10n.alurAcuanGalatStatus), findsOneWidget);
      expect(find.textContaining('Status sekarang'), findsNothing);
      expect(find.byKey(const ValueKey('tolak-alasan')), findsOneWidget);
    });

    testWidgets('Aktifkan: pengakuan per butir wajib; kirim tanggal hari ini', (
      tester,
    ) async {
      final layanan = _Layanan()
        ..statusAwalV2 = 'diajukan'
        ..sudahDisimulasikan();
      await _pasang(tester, token: 'mock-token-5', layanan: layanan);

      await tester.tap(find.byKey(const ValueKey('alur-aktifkan-2')));
      await _tenang(tester);
      final pengakuan = find.byKey(
        const ValueKey('aktifkan-pengakuan-terbit_cetak_berubah'),
      );
      expect(pengakuan, findsOneWidget);

      // Kosong + sandi kosong → tidak terkirim.
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);
      expect(layanan.panggilanTulis, isEmpty);
      expect(find.text(l10n.alurAcuanSandiWajib), findsOneWidget);

      await tester.enterText(pengakuan, 'Pelanggan sudah dikabari');
      await tester.enterText(
        find.byKey(const ValueKey('aktifkan-sandi')),
        'sandi-salah',
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);
      expect(find.text(l10n.alurAcuanGalatSandi), findsOneWidget);
      // Sandi tidak bertahan sesudah satu kirim.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('aktifkan-sandi')))
            .controller!
            .text,
        isEmpty,
      );

      await tester.enterText(
        find.byKey(const ValueKey('aktifkan-sandi')),
        MockDataAcuanService.sandiPeraga,
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);

      expect(layanan.panggilanTulis, ['aktifkan:2', 'aktifkan:2']);
      final isian = layanan.isianTulis['aktifkan']! as Map;
      expect(isian['berlaku_mulai'], tanggalIsoAcuan(DateTime.now()));
      expect(isian['pengakuan'], {
        'terbit_cetak_berubah': 'Pelanggan sudah dikabari',
      });
      expect(find.text(l10n.alurAcuanSuksesAktifkan(2)), findsOneWidget);
    });

    testWidgets('antar-paket: rincian terlihat sebelum pengakuan aktifkan', (
      tester,
    ) async {
      final layanan = _LayananBersamaPaket()
        ..statusAwalV2 = 'diajukan'
        ..sudahDisimulasikan();
      await _pasang(tester, token: 'mock-token-5', layanan: layanan);
      expect(find.text(l10n.alurAcuanBersamaPaket(2)), findsOneWidget);
      expect(find.text(l10n.alurAcuanButirBersamaPaket), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('alur-laporan-2')));
      await tester.tap(find.byKey(const ValueKey('alur-laporan-2')));
      await _tenang(tester);
      expect(find.byKey(const ValueKey('sim-bersama-paket')), findsOneWidget);
      expect(find.text(l10n.simAcuanBersamaPaketJudul), findsOneWidget);
      expect(find.text(l10n.simAcuanPaket('height_gauge')), findsOneWidget);
      expect(
        find.text(l10n.simAcuanDasar('versi berlaku v1 (#1)')),
        findsOneWidget,
      );
      expect(find.text('outside[0].nilai_terkoreksi_mm'), findsOneWidget);
      expect(find.text('25.000800000000001'), findsOneWidget);
      expect(find.text('25.001800000000001'), findsOneWidget);
      expect(find.text(l10n.simAcuanKolomAcuan), findsOneWidget);
      expect(find.text(l10n.simAcuanKolomMaster), findsOneWidget);
      expect(find.text(l10n.simAcuanSumberGagal), findsOneWidget);
      expect(find.text('Master sumber tidak ditemukan.'), findsOneWidget);
      expect(layanan.panggilanTulis, isEmpty);

      // AppBar memakai BackButton Material dengan tooltip sesuai locale app.
      // pageBack() mencari tooltip literal 'Back', sedangkan fixture ini ID.
      final kembali = find.descendant(
        of: find.byType(SimulasiVersiAcuanScreen),
        matching: find.byType(BackButton),
      );
      expect(kembali, findsOneWidget);
      await tester.tap(kembali);
      await _tenang(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('alur-aktifkan-2')));
      await tester.tap(find.byKey(const ValueKey('alur-aktifkan-2')));
      await _tenang(tester);
      final pengakuanPaket = find.byKey(
        const ValueKey('aktifkan-pengakuan-bersama_antar_paket'),
      );
      expect(pengakuanPaket, findsOneWidget);
      expect(find.text('bersama_antar_paket'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('aktifkan-pengakuan-terbit_cetak_berubah')),
        'Dampak sertifikat sudah diperiksa',
      );
      await tester.enterText(
        find.byKey(const ValueKey('aktifkan-sandi')),
        MockDataAcuanService.sandiPeraga,
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);
      expect(layanan.panggilanTulis, isEmpty);
      expect(find.text(l10n.alurAcuanAlasanMin), findsOneWidget);

      await tester.enterText(
        pengakuanPaket,
        'Beda paket sumber sudah ditinjau',
      );
      await tester.tap(find.byKey(const ValueKey('alur-dialog-kirim')));
      await _tenang(tester);
      expect(layanan.panggilanTulis, ['aktifkan:2']);
      expect((layanan.isianTulis['aktifkan']! as Map)['pengakuan'], {
        'terbit_cetak_berubah': 'Dampak sertifikat sudah diperiksa',
        'bersama_antar_paket': 'Beda paket sumber sudah ditinjau',
      });
    });

    testWidgets('Aktifkan: simulasi kedaluwarsa → kirim dinonaktifkan', (
      tester,
    ) async {
      final layanan = _Layanan()
        ..statusAwalV2 = 'diajukan'
        ..sudahDisimulasikan(kedaluwarsa: true);
      await _pasang(tester, token: 'mock-token-5', layanan: layanan);

      await tester.tap(find.byKey(const ValueKey('alur-aktifkan-2')));
      await _tenang(tester);
      expect(
        find.byKey(const ValueKey('aktifkan-sim-belum-terbaru')),
        findsOneWidget,
      );
      final kirim = tester.widget<FilledButton>(
        find.byKey(const ValueKey('alur-dialog-kirim')),
      );
      expect(kirim.onPressed, isNull);
    });
  });

  group('laporan simulasi', () {
    testWidgets('sertifikat terbit & cetak berubah disorot; filter berubah', (
      tester,
    ) async {
      final layanan = _Layanan()..sudahDisimulasikan();
      await _pasang(
        tester,
        token: 'mock-token-1',
        layanan: layanan,
        layar: const SimulasiVersiAcuanScreen(versiId: 2, nomor: 2),
      );

      expect(
        find.byKey(const ValueKey('sim-sertifikat-PERAGA/CERT/001')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sim-cetak-101')), findsOneWidget);
      expect(find.byKey(const ValueKey('sim-selisih-101')), findsOneWidget);
      // Nilai apa adanya, tidak dibulatkan.
      expect(find.text('0.75'), findsOneWidget);
      expect(find.text('0.8'), findsOneWidget);
      // Sesi tanpa perubahan disembunyikan bawaan.
      expect(find.byKey(const ValueKey('sim-sesi-102')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sim-hanya-berubah')));
      await _tenang(tester);
      expect(find.byKey(const ValueKey('sim-sesi-102')), findsOneWidget);
    });

    testWidgets('belum ada simulasi → keadaan kosong', (tester) async {
      await _pasang(
        tester,
        token: 'mock-token-1',
        layar: const SimulasiVersiAcuanScreen(versiId: 2, nomor: 2),
      );
      expect(find.text(l10n.simAcuanBelumAda), findsOneWidget);
    });
  });

  group('pintu Kelola lab', () {
    testWidgets('muncul hanya dengan izin tulis alur', (tester) async {
      await _pasang(
        tester,
        token: 'mock-token-1',
        layar: const KelolaLabScreen(),
      );
      expect(find.text(l10n.alurAcuanJudul), findsOneWidget);

      await _pasang(
        tester,
        token: 'mock-token-1',
        izin: const Izin(
          role: UserRole.admin,
          boleh: {NamaIzin.dataAcuanLihat, NamaIzin.penggunaKelola},
        ),
        layar: const KelolaLabScreen(),
      );
      expect(find.text(l10n.alurAcuanJudul), findsNothing);
    });
  });
}

const _izinSemua = Izin(
  role: UserRole.superAdmin,
  boleh: {
    NamaIzin.dataAcuanLihat,
    NamaIzin.dataAcuanAjukan,
    NamaIzin.dataAcuanSimulasi,
    NamaIzin.dataAcuanAktifkan,
  },
);

UserRole _peranToken(String token) => switch (token) {
  'mock-token-2' => UserRole.teknisi,
  'mock-token-3' => UserRole.viewer,
  'mock-token-5' => UserRole.superAdmin,
  _ => UserRole.admin,
};

/// `/me/permissions` server branch alur: admin = ajukan + simulasi,
/// super admin + aktifkan; viewer/teknisi = lihat saja.
Izin _izinLab(String token) {
  final peran = _peranToken(token);
  return Izin(
    role: peran,
    boleh: {
      NamaIzin.dataAcuanLihat,
      if (peran == UserRole.admin || peran == UserRole.superAdmin) ...{
        NamaIzin.dataAcuanAjukan,
        NamaIzin.dataAcuanSimulasi,
      },
      if (peran == UserRole.superAdmin) NamaIzin.dataAcuanAktifkan,
    },
  );
}

class _Layanan extends MockDataAcuanService {
  _Layanan({super.sebagaiTeknisi});
}

// Kontrak sintetis DataBersamaPaket server, tanpa nilai atau identitas lab.
const _simulasiPaket = <String, dynamic>{
  'status': 'terbaru',
  'id': 4,
  'ringkasan': {'sesi_total': 0, 'bersama_antar_paket': '2'},
  'wajib_diakui': ['terbit_cetak_berubah', 'bersama_antar_paket'],
};

const _bedaPaket = <Map<String, dynamic>>[
  {
    'paket': 'height_gauge',
    'dasar': 'versi berlaku v1 (#1)',
    'jalur': 'outside[0].nilai_terkoreksi_mm',
    'acuan': '25.000800000000001',
    'master': '25.001800000000001',
  },
  {
    'paket': '*',
    'dasar': '-',
    'jalur': '-',
    'acuan': null,
    'master': null,
    'galat': 'Master sumber tidak ditemukan.',
  },
];

class _LayananBersamaPaket extends _Layanan {
  @override
  Future<List<VersiAlurAcuan>> alur(String token, String kode) async => [
    for (final v in await super.alur(token, kode))
      if (v.id == 2)
        VersiAlurAcuan(
          versi: v.versi,
          simulasi: SimulasiVersiAcuan.fromJson(_simulasiPaket),
          log: v.log,
        )
      else
        v,
  ];

  @override
  Future<LaporanSimulasiAcuan> laporanSimulasi(
    String token,
    int versiId,
  ) async => LaporanSimulasiAcuan.fromJson({
    ..._simulasiPaket,
    'laporan': {'sesi': <Object?>[], 'bersama_antar_paket': _bedaPaket},
  });
}

Future<void> _tenang(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }
}

Future<void> _pasang(
  WidgetTester tester, {
  required String token,
  Izin? izin,
  MockDataAcuanService? layanan,
  bool bacaSaja = false,
  Widget layar = const AlurVersiAcuanScreen(kode: 'micrometer'),
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        izinServiceProvider.overrideWithValue(
          MockIzinService(izin: izin ?? _izinLab(token)),
        ),
        dataAcuanServiceProvider.overrideWithValue(
          layanan ?? _Layanan(sebagaiTeknisi: token == 'mock-token-2'),
        ),
        if (bacaSaja) alurAcuanBacaSajaProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: SidikTheme.terang,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: layar,
      ),
    ),
  );
  await _tenang(tester);
}
