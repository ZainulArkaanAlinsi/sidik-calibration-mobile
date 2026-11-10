import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/peran_isian_identitas.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_massa.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetric_glassware.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/dekorasi_isian_wajib.dart';

/// Warna bidang IDENTITAS alat menurut ISI (lihat `peran_isian_identitas.dart`
/// dan `dekorasi_isian_wajib.dart`).
///
/// Yang dikunci: (1) tabel kode -> peran, (2) cakupan jujur enam alat
/// prioritas, (3) keadaan kosong -> oranye / terisi -> hijau, baik yang
/// diketik teknisi maupun yang otomatis dari data alat (kunci + petunjuk),
/// (4) tema gelap, (5) tanpa scope tampil biasa, (6) hasil hitung server tetap
/// abu kebiruan, (7) legenda.
///
/// Sumber kode kolom: bentuk lembar server (`*Profile::bentukLembarKerja`, API
/// `main` 10 Nov 2026) dan cermin lokalnya `contoh_lembar_kerja_*`.
void main() {
  // ---------------------------------------------------------------------------
  // 1. Tabel kode -> peran
  // ---------------------------------------------------------------------------
  group('tabel peran isian identitas', () {
    Set<String> kodeBerperan(PeranIsian peran) => {
      for (final e in peranIsianIdentitas.entries)
        if (e.value == peran) e.key,
    };

    test('daftar identitas-wajib persis seperti diputuskan (dikunci)', () {
      expect(kodeBerperan(PeranIsian.identitasWajib), {
        // nama alat
        'equipment.nama_alat',
        // merek / tipe / nomor seri — dari alat
        'equipment.merk',
        'equipment.model',
        'equipment.serial_number',
        // merek / tipe / nomor seri — diketik teknisi
        'alat_merk',
        'alat_model',
        'alat_serial_number',
        // pelanggan
        'pemilik_nama',
        'pemilik_alamat',
        'customer.nama',
        'customer.alamat',
        // kapasitas / rentang ukur / resolusi
        'equipment.range_resolusi',
        'spesifikasi_alat.kapasitas',
        'spesifikasi_alat.resolusi',
        'spesifikasi_alat.rentang_ukur',
        'spesifikasi_alat.volumetric.kapasitas_ml',
        'spesifikasi_alat.volumetric.resolusi_ml',
        // lokasi, tanggal kalibrasi
        'lokasi',
        'lokasi_nama',
        'tanggal_kalibrasi',
      });
    });

    test('yang sengaja netral tercatat eksplisit, tidak ikut diwarnai', () {
      expect(kodeBerperan(PeranIsian.opsional), {
        'tanggal_terima',
        'room_id',
        'nomor_order',
        'spesifikasi_alat.volumetric.kelas',
        'spesifikasi_alat.volumetric.toleransi_ml',
        'spesifikasi_alat.tipe_thermocouple',
        'spesifikasi_alat.nilai_e',
        'spesifikasi_alat.kelas',
      });

      for (final kode in kodeBerperan(PeranIsian.opsional)) {
        expect(adalahIdentitasWajib(kode), isFalse, reason: kode);
      }
    });

    test('kode yang tidak ada di tabel tidak ditebak jadi identitas', () {
      for (final kode in const [
        'suhu_awal',
        'catatan_teknisi',
        'tipe_sensor',
        'thermohygro_standard_id',
        'kode_ngawur',
      ]) {
        expect(adalahIdentitasWajib(kode), isFalse, reason: kode);
      }
    });

    LembarKerjaState isianDari(Map<String, dynamic> bentuk) => LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentuk),
      clientRequestId: 'uji-identitas',
    );

    FieldLembarKerja fieldDi(LembarKerjaState isian, String kode) => [
      for (final b in isian.bentuk.bagian) ...b.field,
    ].firstWhere((f) => f.kode == kode);

    test('state: identitas ikut fieldWajib; field biasa tidak', () {
      final isian = isianDari(contohBentukLembarKerjaTits());
      addTearDown(isian.dispose);

      expect(isian.fieldWajib(fieldDi(isian, 'alat_serial_number')), isTrue);
      expect(isian.fieldWajib(fieldDi(isian, 'equipment.nama_alat')), isTrue);
      expect(isian.fieldWajib(fieldDi(isian, 'tanggal_kalibrasi')), isTrue);
      expect(isian.fieldWajib(fieldDi(isian, 'tanggal_terima')), isFalse);
      expect(isian.fieldWajib(fieldDi(isian, 'room_id')), isFalse);
      // Penentu angka tetap wajib lewat jalurnya sendiri.
      expect(isian.fieldWajib(fieldDi(isian, 'tipe_sensor')), isTrue);
      expect(isian.fieldIdentitas(fieldDi(isian, 'tipe_sensor')), isFalse);
    });

    test(
      'kolom yang server tandai di_luar_kertas bukan identitas tercetak',
      () {
        // Bentuk persis kiriman server untuk Timbangan
        // (TimbanganProfile::bagianIdentitas): Rentang Ukur ditandai
        // `di_luar_kertas`, Capacity tidak.
        final bentuk = contohBentukLembarKerjaTimbangan();
        final identitas = (bentuk['bagian'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((b) => b['kode'] == 'identitas_alat');
        for (final f
            in (identitas['field'] as List).cast<Map<String, dynamic>>()) {
          if (f['kode'] == 'spesifikasi_alat.rentang_ukur') {
            f['di_luar_kertas'] = true;
          }
        }

        final isian = isianDari(bentuk);
        addTearDown(isian.dispose);

        final rentang = fieldDi(isian, 'spesifikasi_alat.rentang_ukur');
        expect(rentang.diLuarKertas, isTrue);
        expect(isian.fieldIdentitas(rentang), isFalse);
        expect(isian.fieldWajib(rentang), isFalse);

        final kapasitas = fieldDi(isian, 'spesifikasi_alat.kapasitas');
        expect(kapasitas.diLuarKertas, isFalse);
        expect(isian.fieldIdentitas(kapasitas), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 2. Cakupan jujur enam alat prioritas
  // ---------------------------------------------------------------------------
  group('cakupan identitas per alat prioritas', () {
    Set<String> identitasDi(Map<String, dynamic> bentuk) {
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson(bentuk),
        clientRequestId: 'uji-cakupan',
      );
      addTearDown(isian.dispose);

      return {
        for (final b in isian.bentuk.bagian)
          for (final f in [...b.field, ...b.fieldDiLuarKertas])
            if (isian.fieldIdentitas(f)) f.kode,
      };
    }

    const umumVolumetrik = {
      'equipment.nama_alat',
      'spesifikasi_alat.volumetric.kapasitas_ml',
      'tanggal_kalibrasi',
      'alat_merk',
      'alat_model',
      'alat_serial_number',
      'lokasi',
      'lokasi_nama',
      'pemilik_nama',
      'pemilik_alamat',
    };

    test('Labu Ukur: tanpa resolusi (kertas Fixed mencetak "-")', () {
      expect(identitasDi(contohBentukLembarKerjaLabuUkur()), umumVolumetrik);
    });

    test('Pipet Volume: sama dengan Labu Ukur', () {
      expect(identitasDi(contohBentukLembarKerjaPipetVolume()), umumVolumetrik);
    });

    test('Gelas Ukur: ditambah resolusi skala', () {
      expect(identitasDi(contohBentukLembarKerjaGelasUkur()), {
        ...umumVolumetrik,
        'spesifikasi_alat.volumetric.resolusi_ml',
      });
    });

    test('TITS: kapasitas + resolusi (+ rentang di cermin lokal)', () {
      expect(identitasDi(contohBentukLembarKerjaTits()), {
        'equipment.nama_alat',
        'alat_merk',
        'alat_model',
        'alat_serial_number',
        'spesifikasi_alat.rentang_ukur',
        'spesifikasi_alat.kapasitas',
        'spesifikasi_alat.resolusi',
        'tanggal_kalibrasi',
        'lokasi',
        'lokasi_nama',
        'pemilik_nama',
        'pemilik_alamat',
      });
    });

    test('Timbangan: nilai e / kelas / tipe & jenis tidak diwarnai', () {
      final kode = identitasDi(contohBentukLembarKerjaTimbangan());

      expect(kode, containsAll(['equipment.nama_alat', 'alat_serial_number']));
      expect(kode, containsAll(['spesifikasi_alat.kapasitas', 'lokasi']));
      expect(kode, isNot(contains('spesifikasi_alat.nilai_e')));
      expect(kode, isNot(contains('spesifikasi_alat.kelas')));
      expect(kode, isNot(contains('tipe_timbangan')));
      expect(kode, isNot(contains('jenis_timbangan')));
    });

    test('Thermocouple: rentang ukur, kapasitas, resolusi; tipe TC netral', () {
      final kode = identitasDi(contohBentukLembarKerjaThermocouple());

      expect(kode, {
        'equipment.nama_alat',
        'alat_merk',
        'alat_model',
        'alat_serial_number',
        'spesifikasi_alat.rentang_ukur',
        'spesifikasi_alat.kapasitas',
        'spesifikasi_alat.resolusi',
        'tanggal_kalibrasi',
        'lokasi',
        'lokasi_nama',
        'pemilik_nama',
        'pemilik_alamat',
      });
    });

    test('"nomor identifikasi" tidak punya kolom di enam alat itu', () {
      for (final bentuk in [
        contohBentukLembarKerjaLabuUkur(),
        contohBentukLembarKerjaPipetVolume(),
        contohBentukLembarKerjaGelasUkur(),
        contohBentukLembarKerjaTits(),
        contohBentukLembarKerjaTimbangan(),
        contohBentukLembarKerjaThermocouple(),
      ]) {
        final kode = [
          for (final b in LembarKerja.fromJson(bentuk).bagian)
            for (final f in b.field) f.kode,
        ];
        expect(
          kode.where((k) => k.contains('identifikasi') || k.contains('no_id')),
          isEmpty,
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Dekorasi: identitas otomatis (wajib + otomatis)
  // ---------------------------------------------------------------------------
  group('dekorasiIsian — identitas otomatis dari data alat', () {
    Widget bungkus(Widget anak, {Brightness tema = Brightness.light}) =>
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('id'),
            theme: ThemeData(brightness: tema),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: anak),
          ),
        );

    Widget kotak({
      required bool wajib,
      required bool terisi,
      bool otomatis = true,
      bool scope = true,
      String? petunjuk = 'Lengkapi di data alat',
    }) {
      final isi = Builder(
        builder: (context) => InputDecorator(
          decoration: dekorasiIsian(
            context,
            wajib: wajib,
            terisi: terisi,
            otomatis: otomatis,
            petunjukKosong: petunjuk,
            base: const InputDecoration(
              labelText: 'Name',
              suffixText: 'pH',
              helperText: 'Keisi otomatis',
              border: OutlineInputBorder(),
            ),
          ),
          child: const Text('x'),
        ),
      );

      return scope ? WarnaIsianScope(child: isi) : isi;
    }

    InputDecoration dekorasi(WidgetTester tester) =>
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

    testWidgets(
      'kosong: oranye + * + petunjuk (satuan tetap ikut), tanpa kunci',
      (tester) async {
        await tester.pumpWidget(bungkus(kotak(wajib: true, terisi: false)));

        final d = dekorasi(tester);
        expect(
          d.fillColor,
          PaletIsian.untuk(Brightness.light, StatusIsian.wajibKosong)!.latar,
        );
        expect(d.labelText, 'Name *');
        expect(d.helperText, 'Lengkapi di data alat · pH');
        expect(d.suffixIcon, isNull);
      },
    );

    testWidgets(
      'terisi: hijau + ikon kunci kecil, helper otomatis dipertahankan',
      (tester) async {
        await tester.pumpWidget(bungkus(kotak(wajib: true, terisi: true)));

        final d = dekorasi(tester);
        expect(
          d.fillColor,
          PaletIsian.untuk(Brightness.light, StatusIsian.wajibTerisi)!.latar,
        );
        expect(d.labelText, 'Name *');
        expect(d.helperText, 'Keisi otomatis');
        expect(d.suffixIcon, isA<Icon>());
        expect((d.suffixIcon! as Icon).icon, Icons.lock_outline);
        expect((d.suffixIcon! as Icon).key, kunciIkonIdentitas);
      },
    );

    testWidgets('hasil hitung (otomatis tanpa wajib) tetap abu kebiruan', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(kotak(wajib: false, terisi: true)));

      final d = dekorasi(tester);
      expect(
        d.fillColor,
        PaletIsian.untuk(Brightness.light, StatusIsian.otomatis)!.latar,
      );
      expect(d.labelText, 'Name', reason: 'tanpa bintang');
      expect(d.suffixIcon, isNull, reason: 'tanpa kunci');
      expect(d.helperText, 'Keisi otomatis');

      // Kosong pun tetap abu: yang ini tidak ada yang bisa dilengkapi teknisi.
      await tester.pumpWidget(bungkus(kotak(wajib: false, terisi: false)));
      expect(
        dekorasi(tester).fillColor,
        PaletIsian.untuk(Brightness.light, StatusIsian.otomatis)!.latar,
      );
      expect(dekorasi(tester).helperText, 'Keisi otomatis');
    });

    testWidgets('tema gelap: token gelap untuk kosong dan terisi', (
      tester,
    ) async {
      await tester.pumpWidget(
        bungkus(kotak(wajib: true, terisi: false), tema: Brightness.dark),
      );
      expect(
        dekorasi(tester).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibKosong)!.latar,
      );

      await tester.pumpWidget(
        bungkus(kotak(wajib: true, terisi: true), tema: Brightness.dark),
      );
      expect(
        dekorasi(tester).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibTerisi)!.latar,
      );
      expect(dekorasi(tester).suffixIcon, isA<Icon>());
    });

    testWidgets('tanpa WarnaIsianScope: dekorasi apa adanya', (tester) async {
      await tester.pumpWidget(
        bungkus(kotak(wajib: true, terisi: false, scope: false)),
      );

      final d = dekorasi(tester);
      expect(d.fillColor, isNull);
      expect(d.labelText, 'Name');
      expect(d.helperText, 'Keisi otomatis');
      expect(d.suffixIcon, isNull);
    });

    testWidgets('petunjuk hanya saat KOSONG; diketik teknisi (tanpa petunjuk) '
        'tidak mengganti helper', (tester) async {
      // Isian yang diketik teknisi (bukan otomatis) tidak diberi petunjuk
      // "lengkapi di data alat": ia bisa langsung diketik di sini.
      await tester.pumpWidget(
        bungkus(
          kotak(wajib: true, terisi: false, otomatis: false, petunjuk: null),
        ),
      );
      expect(dekorasi(tester).helperText, 'Keisi otomatis');
      expect(dekorasi(tester).labelText, 'Name *');
      expect(dekorasi(tester).suffixIcon, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Layar lembar kerja sungguhan
  // ---------------------------------------------------------------------------
  group('di layar lembar kerja', () {
    Widget app(String profil, {Brightness tema = Brightness.light}) {
      return ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          lembarKerjaServiceProvider.overrideWithValue(
            MockLembarKerjaService(),
          ),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          theme: ThemeData(brightness: tema),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LembarKerjaScreen(profil: profil),
        ),
      );
    }

    Future<void> buka(
      WidgetTester tester,
      String profil, {
      Brightness tema = Brightness.light,
    }) async {
      tester.view.physicalSize = const Size(1400, 5200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(profil, tema: tema));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    /// Label field dari bentuk lembar yang sama dengan yang dipajang mock.
    String labelDi(Map<String, dynamic> bentuk, String kode) {
      for (final b in LembarKerja.fromJson(bentuk).bagian) {
        for (final f in b.field) {
          if (f.kode == kode) return f.label;
        }
      }
      throw StateError('kolom $kode tidak ada');
    }

    /// Dekorasi kotak berlabel [label] (dengan atau tanpa ` *`).
    InputDecoration dekorasiBerlabel(WidgetTester tester, String label) {
      final cocok = find.byWidgetPredicate((w) {
        if (w is! InputDecorator) return false;
        final t = w.decoration.labelText;
        return t == label || t == '$label *';
      });
      expect(cocok, findsWidgets, reason: 'kotak "$label" tidak ditemukan');

      return tester.widget<InputDecorator>(cocok.first).decoration;
    }

    Color latar(Brightness tema, StatusIsian s) =>
        PaletIsian.untuk(tema, s)!.latar;

    Future<void> ketik(WidgetTester tester, String label, String isi) async {
      final cocok = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final t = w.decoration?.labelText;
        return t == label || t == '$label *';
      });
      await tester.enterText(cocok.first, isi);
      await tester.pump();
    }

    Future<void> pilihAlatMettler(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<EquipmentLookup>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
      await tester.pumpAndSettle();
    }

    final bentukTits = contohBentukLembarKerjaTits();

    testWidgets('nomor seri: kosong oranye + *, diketik jadi hijau', (
      tester,
    ) async {
      await buka(tester, 'tits');
      final serial = labelDi(bentukTits, 'alat_serial_number');

      var d = dekorasiBerlabel(tester, serial);
      expect(d.fillColor, latar(Brightness.light, StatusIsian.wajibKosong));
      expect(d.labelText, '$serial *');

      await ketik(tester, serial, 'SN-12345');

      d = dekorasiBerlabel(tester, serial);
      expect(d.fillColor, latar(Brightness.light, StatusIsian.wajibTerisi));
      expect(d.labelText, '$serial *');
    });

    testWidgets('merk & tipe/model ikut diwarnai menurut isi', (tester) async {
      await buka(tester, 'tits');

      for (final kode in const ['alat_merk', 'alat_model']) {
        final label = labelDi(bentukTits, kode);
        expect(
          dekorasiBerlabel(tester, label).fillColor,
          latar(Brightness.light, StatusIsian.wajibKosong),
          reason: '$kode kosong',
        );
        await ketik(tester, label, 'isi $kode');
        expect(
          dekorasiBerlabel(tester, label).fillColor,
          latar(Brightness.light, StatusIsian.wajibTerisi),
          reason: '$kode terisi',
        );
      }
    });

    testWidgets('spasi saja dianggap kosong', (tester) async {
      await buka(tester, 'tits');
      final serial = labelDi(bentukTits, 'alat_serial_number');

      await ketik(tester, serial, '   ');

      expect(
        dekorasiBerlabel(tester, serial).fillColor,
        latar(Brightness.light, StatusIsian.wajibKosong),
      );
    });

    testWidgets('nama alat (otomatis): kosong oranye + petunjuk -> '
        'pilih alat: hijau + kunci', (tester) async {
      await buka(tester, 'tits');
      final nama = labelDi(bentukTits, 'equipment.nama_alat');

      var d = dekorasiBerlabel(tester, nama);
      expect(d.fillColor, latar(Brightness.light, StatusIsian.wajibKosong));
      expect(d.labelText, '$nama *');
      expect(d.helperText, contains('Lengkapi di data alat'));
      expect(d.suffixIcon, isNull);

      await pilihAlatMettler(tester);

      d = dekorasiBerlabel(tester, nama);
      expect(d.fillColor, latar(Brightness.light, StatusIsian.wajibTerisi));
      expect(d.helperText, isNot(contains('Lengkapi di data alat')));
      expect(find.byKey(kunciIkonIdentitas), findsOneWidget);
      expect(find.text('pH Meter Mettler Toledo'), findsWidgets);
    });

    testWidgets(
      'pilih alat mengisi merk/tipe/seri/pelanggan -> semuanya hijau',
      (tester) async {
        await buka(tester, 'tits');
        await pilihAlatMettler(tester);

        for (final kode in const [
          'alat_merk',
          'alat_model',
          'alat_serial_number',
          'pemilik_nama',
          'pemilik_alamat',
        ]) {
          expect(
            dekorasiBerlabel(tester, labelDi(bentukTits, kode)).fillColor,
            latar(Brightness.light, StatusIsian.wajibTerisi),
            reason: kode,
          );
        }
      },
    );

    testWidgets('tanggal kalibrasi: awalnya hari ini (hijau), dikosongkan '
        'jadi oranye; tanggal diterima tetap netral', (tester) async {
      await buka(tester, 'tits');
      final kalibrasi = labelDi(bentukTits, 'tanggal_kalibrasi');
      final terima = labelDi(bentukTits, 'tanggal_terima');

      expect(
        dekorasiBerlabel(tester, kalibrasi).fillColor,
        latar(Brightness.light, StatusIsian.wajibTerisi),
      );
      expect(dekorasiBerlabel(tester, terima).fillColor, isNull);
      expect(dekorasiBerlabel(tester, terima).labelText, terima);

      await tester.tap(find.byTooltip('Kosongkan tanggal').first);
      await tester.pumpAndSettle();

      final d = dekorasiBerlabel(tester, kalibrasi);
      expect(d.fillColor, latar(Brightness.light, StatusIsian.wajibKosong));
      expect(d.labelText, '$kalibrasi *');
    });

    testWidgets('lokasi (pilihan): selalu terisi -> hijau', (tester) async {
      await buka(tester, 'tits');
      final lokasi = labelDi(bentukTits, 'lokasi');

      expect(
        dekorasiBerlabel(tester, lokasi).fillColor,
        latar(Brightness.light, StatusIsian.wajibTerisi),
      );
    });

    testWidgets('kapasitas & resolusi (baris spesifikasi): kosong oranye, '
        'diketik hijau', (tester) async {
      await buka(tester, 'tits');

      for (final kode in const [
        'spesifikasi_alat.kapasitas',
        'spesifikasi_alat.resolusi',
      ]) {
        final judul = labelDi(bentukTits, kode);
        final kotak = find.descendant(
          of: find.byWidgetPredicate(
            (w) =>
                w is Column &&
                w.children.any((c) => c is Text && c.data == judul),
          ),
          matching: find.byType(TextField),
        );
        expect(kotak, findsOneWidget, reason: kode);

        expect(
          tester.widget<TextField>(kotak).decoration!.fillColor,
          latar(Brightness.light, StatusIsian.wajibKosong),
          reason: '$kode kosong',
        );

        await tester.enterText(kotak, '150');
        await tester.pump();

        expect(
          tester.widget<TextField>(kotak).decoration!.fillColor,
          latar(Brightness.light, StatusIsian.wajibTerisi),
          reason: '$kode terisi',
        );
      }
    });

    testWidgets(
      'Gelas Ukur: kapasitas & resolusi skala (volumetrik) berwarna',
      (tester) async {
        await buka(tester, 'gelas_ukur');
        final bentuk = contohBentukLembarKerjaGelasUkur();

        for (final kode in const [
          'spesifikasi_alat.volumetric.kapasitas_ml',
          'spesifikasi_alat.volumetric.resolusi_ml',
        ]) {
          final judul = labelDi(bentuk, kode);
          final kotak = find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Column &&
                  w.children.any((c) => c is Text && c.data == judul),
            ),
            matching: find.byType(TextField),
          );
          expect(kotak, findsOneWidget, reason: kode);
          expect(
            tester.widget<TextField>(kotak).decoration!.fillColor,
            latar(Brightness.light, StatusIsian.wajibKosong),
            reason: '$kode kosong',
          );

          await tester.enterText(kotak, '100');
          await tester.pump();
          expect(
            tester.widget<TextField>(kotak).decoration!.fillColor,
            latar(Brightness.light, StatusIsian.wajibTerisi),
            reason: '$kode terisi',
          );
        }
      },
    );

    testWidgets('tema gelap memakai token gelap', (tester) async {
      await buka(tester, 'tits', tema: Brightness.dark);
      final serial = labelDi(bentukTits, 'alat_serial_number');

      expect(
        dekorasiBerlabel(tester, serial).fillColor,
        latar(Brightness.dark, StatusIsian.wajibKosong),
      );

      await ketik(tester, serial, 'SN-1');
      expect(
        dekorasiBerlabel(tester, serial).fillColor,
        latar(Brightness.dark, StatusIsian.wajibTerisi),
      );
    });

    for (final profil in const [
      'labu_ukur',
      'pipet_volume',
      'gelas_ukur',
      'timbangan',
      'thermocouple',
    ]) {
      testWidgets('$profil: nomor seri kosong oranye lalu hijau; nama alat '
          'otomatis ikut warna isi', (tester) async {
        await buka(tester, profil);

        final bentuk = switch (profil) {
          'labu_ukur' => contohBentukLembarKerjaLabuUkur(),
          'pipet_volume' => contohBentukLembarKerjaPipetVolume(),
          'gelas_ukur' => contohBentukLembarKerjaGelasUkur(),
          'timbangan' => contohBentukLembarKerjaTimbangan(),
          _ => contohBentukLembarKerjaThermocouple(),
        };
        final serial = labelDi(bentuk, 'alat_serial_number');
        final nama = labelDi(bentuk, 'equipment.nama_alat');

        expect(
          dekorasiBerlabel(tester, serial).fillColor,
          latar(Brightness.light, StatusIsian.wajibKosong),
        );
        expect(
          dekorasiBerlabel(tester, nama).fillColor,
          latar(Brightness.light, StatusIsian.wajibKosong),
        );

        await ketik(tester, serial, 'SN-77');
        await pilihAlatMettler(tester);

        expect(
          dekorasiBerlabel(tester, nama).fillColor,
          latar(Brightness.light, StatusIsian.wajibTerisi),
        );
        expect(find.byKey(kunciIkonIdentitas), findsOneWidget);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 5. Legenda
  // ---------------------------------------------------------------------------
  group('legenda identitas', () {
    Future<void> bukaLegenda(WidgetTester tester, String bahasa) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: Locale(bahasa),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LegendaWarnaIsian()),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('tombol-legenda-warna-isian')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'bahasa Indonesia: baris identitas + kunci + tidak menahan kirim',
      (tester) async {
        await bukaLegenda(tester, 'id');

        expect(
          find.byKey(const ValueKey('legenda-identitas-alat')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Identitas alat yang tercetak'),
          findsOneWidget,
        );
        expect(find.textContaining('Ikon kunci'), findsOneWidget);
        expect(find.textContaining('tidak menahan pengiriman'), findsOneWidget);
        // Judul lama tetap.
        expect(find.textContaining('Wajib, masih kosong'), findsOneWidget);
        expect(find.textContaining('Otomatis (abu kebiruan)'), findsOneWidget);
      },
    );

    testWidgets('bahasa Inggris', (tester) async {
      await bukaLegenda(tester, 'en');

      expect(find.textContaining('Equipment identity printed'), findsOneWidget);
      expect(find.textContaining('lock icon'), findsOneWidget);
      expect(find.textContaining('does not block the send'), findsOneWidget);
    });

    test('petunjuk kosong tersedia di kedua bahasa', () async {
      expect(
        (await AppLocalizations.delegate.load(
          const Locale('id'),
        )).lkLengkapiDiDataAlat,
        'Lengkapi di data alat',
      );
      expect(
        (await AppLocalizations.delegate.load(
          const Locale('en'),
        )).lkLengkapiDiDataAlat,
        'Complete it in the equipment record',
      );
    });
  });
}
