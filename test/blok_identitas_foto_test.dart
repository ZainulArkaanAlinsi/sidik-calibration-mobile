import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/customer_lookup.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show equipmentLookupServiceProvider;
import 'package:sidik_calibration/providers/equipment_provider.dart'
    show equipmentServiceProvider;
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/pindai/blok_identitas_foto.dart';
import 'package:sidik_calibration/screens/pindai/identitas_foto_isian.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart'
    show EquipmentLookupService, daftarAlatMock;
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/layanan_alat_uji.dart';

/// Blok identitas di atas lembar dari foto: keadaan cocok, mirip, baru, seri
/// kosong, PT mirip, tidak terbaca, galat server, dan ganti akun. Layanan
/// TIRUAN yang meniru aturan server (seri dinormalkan, 409 PT mirip, 422 seri
/// kembar); yang dijaga: tidak ada alat yang dipilih atau dibuat tanpa ketukan
/// teknisi, tidak ada duplikat, dan nilai teknisi tidak pernah tertimpa.

const _bekal = BekalAlatBaru(
  kategori: 'instrumen-analitik',
  namaAlatKemampuan: 'pH Meter',
);

/// Alat pH terdaftar (id 14): merk "Mettler Toledo", model "Five Easy".
final _alat14 = daftarAlatMock.firstWhere((a) => a.id == 14);

const _kertas = IdentitasKertas(
  namaAlat: 'pH Meter',
  merk: 'Mettler',
  seri: 'B628755900',
  pemilik: 'PT Tirta Contoh Mandiri',
  alamat: 'Jl. Contoh Primer A-10',
);

EquipmentLookup _a(
  int id,
  String seri, {
  String kategori = 'instrumen-analitik',
}) => EquipmentLookup(
  id: id,
  namaAlat: 'pH Meter $id',
  serialNumber: seri,
  kategori: kategori,
  status: 'aktif',
);

class _Harness {
  _Harness({
    this.identitas = _kertas,
    List<EquipmentLookup>? alat,
    PtUji? pt,
    this.bekal = _bekal,
    this.pencariKhusus,
  }) : pencari = PencariAlatUji(alat ?? [_alat14]),
       pt = pt ?? PtUji(),
       layanan = LayananAlatUji(),
       penyimpan = InMemoryTokenStorage('mock-token-2') {
    isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uuid-uji',
      tanggalKalibrasiAwal: DateTime(2026, 11, 15),
    );
  }

  final IdentitasKertas identitas;
  final BekalAlatBaru? bekal;
  final PencariAlatUji pencari;
  final EquipmentLookupService? pencariKhusus;
  final PtUji pt;
  final LayananAlatUji layanan;
  final InMemoryTokenStorage penyimpan;
  late final LembarKerjaState isian;
  int berubah = 0;

  Future<void> pasang(
    WidgetTester tester, {
    Size ukuran = const Size(392, 852),
    double skalaHuruf = 1.0,
    EdgeInsets papanKetik = EdgeInsets.zero,
    bool terapkanKertas = true,

    /// `false` = jangan menunggu layar tenang (ada spinner yang berputar karena
    /// jawaban server sengaja ditahan).
    bool tenang = true,
  }) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (terapkanKertas) isian.terapkanIdentitasKertas(identitas);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(penyimpan),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          equipmentLookupServiceProvider.overrideWithValue(
            pencariKhusus ?? pencari,
          ),
          customerLookupServiceProvider.overrideWithValue(pt),
          equipmentServiceProvider.overrideWithValue(layanan),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(skalaHuruf),
              viewInsets: papanKetik,
            ),
            child: child!,
          ),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: StatefulBuilder(
              builder: (context, set) => Column(
                children: [
                  // Seperti di lembar: jatah sendiri (`Flexible`), lembar di bawah.
                  Flexible(
                    child: BlokIdentitasFoto(
                      identitas: identitas,
                      isian: isian,
                      profil: 'ph_meter',
                      bekalAlatBaru: bekal,
                      onBerubah: () {
                        berubah++;
                        set(() {});
                      },
                    ),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (tenang) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

String _teks(LembarKerjaState i, String kode) => i.teks[kode]!.text;

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String _isiKotak(WidgetTester tester, Key k) =>
    tester.widget<TextField>(find.byKey(k)).controller!.text;

bool _terisiKuning(WidgetTester tester, Key k) =>
    tester.widget<TextField>(find.byKey(k)).decoration!.filled ?? false;

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('cocok PERSIS: menunggu ketukan teknisi', () {
    testWidgets('kartu "Alat terdaftar" + selisih; BELUM ada alat yang dipilih '
        'dan master tidak disalin sebelum "Pakai alat ini"', (tester) async {
      final h = _Harness(identitas: _kertas);
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsOneWidget);
      expect(
        find.text('Alat terdaftar: pH Meter Mettler Toledo'),
        findsOneWidget,
      );
      // Selisih terhadap kertas: merk "Mettler" (kertas) lawan master.
      expect(
        find.byKey(BlokIdentitasFoto.kunciBeda('alat_merk')),
        findsOneWidget,
      );
      expect(find.textContaining('kertas "Mettler"'), findsOneWidget);

      // Tidak ada yang dipilih / disalin diam-diam.
      expect(h.isian.alat, isNull);
      expect(_teks(h.isian, 'alat_merk'), 'Mettler');
      expect(_teks(h.isian, 'alat_model'), isEmpty);
      expect(h.berubah, 0, reason: 'lembar belum diberi tahu apa pun');
    });

    testWidgets('"Pakai alat ini": alat dipasang; kertas MENANG atas master di '
        'kotak yang sudah terisi, master hanya mengisi yang kosong', (
      tester,
    ) async {
      final h = _Harness(identitas: _kertas);
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPakaiAlat));

      expect(h.isian.alat?.id, 14);
      expect(h.berubah, 1);
      expect(find.byKey(BlokIdentitasFoto.kunciTerpilih), findsOneWidget);
      // Kertas menang: merk tetap "Mettler" (masih saran kuning).
      expect(_teks(h.isian, 'alat_merk'), 'Mettler');
      expect(h.isian.isianDariFoto, contains('alat_merk'));
      // Kosong di kertas: diisi master, dan itu BUKAN saran dari foto.
      expect(_teks(h.isian, 'alat_model'), 'Five Easy');
      expect(h.isian.isianDariFoto, isNot(contains('alat_model')));
      // Selisih tetap terlihat sesudah dipakai.
      expect(
        find.byKey(BlokIdentitasFoto.kunciBeda('alat_merk')),
        findsOneWidget,
      );
    });

    testWidgets('"Pakai yang terdaftar" per baris: nilai master menggantikan, '
        'tanda dari-foto dilepas, selisihnya hilang', (tester) async {
      final h = _Harness(identitas: _kertas);
      await h.pasang(tester);
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPakaiAlat));

      await _ketuk(
        tester,
        find.byKey(BlokIdentitasFoto.kunciPakaiTerdaftar('alat_merk')),
      );

      expect(_teks(h.isian, 'alat_merk'), 'Mettler Toledo');
      expect(h.isian.isianDariFoto, isNot(contains('alat_merk')));
      expect(
        find.byKey(BlokIdentitasFoto.kunciBeda('alat_merk')),
        findsNothing,
      );
    });

    testWidgets('nilai yang DIKETIK teknisi tidak ikut ditimpa oleh "Pakai '
        'alat ini"', (tester) async {
      final h = _Harness(identitas: _kertas);
      h.isian.teks['alat_model']!.text = 'Ketikan teknisi';
      await h.pasang(tester);
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPakaiAlat));

      expect(_teks(h.isian, 'alat_model'), 'Ketikan teknisi');
    });

    testWidgets('seri kertas bertanda baca/huruf kecil tetap cocok persis', (
      tester,
    ) async {
      final h = _Harness(
        identitas: const IdentitasKertas(seri: 'b 628-755 900'),
      );
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsOneWidget);
      expect(h.pencari.dipanggil, greaterThan(0));
    });
  });

  group('MIRIP: "Maksud Anda?"', () {
    final alat = [
      _a(21, 'B628755901'),
      _a(22, 'B628755800'),
      _a(23, 'B628755910'),
      _a(24, 'B628755911'),
      _a(25, 'ZZ-0000'),
    ];

    testWidgets('paling banyak tiga pilihan; satu ketukan memasang alat itu; '
        'tidak ada yang dipilihkan', (tester) async {
      final h = _Harness(identitas: _kertas, alat: alat);
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciMirip), findsOneWidget);
      expect(find.text('Maksud Anda?'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith(
                'identitas-pilih-mirip-',
              ),
        ),
        findsNWidgets(3),
      );
      expect(h.isian.alat, isNull);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPilihMirip(21)));

      expect(h.isian.alat?.id, 21);
      expect(find.byKey(BlokIdentitasFoto.kunciTerpilih), findsOneWidget);
    });

    testWidgets('"Bukan salah satunya" membuka panel alat baru; Batal kembali '
        'ke pilihan', (tester) async {
      final h = _Harness(identitas: _kertas, alat: alat);
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciMiripBaru));
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBatalBaru));
      expect(find.byKey(BlokIdentitasFoto.kunciMirip), findsOneWidget);
    });
  });

  group('alat BARU: panel inline "Buat dan lanjut"', () {
    testWidgets('panel terisi dari kertas (kuning); mengubah kotak melepas '
        'warna kuningnya', (tester) async {
      final h = _Harness(identitas: _kertas, alat: const []);
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
      expect(_isiKotak(tester, BlokIdentitasFoto.kunciKotakSeri), 'B628755900');
      expect(
        _isiKotak(tester, BlokIdentitasFoto.kunciKotakPemilik),
        'PT Tirta Contoh Mandiri',
      );
      expect(find.text('Jenis: pH Meter'), findsOneWidget);
      expect(_terisiKuning(tester, BlokIdentitasFoto.kunciKotakSeri), isTrue);

      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakSeri),
        'B628755901',
      );
      await tester.pump();
      expect(_terisiKuning(tester, BlokIdentitasFoto.kunciKotakSeri), isFalse);
      // Kotak lain tetap kuning.
      expect(_terisiKuning(tester, BlokIdentitasFoto.kunciKotakMerk), isTrue);
    });

    testWidgets('"Buat dan lanjut": PT didaftarkan, alat dibuat (jenis dari '
        'lembar), dipasang ke lembar; nilai panel yang diedit teknisi menjadi '
        'nilai lembar', (tester) async {
      final h = _Harness(identitas: _kertas, alat: const []);
      await h.pasang(tester);

      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakMerk),
        'Mettler Toledo',
      );
      await tester.pump();
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.pt.didaftarkan, 1);
      expect(h.layanan.dikirim, hasLength(1));
      final kirim = h.layanan.dikirim.single;
      expect(kirim.serialNumber, 'B628755900');
      expect(kirim.merk, 'Mettler Toledo');
      expect(kirim.kategori, 'instrumen-analitik');
      expect(kirim.namaAlatKemampuan, 'pH Meter');
      expect(kirim.pelangganId, 901);

      expect(h.isian.alat?.serialNumber, 'B628755900');
      expect(find.byKey(BlokIdentitasFoto.kunciTerpilih), findsOneWidget);
      // Merk diedit teknisi di panel: nilai manusia, bukan saran kuning lagi.
      expect(_teks(h.isian, 'alat_merk'), 'Mettler Toledo');
      expect(h.isian.isianDariFoto, isNot(contains('alat_merk')));
      // Seri tidak diubah: tetap saran kuning yang wajib dicek.
      expect(h.isian.isianDariFoto, contains('alat_serial_number'));
      expect(
        find.textContaining('tersimpan dan langsung dipakai'),
        findsOneWidget,
      );
    });

    testWidgets('kotak lembar yang diketik teknisi tidak ditimpa nilai panel', (
      tester,
    ) async {
      final h = _Harness(identitas: _kertas, alat: const []);
      // Teknisi mengetik merk di lembar sebelum membuat alat.
      h.isian.teks['alat_merk']!.text = 'Ketikan teknisi';
      h.isian.isianDariFoto.remove('alat_merk');
      await h.pasang(tester, terapkanKertas: false);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.layanan.dikirim.single.merk, 'Mettler');
      expect(_teks(h.isian, 'alat_merk'), 'Ketikan teknisi');
    });

    testWidgets('nama dan pemilik wajib: kotak kosong menolak dengan pesan, '
        'tidak ada yang dibuat', (tester) async {
      final h = _Harness(
        identitas: const IdentitasKertas(seri: 'SN-4471'),
        alat: const [],
        bekal: const BekalAlatBaru(
          kategori: 'instrumen-analitik',
          namaAlatKemampuan: '',
        ),
      );
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(find.text('Wajib diisi.'), findsWidgets);
      expect(h.layanan.dikirim, isEmpty);
      expect(h.pt.didaftarkan, 0);
    });

    testWidgets('jenis lembar tanpa kategori di master: tidak ada panel, '
        'pesan mengarahkan ke form Alat baru', (tester) async {
      final h = _Harness(
        identitas: _kertas,
        alat: const [],
        bekal: const BekalAlatBaru(namaAlatKemampuan: 'pH Meter'),
      );
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciKategoriKosong), findsOneWidget);
    });
  });

  group(
    'nomor seri kosong: WAJIB diketik, tidak pernah membuat tanpa seri',
    () {
      testWidgets('kertas tanpa seri: panel dengan pesan, TANPA kueri server', (
        tester,
      ) async {
        final h = _Harness(
          identitas: const IdentitasKertas(
            namaAlat: 'pH Meter',
            merk: 'Mettler',
            pemilik: 'PT Tirta Contoh Mandiri',
          ),
          alat: [_alat14],
        );
        await h.pasang(tester);

        expect(h.pencari.dipanggil, 0);
        expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
        expect(
          find.text('Nomor seri tidak terbaca. Ketik dari badan alat.'),
          findsOneWidget,
        );

        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

        expect(h.layanan.dikirim, isEmpty);
        expect(h.pt.didaftarkan, 0, reason: 'tidak ada PT yatim');
      });

      testWidgets('seri diketik teknisi lalu dibuat: jalan normal', (
        tester,
      ) async {
        final h = _Harness(
          identitas: const IdentitasKertas(
            namaAlat: 'pH Meter',
            pemilik: 'PT Tirta Contoh Mandiri',
          ),
          alat: const [],
        );
        await h.pasang(tester);

        await tester.enterText(
          find.byKey(BlokIdentitasFoto.kunciKotakSeri),
          'SN-9001',
        );
        await tester.pump();
        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

        expect(h.layanan.dikirim.single.serialNumber, 'SN-9001');
        expect(h.isian.alat, isNotNull);
      });
    },
  );

  group('PT mirip: teknisi memutuskan', () {
    const mirip = [
      CustomerLookup(id: 3, nama: 'PT Tirta Contoh Abadi'),
      CustomerLookup(id: 4, nama: 'PT Tirta Contoh Makmur'),
    ];

    testWidgets('409 mirip: kandidat tampil, BELUM ada alat dan PT dibuat; '
        'memilih kandidat membuat alat untuk PT itu', (tester) async {
      final h = _Harness(
        identitas: _kertas,
        alat: const [],
        pt: PtUji(mirip: mirip),
      );
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(find.byKey(BlokIdentitasFoto.kunciPtMirip), findsOneWidget);
      expect(h.layanan.dikirim, isEmpty);
      expect(h.pt.didaftarkan, 0);
      expect(h.isian.alat, isNull);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPilihPt(4)));

      expect(h.layanan.dikirim.single.pelangganId, 4);
      expect(h.pt.didaftarkan, 0, reason: 'memakai PT yang sudah ada');
      expect(h.isian.alat, isNotNull);
    });

    testWidgets('"Tetap buat PT baru": tetap_buat dikirim', (tester) async {
      final h = _Harness(
        identitas: _kertas,
        alat: const [],
        pt: PtUji(mirip: mirip),
      );
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPtBaru));

      expect(h.pt.terakhirTetapBuat, isTrue);
      expect(h.pt.didaftarkan, 1);
      expect(h.isian.alat, isNotNull);
    });
  });

  group('tidak menduplikasi', () {
    testWidgets('seri sudah dipakai alat jenis LAIN: ditolak di kotak seri, '
        'tidak dibuat', (tester) async {
      final lain = _a(77, 'B628755900', kategori: 'suhu');
      final h = _Harness(identitas: _kertas, alat: [lain]);
      // Tidak ikut pencarian per jenis lembar, tetapi ada di lab.
      h.pencari.sembunyikanDariProfil = {77};
      await h.pasang(tester);
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(
        find.textContaining('sudah dipakai "pH Meter 77" (jenis alat lain)'),
        findsOneWidget,
      );
      expect(h.layanan.dikirim, isEmpty);
      expect(h.isian.alat, isNull);
    });

    testWidgets('seri diketik ternyata sudah terdaftar (sejenis): alat yang '
        'ada dipakai, tidak dibuat ganda', (tester) async {
      final ada = _a(88, 'SN-7777');
      final h = _Harness(identitas: _kertas, alat: const []);
      await h.pasang(tester);
      // Perangkat lain mendaftarkannya sesudah blok mencocokkan.
      h.pencari.alat.add(ada);
      await tester.enterText(
        find.byKey(BlokIdentitasFoto.kunciKotakSeri),
        'SN 7777',
      );
      await tester.pump();

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

      expect(h.layanan.dikirim, isEmpty);
      expect(h.isian.alat?.id, 88);
      expect(find.textContaining('tidak dibuat ganda'), findsOneWidget);
    });

    testWidgets('dua ketukan cepat "Buat dan lanjut": satu alat', (
      tester,
    ) async {
      final h = _Harness(identitas: _kertas, alat: const []);
      await h.pasang(tester);

      final tombol = find.byKey(BlokIdentitasFoto.kunciBuatLanjut);
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.tap(tombol, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.layanan.dikirim, hasLength(1));
    });

    testWidgets(
      'gagal (sinyal) lalu coba lagi: PT tidak didaftarkan dua kali',
      (tester) async {
        final h = _Harness(identitas: _kertas, alat: const []);
        var gagal = true;
        h.layanan.sebelumSimpan = (_) async {
          if (gagal) {
            gagal = false;
            throw Exception('putus');
          }
        };
        await h.pasang(tester);

        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
        expect(find.byKey(BlokIdentitasFoto.kunciGalat), findsOneWidget);
        expect(find.textContaining('Periksa sinyal'), findsOneWidget);
        expect(h.isian.alat, isNull);
        expect(h.pt.didaftarkan, 1);

        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));
        expect(h.isian.alat, isNotNull);
        expect(h.pt.didaftarkan, 1, reason: 'PT tidak kembar');
        expect(h.layanan.dikirim, hasLength(1));
      },
    );
  });

  group('jujur bila tidak bisa', () {
    testWidgets('identitas tidak terbaca sama sekali: pesan, tanpa kueri '
        'server, tanpa panel otomatis', (tester) async {
      final h = _Harness(identitas: IdentitasKertas.kosong);
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciTidakTerbaca), findsOneWidget);
      expect(h.pencari.dipanggil, 0);
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsNothing);

      await _ketuk(tester, find.text('Alat baru'));
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsOneWidget);
    });

    testWidgets('server tidak terjangkau: pesan jujur (BUKAN "alat baru"), '
        '"Coba lagi" menanyakan ulang', (tester) async {
      final h = _Harness(identitas: _kertas);
      h.pencari.gagal = true;
      await h.pasang(tester);

      expect(find.byKey(BlokIdentitasFoto.kunciGagalCocok), findsOneWidget);
      expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsNothing);

      h.pencari.gagal = false;
      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciUlangCocok));

      expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsOneWidget);
    });

    testWidgets('"Tutup": blok hilang, lembar tetap bisa dipakai manual', (
      tester,
    ) async {
      final h = _Harness(identitas: _kertas);
      await h.pasang(tester);

      await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciTutup));

      expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsNothing);
      expect(h.isian.alat, isNull);
    });
  });

  group('tanggal di kertas: saran, bukan diterapkan diam-diam', () {
    testWidgets('tanggal beda dari lembar: baris kuning + "Pakai tanggal ini"; '
        'sama = tidak ada baris', (tester) async {
      final h = _Harness(
        identitas: IdentitasKertas(
          seri: 'B628755900',
          tanggalKalibrasi: DateTime(2026, 11, 13),
          tanggalTerima: DateTime(2026, 11, 15),
        ),
      );
      await h.pasang(tester);

      expect(
        find.text('Tanggal kalibrasi di kertas: 13 Nov 2026'),
        findsOneWidget,
      );
      // Lembar sudah bertanggal 15 Nov (hari ini): tanggal terima di kertas sama,
      // tidak perlu saran.
      expect(find.byKey(BlokIdentitasFoto.kunciTanggalTerima), findsOneWidget);
      expect(
        h.isian.tanggal['tanggal_kalibrasi'],
        DateTime(2026, 11, 15),
        reason: 'tidak diterapkan diam-diam',
      );

      await _ketuk(
        tester,
        find.descendant(
          of: find.byKey(BlokIdentitasFoto.kunciTanggalKalibrasi),
          matching: find.byType(OutlinedButton),
        ),
      );

      expect(h.isian.tanggal['tanggal_kalibrasi'], DateTime(2026, 11, 13));
      expect(find.byKey(BlokIdentitasFoto.kunciTanggalKalibrasi), findsNothing);
    });
  });

  group('ganti akun di tengah lembar (sidik-fe-scope-akun)', () {
    testWidgets('hasil pencocokan akun lama yang datang SESUDAH ganti akun '
        'dibuang; tidak ada alat terpasang', (tester) async {
      final tahan = Completer<void>();
      final pencari = _PencariTertahan(tahan.future, [_alat14]);
      final h = _Harness(identitas: _kertas, pencariKhusus: pencari);
      await h.pasang(tester, tenang: false);
      expect(find.byKey(BlokIdentitasFoto.kunciMencocokkan), findsOneWidget);

      // Akun A (teknisi) selesai dimuat; pencocokan masih menunggu server.
      final wadah = ProviderScope.containerOf(
        tester.element(find.byKey(BlokIdentitasFoto.kunci)),
      );
      // `authProvider` memakai timer sungguhan: tunggu di luar jam palsu.
      await tester.runAsync(() => wadah.read(authProvider.future));
      await tester.pump();
      expect(find.byKey(BlokIdentitasFoto.kunciMencocokkan), findsOneWidget);

      // Akun B (admin) masuk di HP yang sama.
      await h.penyimpan.write('mock-token-1');
      wadah.invalidate(authProvider);
      await tester.runAsync(() => wadah.read(authProvider.future));
      await tester.pump();
      await tester.pump();

      tahan.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsNothing);
      expect(find.byKey(BlokIdentitasFoto.kunciMencocokkan), findsNothing);
      expect(h.isian.alat, isNull);
    });
  });

  group('tata letak: tidak meluap di HP sempit, huruf besar, lanskap, papan '
      'ketik', () {
    for (final (nama, ukuran, huruf, ketik) in [
      ('320 x 640, huruf 2,0', const Size(320, 640), 2.0, EdgeInsets.zero),
      ('392 x 852, huruf 1,0', const Size(392, 852), 1.0, EdgeInsets.zero),
      ('600 x 900, huruf 1,5', const Size(600, 900), 1.5, EdgeInsets.zero),
      ('840 x 360 lanskap', const Size(840, 360), 1.0, EdgeInsets.zero),
      (
        '320 x 640 papan ketik, huruf 2,0',
        const Size(320, 640),
        2.0,
        const EdgeInsets.only(bottom: 280),
      ),
    ]) {
      testWidgets('panel alat baru + PT mirip + galat: $nama', (tester) async {
        final h = _Harness(
          identitas: _kertas,
          alat: const [],
          pt: PtUji(
            mirip: const [
              CustomerLookup(
                id: 3,
                nama: 'PT Tirta Contoh Abadi Nusantara Sejahtera',
                alamat: 'Jl. Contoh Primer A-10, Kec. Cicalengka',
              ),
            ],
          ),
        );
        await h.pasang(
          tester,
          ukuran: ukuran,
          skalaHuruf: huruf,
          papanKetik: ketik,
        );
        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciBuatLanjut));

        expect(find.byKey(BlokIdentitasFoto.kunciPtMirip), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (nama, ukuran, huruf) in [
      ('320 x 640, huruf 2,0', const Size(320, 640), 2.0),
      ('600 x 900, huruf 1,0', const Size(600, 900), 1.0),
    ]) {
      testWidgets('kartu cocok dengan selisih + tanggal: $nama', (
        tester,
      ) async {
        final h = _Harness(
          identitas: IdentitasKertas(
            merk: 'Mettler Instrument Corporation Internasional',
            model: 'Five Easy Plus Edisi Panjang Sekali',
            seri: 'B628755900',
            pemilik: 'PT Tirta Contoh Mandiri Sejahtera Abadi',
            tanggalKalibrasi: DateTime(2026, 11, 13),
          ),
        );
        await h.pasang(tester, ukuran: ukuran, skalaHuruf: huruf);
        await _ketuk(tester, find.byKey(BlokIdentitasFoto.kunciPakaiAlat));

        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Pencari yang menahan jawabannya sampai [tahan] selesai.
class _PencariTertahan extends PencariAlatUji {
  _PencariTertahan(this.tahan, List<EquipmentLookup> awal) : super(awal);

  final Future<void> tahan;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async {
    await tahan;

    return super.cari(
      token,
      search: search,
      kategori: kategori,
      profil: profil,
    );
  }
}
