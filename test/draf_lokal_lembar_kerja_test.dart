import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/autoclave_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/autoclave_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/pengirim_draf_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/versi_service.dart';

/// Draf offline di layar lembar kerja (F3 paket 30 Sep, rencana
/// `draf-offline` 14 Okt 2026).
///
/// Yang diuji URUTAN kejadian, bukan satu keadaan: isi → aplikasi dimatikan
/// paksa → dibuka lagi → isiannya kembali; isi → server mati → Simpan Draf →
/// keluar → draf menunggu di HP.
///
/// Angka di tabel (4.00 / 22.2) cuma isian yang diadu bolak-balik layar ↔
/// simpanan, bukan angka hasil hitung — bentuknya disalin dari
/// `lembar_kerja_test.dart` (titik pH 4, Repeat 1).
void main() {
  const alat = 'pH Meter Mettler Toledo · B628755900';
  const userId = 1; // `mock-token-1`

  setUp(() => MockStore.instance.reset());

  Widget app({
    required SimpananDrafLokal simpanan,
    LembarKerjaService? lembar,
    HistoryService? riwayat,
    AutoclaveService? autoclave,
    required Widget Function(BuildContext) tujuan,
  }) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(
        lembar ?? MockLembarKerjaService(),
      ),
      historyServiceProvider.overrideWithValue(riwayat ?? MockHistoryService()),
      autoclaveServiceProvider.overrideWithValue(
        autoclave ?? MockAutoclaveService(),
      ),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      versiServiceProvider.overrideWithValue(MockVersiService()),
      simpananDrafLokalProvider.overrideWithValue(simpanan),
      // Pengirim antrean jangan sampai ke jaringan di test ini.
      pengirimDrafServiceProvider.overrideWithValue(_PengirimMati()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) {
          // Akun harus sudah termuat SEBELUM layar dibuka — salinan selalu
          // ditulis atas nama satu akun.
          ref.watch(authProvider);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: tujuan)),
                child: const Text('buka'),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> pasang(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> pilihAlat(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentLookup>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(alat).last);
    await tester.pumpAndSettle();
  }

  Finder kotakAfter() => find.descendant(
    of: find
        .ancestor(
          of: find.text('After adjustment Reading'),
          matching: find.byType(Column),
        )
        .first,
    matching: find.byType(TextField),
  );

  Future<void> isiTitik4(WidgetTester tester) async {
    await tester.enterText(kotakAfter().at(0), '4.00');
    await tester.enterText(kotakAfter().at(1), '22.2');
    await tester.pump();
  }

  String teksKotak(WidgetTester tester, Finder f) =>
      tester.widget<TextField>(f).controller!.text;

  group('lembar baru', () {
    testWidgets('disimpan otomatis 800 ms sesudah diketik, pulih lewat layar '
        'Draf sesudah aplikasi dimatikan paksa, lalu dibuang dari HP begitu '
        'tersimpan di server', (tester) async {
      // --- Sesi pertama: isi, lalu "dimatikan paksa".
      final hpA = SimpananDrafLokalMemori();
      await pasang(
        tester,
        app(
          simpanan: hpA,
          tujuan: (_) => const LembarKerjaScreen(profil: 'ph_meter'),
        ),
      );
      await pilihAlat(tester);
      await isiTitik4(tester);

      await tester.pump(const Duration(milliseconds: 900));

      final ditulis = await hpA.daftar(userId);
      expect(ditulis, hasLength(1), reason: 'Simpan otomatis nggak jalan.');
      final salinan = ditulis.single;
      expect(salinan.kunci, startsWith('baru-'));
      expect(salinan.status, StatusDrafLokal.lokal);
      expect(salinan.judul, alat);

      // Dimatikan paksa: yang tersisa cuma yang SUDAH ditulis ke disk —
      // bukan hasil `dispose()` yang nggak pernah jalan di kejadian nyata.
      final hpB = SimpananDrafLokalMemori();
      await hpB.simpan(salinan);
      await tester.pumpWidget(const SizedBox());

      // --- Dibuka lagi: layar Draf → "Belum tersinkron di HP ini".
      final lembar = MockLembarKerjaService();
      await pasang(
        tester,
        app(simpanan: hpB, lembar: lembar, tujuan: (_) => const DrafScreen()),
      );

      expect(find.text('Belum tersinkron di HP ini'), findsOneWidget);
      expect(find.text('Draf di server'), findsOneWidget);

      await tester.tap(find.text('Hanya di HP ini — belum disimpan ke server'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dipulihkan dari HP ini'), findsOneWidget);
      expect(teksKotak(tester, kotakAfter().at(0)), '4.00');
      expect(teksKotak(tester, kotakAfter().at(1)), '22.2');
      expect(find.text(alat), findsWidgets, reason: 'Alatnya nggak pulih.');

      // --- Simpan Draf berhasil: id dari server, salinan HP dibuang.
      await tester.tap(find.text('Simpan sebagai draft'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        lembar.payloadTerakhir!['client_request_id'],
        salinan.clientRequestId,
        reason: 'Kunci idempotensi lembar yang dipulihkan berganti.',
      );
      final titik4 = (lembar.payloadTerakhir!['measurements'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['titik_ukur'] == 4.0);
      expect((titik4['pembacaan'] as List).first, 4.0);

      expect(await hpB.daftar(userId), isEmpty);
    });

    testWidgets('lembar baru yang belum disentuh nggak menitipkan apa pun', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await pasang(
        tester,
        app(
          simpanan: hp,
          tujuan: (_) => const LembarKerjaScreen(profil: 'ph_meter'),
        ),
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());

      expect(hp.jumlahTulis, 0);
    });

    testWidgets('Simpan Draf waktu server nggak terjangkau: disimpan di HP, '
        'antre sebagai draft, layar boleh ditutup', (tester) async {
      final hp = SimpananDrafLokalMemori();
      final lembar = _LembarOffline();
      await pasang(
        tester,
        app(
          simpanan: hp,
          lembar: lembar,
          tujuan: (_) => const LembarKerjaScreen(profil: 'ph_meter'),
        ),
      );
      await pilihAlat(tester);
      await isiTitik4(tester);

      await tester.tap(find.text('Simpan sebagai draft'));
      await tester.pumpAndSettle();

      expect(
        find.text('Disimpan di HP, dikirim otomatis saat online'),
        findsOneWidget,
      );
      expect(
        find.text('buka'),
        findsOneWidget,
        reason: 'Teknisi tertahan di layar lembar kerja.',
      );

      final d = (await hp.daftar(userId)).single;
      expect(d.status, StatusDrafLokal.belumTersinkron);
      expect(d.dicobaKirim, isTrue);
      expect(d.kiriman!['status'], 'draft');
      expect(d.kiriman!['client_request_id'], d.clientRequestId);
      expect(
        d.kiriman,
        lembar.payloadTerakhir,
        reason:
            'Kiriman antre beda '
            'dari yang dikirim layar.',
      );
    });

    testWidgets(
      'Kirim ke admin waktu server nggak terjangkau TIDAK diantrekan: '
      'galatnya tetap, isiannya tetap di HP',
      (tester) async {
        final hp = SimpananDrafLokalMemori();
        await pasang(
          tester,
          app(
            simpanan: hp,
            lembar: _LembarOffline(),
            tujuan: (_) => const LembarKerjaScreen(profil: 'ph_meter'),
          ),
        );
        await pilihAlat(tester);
        await isiTitik4(tester);

        await tester.tap(find.text('Kirim ke admin'));
        await tester.pumpAndSettle();
        final konfirmasi = find.text('Kirim sekarang');
        if (konfirmasi.evaluate().isNotEmpty) {
          await tester.tap(konfirmasi);
          await tester.pumpAndSettle();
        }

        expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
        expect(
          find.text('Disimpan di HP, dikirim otomatis saat online'),
          findsNothing,
        );
        expect(
          find.text('Kirim ke admin'),
          findsOneWidget,
          reason: 'Layarnya ditutup.',
        );

        final d = (await hp.daftar(userId)).single;
        expect(d.status, StatusDrafLokal.lokal, reason: 'Kiriman final antre.');
        expect(d.kiriman, isNull);
        expect(d.dicobaKirim, isTrue);
      },
    );

    testWidgets('lembar dari HP yang POST-nya pernah putus: disimpan lewat '
        'POST lalu PUT ke id yang dipulangkan', (tester) async {
      // Kiriman sebelumnya mungkin SUDAH sampai server. Replay POST cuma
      // memulangkan sesi lama tanpa membaca isi baru — PUT yang memastikan.
      final pH = daftarAlatMock.firstWhere(
        (e) => '${e.namaAlat} · ${e.serialNumber}' == alat,
      );
      final hp = SimpananDrafLokalMemori();
      final d = DrafLokal(
        userId: userId,
        clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
        profil: 'ph_meter',
        equipmentId: pH.id,
        disimpanPada: DateTime.utc(2026, 10, 14, 6),
        status: StatusDrafLokal.belumTersinkron,
        dicobaKirim: true,
        kiriman: const {'status': 'draft'},
        isian: {
          'alat': pH.toJson(),
          'teks': const {'catatan_teknisi': 'lanjutan'},
        },
      );
      await hp.simpan(d);
      final lembar = _LembarPerekam();

      await pasang(
        tester,
        app(
          simpanan: hp,
          lembar: lembar,
          tujuan: (_) => LembarKerjaScreen(profil: 'ph_meter', drafLokal: d),
        ),
      );

      expect(find.textContaining('Dipulihkan dari HP ini'), findsOneWidget);

      await tester.tap(find.text('Simpan sebagai draft'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(lembar.metode, ['POST', 'PUT']);
      expect(lembar.idPut, [lembar.idPost.single]);
      expect(lembar.payload.last['catatan_teknisi'], 'lanjutan');
      expect(lembar.payload.last['client_request_id'], d.clientRequestId);
      expect(await hp.daftar(userId), isEmpty);
    });

    testWidgets('Autoklaf: Simpan Draf offline mengantrekan body matriks', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await pasang(
        tester,
        app(
          simpanan: hp,
          autoclave: _AutoklafOffline(),
          tujuan: (_) => const LembarKerjaScreen(profil: 'autoclave'),
        ),
      );
      await pilihAlat(tester);

      await tester.tap(find.text('Simpan sebagai draft'));
      await tester.pumpAndSettle();

      final d = (await hp.daftar(userId)).single;
      expect(d.status, StatusDrafLokal.belumTersinkron);
      expect(d.matriks, isTrue);
      expect(d.kiriman!['status'], 'draft');
      expect(d.kiriman!['equipment_id'], isNotNull);
    });
  });

  group('sesi lama', () {
    final diubahServer = DateTime.utc(2026, 10, 14, 6);

    DrafLokal salinanSesi({
      required DateTime disimpan,
      required DateTime basis,
    }) => DrafLokal(
      userId: userId,
      sesiId: 72,
      clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a71',
      profil: 'ph_meter',
      disimpanPada: disimpan,
      basisServer: basis,
      isian: const {
        'teks': {'catatan_teknisi': 'diketik di HP'},
      },
    );

    Future<void> bukaSesi(
      WidgetTester tester,
      SimpananDrafLokal hp, {
      HistoryService? riwayat,
    }) => pasang(
      tester,
      app(
        simpanan: hp,
        riwayat: riwayat ?? _RiwayatSatuSesi(),
        tujuan: (_) => const LembarKerjaScreen(profil: 'ph_meter', sesiId: 72),
      ),
    );

    Finder catatan() => find.widgetWithText(TextField, 'Catatan');

    testWidgets('salinan HP lebih baru dari server: dipakai, dengan banner', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await hp.simpan(
        salinanSesi(
          disimpan: diubahServer.add(const Duration(minutes: 5)),
          basis: diubahServer,
        ),
      );

      await bukaSesi(tester, hp);

      expect(find.textContaining('Dipulihkan dari HP ini'), findsOneWidget);
      expect(teksKotak(tester, catatan()), 'diketik di HP');
    });

    testWidgets('salinan HP lebih lama dari server: versi server dipakai, '
        'salinannya dibuang', (tester) async {
      final hp = SimpananDrafLokalMemori();
      await hp.simpan(
        salinanSesi(
          disimpan: diubahServer.subtract(const Duration(hours: 1)),
          basis: diubahServer.subtract(const Duration(hours: 2)),
        ),
      );

      await bukaSesi(tester, hp);

      expect(find.textContaining('Dipulihkan dari HP ini'), findsNothing);
      expect(teksKotak(tester, catatan()), 'catatan di server');
      expect(
        find.textContaining('lebih lama dari versi server'),
        findsOneWidget,
      );
      expect(await hp.daftar(userId), isEmpty);
    });

    testWidgets('"Buang": salinan dihapus, lembar dimuat ulang dari server', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await hp.simpan(
        salinanSesi(
          disimpan: diubahServer.add(const Duration(minutes: 5)),
          basis: diubahServer,
        ),
      );
      await bukaSesi(tester, hp);

      await tester.tap(find.widgetWithText(TextButton, 'Buang'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Buang'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(await hp.daftar(userId), isEmpty);
      expect(find.textContaining('Dipulihkan dari HP ini'), findsNothing);
      expect(teksKotak(tester, catatan()), 'catatan di server');
    });

    testWidgets(
      'diketik sesudah termuat: disimpan otomatis sebagai sesi-<id>',
      (tester) async {
        final hp = SimpananDrafLokalMemori();
        await bukaSesi(tester, hp);

        // Membuka draf tanpa mengubah apa pun nggak meninggalkan salinan.
        await tester.pump(const Duration(seconds: 3));
        expect(hp.jumlahTulis, 0);

        await tester.enterText(catatan(), 'diubah teknisi');
        await tester.pump(const Duration(seconds: 3));

        final d = (await hp.daftar(userId)).single;
        expect(d.kunci, 'sesi-72');
        expect(d.basisServer, diubahServer);
        expect((d.isian['teks'] as Map)['catatan_teknisi'], 'diubah teknisi');
      },
    );

    testWidgets('sesi yang sudah disetujui nggak pernah disimpan otomatis', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await bukaSesi(
        tester,
        hp,
        riwayat: _RiwayatSatuSesi(status: 'disetujui'),
      );

      await tester.enterText(catatan(), 'nggak boleh kesimpan');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());

      expect(hp.jumlahTulis, 0);
    });

    testWidgets('sesi yang gagal dimuat nggak disimpan otomatis', (
      tester,
    ) async {
      final hp = SimpananDrafLokalMemori();
      await bukaSesi(tester, hp, riwayat: _RiwayatGagal());

      expect(find.textContaining('belum berhasil dimuat'), findsOneWidget);

      await tester.enterText(catatan(), 'formulir kosong');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());

      expect(hp.jumlahTulis, 0);
    });
  });
}

class _LembarPerekam extends MockLembarKerjaService {
  final metode = <String>[];
  final idPost = <int>[];
  final idPut = <int>[];

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    metode.add('POST');
    final id = await super.kirim(token, isian);
    idPost.add(id);
    return id;
  }

  @override
  Future<int> perbarui(
    String token,
    int id,
    LembarKerjaSubmission isian,
  ) async {
    metode.add('PUT');
    idPut.add(id);
    return super.perbarui(token, id, isian);
  }
}

class _LembarOffline extends MockLembarKerjaService {
  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    payload.add(isian.toJson());
    throw const KoneksiException(
      'Nggak bisa nyambung ke server. Cek koneksi kamu.',
    );
  }

  @override
  Future<int> perbarui(
    String token,
    int id,
    LembarKerjaSubmission isian,
  ) async {
    payload.add(isian.toJson());
    throw const KoneksiException(
      'Nggak bisa nyambung ke server. Cek koneksi kamu.',
    );
  }
}

class _AutoklafOffline extends MockAutoclaveService {
  @override
  Future<int> simpan(String token, Map<String, dynamic> payload) async {
    throw const KoneksiException('Server nggak nyaut. Coba lagi sebentar.');
  }
}

class _RiwayatSatuSesi extends MockHistoryService {
  _RiwayatSatuSesi({this.status = 'draft'});

  final String status;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': id,
        'status': status,
        'desimal': 2,
        'updated_at': '2026-10-14T06:00:00Z',
        'catatan_teknisi': 'catatan di server',
        'equipment': {'nama_alat': 'pH Meter', 'profil': 'ph_meter'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'titik': const <Map<String, dynamic>>[],
        'pembacaan_mentah': const <Map<String, dynamic>>[],
      });
}

class _RiwayatGagal extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      throw Exception('simulasi: server tidak terjangkau');
}

class _PengirimMati implements PengirimDrafService {
  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async => throw const KoneksiException('offline');

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async => throw const KoneksiException('offline');
}
