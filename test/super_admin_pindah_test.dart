import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/customer.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/pindah_alat.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_detail_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_sa_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pindahkan_alat_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pratinjau_pindah_alat_screen.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/widgets/app_button.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';

import 'support/super_admin_uji.dart';

/// Hitungan pelanggan (§3.6) dan pindah alat (§3.7).
///
/// SUMBER bentuk JSON: `docs/perintah-frontend-super-admin.md` §3.6 dan §3.7
/// (repo API, branch `feat/super-admin-pengelolaan`); contoh respons di bawah
/// disalin dari dokumen itu. Angka di layar = angka server; tidak ada
/// perhitungan klien yang perlu dicocokkan ke workbook.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// §3.7 respons pratinjau.
final _pratinjauJson = {
  'data': {
    'dry_run': true,
    'dari': {'id': 17, 'nama': 'PT Contoh Makmur', 'anggota_aktif_count': 0},
    'ke': {'id': 23, 'nama': 'PT Contoh Makmur Tbk', 'anggota_aktif_count': 2},
    'jumlah_alat': 2,
    'alat': [
      {
        'id': 118,
        'nama_alat': 'Termometer Digital',
        'serial_number': 'SN-2231',
        'jumlah_sertifikat': 3,
      },
      {
        'id': 119,
        'nama_alat': 'Timbangan',
        'serial_number': 'SN-9001',
        'jumlah_sertifikat': 2,
      },
    ],
    'sertifikat_terdampak': 5,
    'sertifikat_terlihat_pelanggan': 4,
    'anggota_mulai_melihat': [
      {'id': 41, 'nama': 'Budi Santoso', 'email': 'budi@contoh.test'},
    ],
    'anggota_berhenti_melihat': [],
    'paket_terkait_count': 1,
    'peringatan': [
      {
        'kode': 'paket_tidak_dipindah',
        'pesan': 'Baris paket/order yang menunjuk alat ini TIDAK ikut pindah.',
      },
      {
        'kode': 'arsip_tidak_dipindah',
        'pesan': 'Berkas arsip lama tetap di folder PT asal.',
      },
      {
        'kode': 'isi_sertifikat_tetap',
        'pesan': 'Nomor dan isi sertifikat tidak diubah.',
      },
    ],
  },
};

void main() {
  setUpAll(muatFontSa);

  group('model: hitungan pelanggan (§3.6)', () {
    test('enam kunci baru dibaca; kunci lama tidak berubah', () {
      final c = Customer.fromJson({
        'id': 17,
        'nama': 'PT Contoh Makmur',
        'alamat': 'Jl. Contoh 1',
        'contact_person': null,
        'telepon': null,
        'email': null,
        'jumlah_alat': 3,
        'alat_count': 3,
        'sertifikat_count': 5,
        'anggota_aktif_count': 0,
        'undangan_menunggu_count': 1,
        'tanpa_akun': true,
        'nama_normal_kosong': false,
      });
      expect(c.jumlahAlat, 3);
      expect(c.alatCount, 3);
      expect(c.sertifikatCount, 5);
      expect(c.anggotaAktifCount, 0);
      expect(c.undanganMenungguCount, 1);
      expect(c.tanpaAkun, isTrue);
      expect(c.namaNormalKosong, isFalse);
    });

    test('server lama / POST-PUT tanpa hitungan: null dan false, bukan 0', () {
      final c = Customer.fromJson({'id': 1, 'nama': 'PT A', 'jumlah_alat': 2});
      expect(c.alatCount, isNull);
      expect(c.sertifikatCount, isNull);
      expect(c.anggotaAktifCount, isNull);
      expect(c.tanpaAkun, isFalse);
      expect(c.namaNormalKosong, isFalse);
    });
  });

  group('model: pratinjau dan hasil pindah alat (§3.7)', () {
    test('pratinjau: semua angka dan daftar dari server', () {
      final p = PratinjauPindahAlat.fromJson(_pratinjauJson);
      expect(p.dari.nama, 'PT Contoh Makmur');
      expect(p.dari.anggotaAktifCount, 0);
      expect(p.ke.id, 23);
      expect(p.ke.anggotaAktifCount, 2);
      expect(p.jumlahAlat, 2);
      expect(p.alat.map((a) => a.id), [118, 119]);
      expect(p.alat.first.jumlahSertifikat, 3);
      expect(p.sertifikatTerdampak, 5);
      expect(p.sertifikatTerlihatPelanggan, 4);
      expect(p.anggotaMulaiMelihat.single.nama, 'Budi Santoso');
      expect(p.anggotaBerhentiMelihat, isEmpty);
      expect(p.paketTerkaitCount, 1);
      expect(p.peringatan.map((w) => w.kode), [
        'paket_tidak_dipindah',
        'arsip_tidak_dipindah',
        'isi_sertifikat_tetap',
      ]);
    });

    test('hasil eksekusi', () {
      final h = HasilPindahAlat.fromJson({
        'message': '2 alat dipindahkan ke PT Contoh Makmur Tbk.',
        'data': {
          'dry_run': false,
          'dari': {
            'id': 17,
            'nama': 'PT Contoh Makmur',
            'anggota_aktif_count': 0,
          },
          'ke': {
            'id': 23,
            'nama': 'PT Contoh Makmur Tbk',
            'anggota_aktif_count': 2,
          },
          'jumlah_alat': 2,
          'alat_ids': [118, 119],
          'sertifikat_terdampak': 5,
          'sertifikat_terlihat_pelanggan': 4,
        },
      });
      expect(h.ke.nama, 'PT Contoh Makmur Tbk');
      expect(h.jumlahAlat, 2);
      expect(h.sertifikatTerdampak, 5);
      expect(h.sertifikatTerlihatPelanggan, 4);
    });
  });

  group('service: POST /customers/{c}/pindahkan-alat', () {
    AnggotaPelangganService baru(
      Future<http.Response> Function(http.Request) h,
    ) => ApiAnggotaPelangganService(
      ApiClient(client: MockClient(h), baseUrl: _dasar),
    );

    test('pratinjau: dry_run true, tanpa alasan/konfirmasi', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json(_pratinjauJson);
      });

      final p = await s.pratinjauPindahAlat(
        'tkn',
        17,
        alatIds: [118, 119],
        keCustomerId: 23,
      );

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/customers/17/pindahkan-alat');
      expect(_badan(terkirim), {
        'alat_ids': [118, 119],
        'ke_customer_id': 23,
        'dry_run': true,
      });
      expect(p.sertifikatTerdampak, 5);
    });

    test('eksekusi: alasan + konfirmasi true, tanpa dry_run', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'message': '2 alat dipindahkan ke PT Contoh Makmur Tbk.',
          'data': {
            'dry_run': false,
            'dari': {'id': 17, 'nama': 'A', 'anggota_aktif_count': 0},
            'ke': {'id': 23, 'nama': 'B', 'anggota_aktif_count': 2},
            'jumlah_alat': 2,
            'alat_ids': [118, 119],
            'sertifikat_terdampak': 5,
            'sertifikat_terlihat_pelanggan': 4,
          },
        });
      });

      final h = await s.pindahkanAlat(
        'tkn',
        17,
        alatIds: [118, 119],
        keCustomerId: 23,
        alasan: 'PT salah ketik, pemilik sebenarnya PT B',
      );

      expect(_badan(terkirim), {
        'alat_ids': [118, 119],
        'ke_customer_id': 23,
        'alasan': 'PT salah ketik, pemilik sebenarnya PT B',
        'konfirmasi': true,
      });
      expect(_badan(terkirim).containsKey('dry_run'), isFalse);
      expect(h.jumlahAlat, 2);
    });

    final galat = <(String, int, Map<String, dynamic>)>[
      (
        '409 alat_sudah_pindah',
        409,
        {'kode': 'alat_sudah_pindah', 'message': 'Alat sudah pindah.'},
      ),
      (
        '422 alat_bukan_milik_pt_asal',
        422,
        {
          'kode': 'alat_bukan_milik_pt_asal',
          'message': 'Bukan milik PT asal.',
          'data': {
            'alat_ids': [119],
          },
        },
      ),
      (
        '422 pt_tujuan_sama',
        422,
        {'kode': 'pt_tujuan_sama', 'message': 'Sama.'},
      ),
      (
        '422 alasan',
        422,
        {
          'message': 'Alasan wajib.',
          'errors': {
            'alasan': ['Alasan wajib.'],
          },
        },
      ),
      ('404', 404, {'message': 'Data nggak ketemu.'}),
      ('403', 403, {'message': 'Kamu nggak punya akses ke sini.'}),
      ('429', 429, {'message': 'Kebanyakan percobaan.'}),
    ];
    for (final (nama, status, badan) in galat) {
      test('eksekusi galat $nama dilempar apa adanya', () async {
        final s = baru((_) async => _json(badan, status));
        await expectLater(
          s.pindahkanAlat(
            't',
            17,
            alatIds: [1],
            keCustomerId: 2,
            alasan: 'abc',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['kode'], 'kode', badan['kode']),
          ),
        );
      });
    }

    test('jaringan putus saat eksekusi: tidak diulang otomatis', () async {
      var panggilan = 0;
      final s = baru((_) async {
        panggilan++;
        throw http.ClientException('putus');
      });
      await expectLater(
        s.pindahkanAlat('t', 17, alatIds: [1], keCustomerId: 2, alasan: 'abc'),
        throwsA(isA<KoneksiException>()),
      );
      expect(panggilan, 1, reason: 'mengulang bisa memindah dua kali');
    });

    test('detailPelanggan: GET /customers/{id} membawa hitungan', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'data': {
            'id': 17,
            'nama': 'PT Contoh Makmur',
            'jumlah_alat': 3,
            'alat_count': 3,
            'sertifikat_count': 5,
            'anggota_aktif_count': 0,
            'undangan_menunggu_count': 1,
            'tanpa_akun': true,
            'nama_normal_kosong': true,
          },
        });
      });
      final c = await s.detailPelanggan('t', 17);
      expect(terkirim.url.path, '/api/customers/17');
      expect(c.tanpaAkun, isTrue);
      expect(c.namaNormalKosong, isTrue);
      expect(c.sertifikatCount, 5);
    });
  });

  group('layar: hitungan dan lencana "Belum ada akun pelanggan"', () {
    testWidgets(
      'daftar: ringkasan dari server; lencana hanya yang tanpa akun',
      (tester) async {
        aturLayar(tester, 392, 900);
        await tester.pumpWidget(bungkusSa(const PelangganSaScreen()));
        await selesaikan(tester);

        expect(
          find.text('12 alat · 30 sertifikat · 2 anggota'),
          findsOneWidget,
        );
        expect(find.text('3 alat · 5 sertifikat · 0 anggota'), findsOneWidget);
        expect(find.byKey(const Key('tanpa-akun-18')), findsOneWidget);
        expect(find.byKey(const Key('tanpa-akun-17')), findsNothing);
        expect(find.text('Belum ada akun pelanggan'), findsOneWidget);
      },
    );

    testWidgets('server lama tanpa hitungan: jatuh ke jumlah alat', (
      tester,
    ) async {
      aturLayar(tester, 392, 900);
      await tester.pumpWidget(
        bungkusSa(
          const PelangganSaScreen(),
          lapisan: LapisanUjiSa(
            anggota: MockAnggotaPelangganService(
              pelanggan: const [
                Customer(
                  id: 5,
                  nama: 'PT Lama',
                  alamat: '',
                  contactPerson: '',
                  telepon: '',
                  email: '',
                  jumlahAlat: 7,
                ),
              ],
            ),
          ),
        ),
      );
      await selesaikan(tester);
      expect(find.text('7 alat'), findsOneWidget);
      expect(find.textContaining('sertifikat'), findsNothing);
      expect(find.text('Belum ada akun pelanggan'), findsNothing);
    });

    testWidgets(
      'detail: ringkasan, lencana, Undang anggota cepat, nama normal',
      (tester) async {
        aturLayar(tester, 392, 1400);
        await tester.pumpWidget(
          bungkusSa(
            PelangganDetailScreen(
              pelanggan: MockAnggotaPelangganService.contohPelanggan[1],
            ),
          ),
        );
        await selesaikan(tester);

        expect(find.byKey(const Key('ringkas-detail')), findsOneWidget);
        expect(find.text('3 alat · 5 sertifikat · 0 anggota'), findsOneWidget);
        expect(find.byKey(const Key('tanpa-akun-detail')), findsOneWidget);
        expect(find.byKey(const Key('nama-normal-kosong')), findsOneWidget);

        await tester.tap(find.byKey(const Key('undang-cepat')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('undang-email')), findsOneWidget);
      },
    );

    testWidgets(
      'detail PT yang punya akun: tanpa lencana dan tanpa aksi cepat',
      (tester) async {
        aturLayar(tester, 392, 1400);
        await tester.pumpWidget(
          bungkusSa(
            PelangganDetailScreen(
              pelanggan: MockAnggotaPelangganService.contohPelanggan[0],
            ),
          ),
        );
        await selesaikan(tester);

        expect(
          find.text('12 alat · 30 sertifikat · 2 anggota'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('tanpa-akun-detail')), findsNothing);
        expect(find.byKey(const Key('undang-cepat')), findsNothing);
        expect(find.byKey(const Key('nama-normal-kosong')), findsNothing);
      },
    );
  });

  group('alur pindahkan alat', () {
    final asal = MockAnggotaPelangganService.contohPelanggan[1];

    Future<void> pasang(
      WidgetTester tester, {
      LapisanUjiSa? lapisan,
      Izin izin = izinSuperAdmin,
      double lebar = 392,
      double tinggi = 900,
    }) async {
      aturLayar(tester, lebar, tinggi);
      await tester.pumpWidget(
        bungkusSa(
          PelangganDetailScreen(pelanggan: asal),
          lapisan: lapisan,
          izin: izin,
        ),
      );
      await selesaikan(tester);
    }

    Future<void> bukaPindah(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('pindahkan-alat')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('pindahkan-alat')));
      await selesaikan(tester);
    }

    Future<void> pilihAlatDanTujuan(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('pilih-alat-500')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilih-alat-501')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pilih-tujuan')));
      await selesaikan(tester);
      await tester.tap(find.byKey(const Key('tujuan-17')));
      await selesaikan(tester);
    }

    testWidgets('tombol hanya untuk yang berizin pelanggan.pindah-alat', (
      tester,
    ) async {
      const tanpaPindah = Izin(
        role: UserRole.admin,
        boleh: {
          NamaIzin.anggotaPelangganLihat,
          NamaIzin.pelangganAlatLihat,
          NamaIzin.alatRiwayatSertifikat,
        },
      );
      await pasang(tester, izin: tanpaPindah);
      await tester.scrollUntilVisible(
        find.byKey(const Key('alat-500')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('pindahkan-alat')), findsNothing);
    });

    testWidgets(
      'langkah 1: tombol pratinjau mati sampai alat DAN tujuan dipilih',
      (tester) async {
        await pasang(tester);
        await bukaPindah(tester);
        expect(find.byType(PindahkanAlatScreen), findsOneWidget);

        FilledButton tombol() => tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('lihat-pratinjau')),
            matching: find.byType(FilledButton),
          ),
        );
        expect(tombol().onPressed, isNull);
        expect(find.text('0 alat dipilih'), findsOneWidget);

        await tester.tap(find.byKey(const Key('pilih-alat-500')));
        await tester.pump();
        expect(find.text('1 alat dipilih'), findsOneWidget);
        expect(tombol().onPressed, isNull, reason: 'tujuan belum dipilih');

        await tester.tap(find.byKey(const Key('pilih-tujuan')));
        await selesaikan(tester);
        // PT asal TIDAK ikut daftar tujuan.
        expect(find.byKey(const Key('tujuan-18')), findsNothing);
        expect(find.byKey(const Key('tujuan-17')), findsOneWidget);
        await tester.tap(find.byKey(const Key('tujuan-17')));
        await selesaikan(tester);

        expect(find.text('PT Contoh Makmur'), findsWidgets);
        expect(tombol().onPressed, isNotNull);
      },
    );

    testWidgets('pilih semua yang termuat dan kosongkan', (tester) async {
      await pasang(tester);
      await bukaPindah(tester);

      await tester.tap(find.byKey(const Key('pilih-semua')));
      await tester.pump();
      expect(find.text('20 alat dipilih'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kosongkan-pilihan')));
      await tester.pump();
      expect(find.text('0 alat dipilih'), findsOneWidget);
    });

    testWidgets('pratinjau menampilkan angka server dan peringatan', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);

      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      expect(find.byType(PratinjauPindahAlatScreen), findsOneWidget);
      expect(
        layanan.catatan.any((c) => c.startsWith('pratinjau 18 -> 17')),
        isTrue,
      );
      expect(find.text('2 alat dipindahkan'), findsOneWidget);
      expect(find.text('5 sertifikat ikut berpindah'), findsOneWidget);
      expect(
        find.text('4 di antaranya terlihat di aplikasi pelanggan'),
        findsOneWidget,
      );
      expect(find.textContaining('Budi Santoso'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('pratinjau-berhenti')),
          matching: find.text('Tidak ada'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pratinjau-paket')), findsOneWidget);
      for (final kode in [
        'paket_tidak_dipindah',
        'arsip_tidak_dipindah',
        'isi_sertifikat_tetap',
      ]) {
        expect(find.byKey(Key('peringatan-$kode')), findsOneWidget);
      }
      // Pratinjau TIDAK memindahkan apa pun.
      expect(layanan.catatan.any((c) => c.startsWith('pindah ')), isFalse);
    });

    testWidgets('konfirmasi: alasan wajib; Batal tidak memanggil server', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      await tester.ensureVisible(find.byKey(const Key('pindahkan')));
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 3 karakter.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.enterText(find.byKey(const Key('alasan-pindah')), 'ab');
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 3 karakter.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('alasan-pindah')),
        'PT salah ketik',
      );
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      expect(
        find.text('Pindahkan 2 alat ke PT Contoh Makmur?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(layanan.catatan.any((c) => c.startsWith('pindah ')), isFalse);
    });

    testWidgets('sukses: alasan ikut terkirim apa adanya; Selesai kembali', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService();
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      await tester.ensureVisible(find.byKey(const Key('pindahkan')));
      await tester.enterText(
        find.byKey(const Key('alasan-pindah')),
        'PT salah ketik',
      );
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('konfirmasi-pindah')));
      await selesaikan(tester);

      expect(
        layanan.catatan,
        contains('pindah 18 -> 17 [500, 501] "PT salah ketik"'),
      );
      expect(
        find.text('2 alat dipindahkan ke PT Contoh Makmur.'),
        findsOneWidget,
      );
      expect(
        find.text(
          '5 sertifikat ikut berpindah (4 terlihat di aplikasi pelanggan).',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('selesai-pindah')));
      await selesaikan(tester);
      // Kembali ke detail pelanggan, dua layar sekaligus.
      expect(find.byType(PratinjauPindahAlatScreen), findsNothing);
      expect(find.byType(PindahkanAlatScreen), findsNothing);
      expect(find.byType(PelangganDetailScreen), findsOneWidget);
    });

    testWidgets('409 alat_sudah_pindah: kalimat jelas + Ulangi pratinjau', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService()
        ..galatPindah = const ApiException(
          'x',
          status: 409,
          body: {'kode': 'alat_sudah_pindah', 'message': 'x'},
        );
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      await tester.ensureVisible(find.byKey(const Key('pindahkan')));
      await tester.enterText(find.byKey(const Key('alasan-pindah')), 'alasan');
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('konfirmasi-pindah')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Alat sudah dipindah admin lain. Ulangi pratinjau untuk melihat '
          'keadaan terbaru.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pindahkan')), findsNothing);

      final sebelum = layanan.catatan
          .where((c) => c.startsWith('pratinjau'))
          .length;
      layanan.galatPindah = null;
      // Dipanggil langsung: letak tombol di ujung daftar yang memanjang
      // sesudah galat membuat ketukan di koordinat layar tidak dapat diandalkan
      // di tes (perilakunya yang diuji, bukan hit-test).
      tester
          .widget<AppButton>(find.byKey(const Key('ulangi-pratinjau')))
          .onPressed!();
      await tester.pump();
      await selesaikan(tester);
      expect(
        layanan.catatan.where((c) => c.startsWith('pratinjau')).length,
        sebelum + 1,
      );
      expect(find.byKey(const Key('pindahkan')), findsOneWidget);
    });

    testWidgets('422 errors.alasan dari server tampil di kolom alasan', (
      tester,
    ) async {
      final layanan = MockAnggotaPelangganService()
        ..galatPindah = const ApiException(
          'Alasan tidak valid.',
          status: 422,
          body: {
            'message': 'Alasan tidak valid.',
            'errors': {
              'alasan': ['Alasan dari server.'],
            },
          },
        );
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      await tester.ensureVisible(find.byKey(const Key('pindahkan')));
      await tester.enterText(find.byKey(const Key('alasan-pindah')), 'alasan');
      await tester.tap(find.byKey(const Key('pindahkan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('konfirmasi-pindah')));
      await tester.pumpAndSettle();

      expect(find.text('Alasan dari server.'), findsOneWidget);
    });

    testWidgets('pratinjau gagal dimuat: kalimat + Coba lagi', (tester) async {
      final layanan = MockAnggotaPelangganService()
        ..galatPratinjau = const KoneksiException(
          'Nggak bisa nyambung ke server.',
        );
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await selesaikan(tester);

      expect(find.text('Nggak bisa nyambung ke server.'), findsOneWidget);
      layanan.galatPratinjau = null;
      await tester.tap(find.text('Coba lagi'));
      await selesaikan(tester);
      expect(find.byKey(const Key('pindahkan')), findsOneWidget);
    });

    testWidgets('pratinjau memuat: kerangka dulu', (tester) async {
      final layanan = MockAnggotaPelangganService();
      await pasang(tester, lapisan: LapisanUjiSa(anggota: layanan));
      await bukaPindah(tester);
      await pilihAlatDanTujuan(tester);

      // Jeda dipasang SESUDAH langkah 1: hanya pratinjau yang menunggu.
      layanan.jeda = const Duration(milliseconds: 500);
      await tester.tap(find.byKey(const Key('lihat-pratinjau')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(PratinjauPindahAlatScreen), findsOneWidget);
      expect(find.byKey(const Key('pindahkan')), findsNothing);
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pump(const Duration(seconds: 2));
      await selesaikan(tester);
      expect(find.byKey(const Key('pindahkan')), findsOneWidget);
    });

    testWidgets('layar langkah 1 dibuka tanpa izin: terkunci', (tester) async {
      aturLayar(tester, 392, 800);
      await tester.pumpWidget(
        bungkusSa(
          PindahkanAlatScreen(asal: asal),
          token: tokenTeknisi,
          izin: izinTeknisi,
        ),
      );
      await selesaikan(tester);
      expect(
        find.text('Layar ini hanya untuk akun yang diberi izin oleh server.'),
        findsOneWidget,
      );
    });
  });
}
