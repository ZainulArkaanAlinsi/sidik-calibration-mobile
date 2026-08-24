import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// JALAN MASUK ke lembar kerja TITS — bagian yang selama ini bolong.
///
/// Lembar kerjanya sendiri sudah jadi & teruji (`lembar_kerja_tits_render_test`),
/// tapi tidak ada satu pun jalur di aplikasi yang membukanya: nama alat TITS
/// belum terdaftar di `_profilKhusus`, kategori `suhu-dan-kelembapan` pulang
/// kosong dari mock, dan sesi yang dibuka lagi nebak profil dari nama alat
/// PELANGGAN yang tidak pernah menyebut jenis alatnya.
///
/// Ketiganya gagal TANPA error: teknisi dapat formulir yang salah — pH, tiga
/// titik 4/7/10,01 — di atas lembar suhu sembilan titik −20…1000 °C, dan
/// angkanya tetap masuk.
void main() {
  group('nama alat → profil lembar kerja', () {
    test('dua ejaan lampiran akreditasi & lembar kerja sama-sama kenal', () {
      // Lampiran akreditasi LK-285-IDN no. 1 nulis "Indicator" (Inggris),
      // judul lembar kerjanya "Indikator" (Indonesia).
      expect(
        profilLembarKerjaUntuk('Temperature Indicator tanpa Sensor'),
        'tits',
      );
      expect(
        profilLembarKerjaUntuk('Temperature Indikator Tanpa Sensor'),
        'tits',
      );
    });

    test('beda huruf besar/kecil & spasi dobel tetap kena', () {
      expect(
        profilLembarKerjaUntuk('  TEMPERATURE   INDICATOR  TANPA SENSOR '),
        'tits',
      );
    });

    test('nama alat pelanggan NGGAK ketebak — itu tugas `equipment.profil`', () {
      // Kedua alat di sesi master terdaftar dengan nama ini. Nol kemiripan
      // sama "Temperature Indicator tanpa Sensor", jadi menebak dari nama
      // memang mustahil di sini — dan itulah kenapa backend mengirim
      // `equipment.profil` yang sudah jadi.
      expect(profilLembarKerjaUntuk('Temperature Calibrator'), isNull);
      expect(profilLembarKerjaUntuk('Temperature Recorder Controller'), isNull);
    });

    test('sepuluh alat lain nggak kesenggol', () {
      expect(profilLembarKerjaUntuk('pH Meter'), 'ph_meter');
      expect(profilLembarKerjaUntuk('Autoklaf'), 'autoclave');
      expect(profilLembarKerjaUntuk('Jangka Sorong'), isNull);
    });
  });

  group('profil dari respons sesi', () {
    Map<String, dynamic> sesi(Map<String, dynamic> equipment) => {
      'id': 7,
      'tanggal_kalibrasi': '2026-06-10',
      'status': 'draft',
      'equipment': equipment,
      'teknisi': {'nama': 'Rohman'},
    };

    test('CalibrationDetail baca `equipment.profil`', () {
      final d = CalibrationDetail.fromJson(sesi({
        'id': 3,
        'nama_alat': 'Temperature Recorder Controller',
        'profil': 'tits',
      }));

      expect(d.profil, 'tits');
      // Nama alat pelanggan tetap dipulangkan apa adanya — dipakai buat judul,
      // bukan buat nebak profil.
      expect(d.namaAlat, 'Temperature Recorder Controller');
    });

    test('CalibrationHistoryItem baca `equipment.profil`', () {
      final h = CalibrationHistoryItem.fromJson(sesi({
        'id': 3,
        'nama_alat': 'Temperature Calibrator',
        'profil': 'tits',
      }));

      expect(h.profil, 'tits');
    });

    test('server lama tanpa kunci `profil` pulang null, bukan meledak', () {
      final d = CalibrationDetail.fromJson(sesi({
        'id': 3,
        'nama_alat': 'pH Meter Mettler Toledo',
      }));

      expect(d.profil, isNull);
      // Pemanggil balik nebak dari nama, persis perilaku lama.
      expect(profilLembarKerjaUntuk(d.namaAlat), 'ph_meter');
    });

    test('`copyWith` riwayat nggak ngilangin profil', () {
      final h = CalibrationHistoryItem.fromJson(sesi({
        'id': 3,
        'nama_alat': 'Temperature Calibrator',
        'profil': 'tits',
      }));

      expect(h.copyWith(catatanRevisi: 'ulangi titik 600').profil, 'tits');
    });
  });

  group('kartu TITS di picker', () {
    Widget app(Category kategori) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        categoryServiceProvider.overrideWithValue(MockCategoryService()),
        lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
        standardServiceProvider.overrideWithValue(MockStandardService()),
        roomServiceProvider.overrideWithValue(MockRoomService()),
        equipmentLookupServiceProvider.overrideWithValue(
          MockEquipmentLookupService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstrumentPickerScreen(kategori: kategori),
      ),
    );

    const suhu = Category(
      kode: 'suhu-dan-kelembapan',
      nama: 'Suhu & Kelembapan',
      satuan: '°C',
    );

    testWidgets('sepuluh baris CMC dua nama alat jadi SATU kartu', (
      tester,
    ) async {
      await tester.pumpWidget(app(suhu));
      await tester.pumpAndSettle();

      // Tujuh baris TITS (Type K/J/T/N/R/S + RTD) + tiga baris TIDS — kalau
      // dedupe-nya lepas, teknisi lihat sepuluh kartu.
      //
      // Judulnya "Temperatur Indikator", bukan salah satu nama panjangnya:
      // kartunya sekarang PINTU buat dua-duanya, dan varian-nya dipilih di
      // `TemperaturIndikatorGerbangScreen` (permintaan pemilik proyek, Agu
      // 2026). Nyetak salah satu nama panjang di kartu gabungan bikin teknisi
      // ngira varian yang satunya nggak ada.
      expect(find.text('Temperatur Indikator'), findsOneWidget);
      expect(find.text('Temperature Indicator tanpa Sensor'), findsNothing);
    });

    testWidgets('lewat gerbang, "tanpa sensor" mbuka lembar TITS', (
      tester,
    ) async {
      // Lembar TITS panjang — di layar 800x600 bawaan, dua dropdown-nya ada di
      // pohon tapi belum kegambar, dan `find.text` cuma lihat yang kegambar.
      tester.view.physicalSize = const Size(1400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(suhu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tanpa Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final layar = tester.widget<LembarKerjaScreen>(
        find.byType(LembarKerjaScreen),
      );
      expect(layar.profil, 'tits');

      // Dua dropdown yang cuma TITS punya — bukti lembarnya bener, bukan cuma
      // kode profil yang kebetulan lewat.
      expect(find.text('1. Mode'), findsOneWidget);
      expect(find.text('2. Temperature Type'), findsOneWidget);
    });
  });

  group('bentuk lembar TITS mock ikut server', () {
    test('blok STANDARD bawa dua kalibrator lab', () {
      final bentuk = contohBentukLembarKerjaTits();
      final bagian = (bentuk['bagian'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['kode'] == 'usage_check');

      final baris = (bagian['baris'] as List).cast<Map<String, dynamic>>();

      // Merk kalibrator yang MENENTUKAN tabel koreksi mana yang dipakai
      // backend. Tanpa blok ini teknisi nggak punya cara ngeganti dari
      // Yokogawa ke Constant sama sekali.
      expect(
        baris.map((b) => b['label']),
        containsAll([
          'Temperature Calibrator Constant 40T',
          'Temperature Calibrator Yokogawa CA 150 Handy Cal',
        ]),
      );
      expect(baris.every((b) => b['standard_id'] != null), isTrue);
    });

    test('tiap baris titik bawa kalibrator sebagai nilai awal', () {
      final bentuk = contohBentukLembarKerjaTits();
      final hasil = (bentuk['bagian'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['kode'] == 'hasil');

      final tabel = (hasil['tabel'] as List).cast<Map<String, dynamic>>();

      for (final t in tabel) {
        final baris = (t['baris'] as List).cast<Map<String, dynamic>>();
        expect(baris, isNotEmpty);
        // Yokogawa, bukan Constant — kedua sesi master pakai itu, dan
        // sertifikat Constant 40T sudah lewat masa berlaku.
        expect(
          baris.every(
            (b) =>
                b['standard_nama'] ==
                'Temperature Calibrator Yokogawa CA 150 Handy Cal',
          ),
          isTrue,
        );
      }
    });

    test('standar kalibrator ada di master mock, jadi Usage Check ketaut', () async {
      final bentuk = contohBentukLembarKerjaTits();
      final bagian = (bentuk['bagian'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['kode'] == 'usage_check');

      final idBentuk = (bagian['baris'] as List)
          .cast<Map<String, dynamic>>()
          .map((b) => b['standard_id'] as int)
          .toSet();

      final master = await MockStandardService().daftar('mock-token-1');

      expect(idBentuk.difference(master.map((s) => s.id).toSet()), isEmpty);
    });
  });

  group('penjaga dua dropdown penentu angka', () {
    LembarKerjaState state(Map<String, dynamic> bentuk) => LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentuk),
      clientRequestId: 'uji',
    );

    test('dua-duanya kosong waktu lembar baru dibuka', () {
      final isian = state(contohBentukLembarKerjaTits());

      expect(
        isian.pilihanPenentuAngkaKosong.map((f) => f.kode),
        containsAll(['mode_kalibrasi', 'tipe_sensor']),
      );
    });

    test('yang udah dipilih hilang dari daftar', () {
      final isian = state(contohBentukLembarKerjaTits());

      isian.teks['mode_kalibrasi']!.text = 'source';

      expect(
        isian.pilihanPenentuAngkaKosong.map((f) => f.kode),
        ['tipe_sensor'],
      );
    });

    test('kosong begitu dua-duanya kepilih', () {
      final isian = state(contohBentukLembarKerjaTits());

      isian.teks['mode_kalibrasi']!.text = 'measure';
      isian.teks['tipe_sensor']!.text = 'Type N';

      expect(isian.pilihanPenentuAngkaKosong, isEmpty);
    });

    test('alat lain nggak pernah kena — lembarnya nggak punya field itu', () {
      final isian = state(contohBentukLembarKerja());

      expect(isian.pilihanPenentuAngkaKosong, isEmpty);
    });
  });
}
