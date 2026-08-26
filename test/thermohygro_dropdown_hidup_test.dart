import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Dropdown "Environmental Meter Used" beneran hidup di layar, bukan cuma di
/// respons server.**
///
/// ## Yang belum pernah diadu
///
/// Kolom thermohygro sempat mati di TITS, TIDS, dan kelima lembar Enclosure —
/// dropdown-nya nggak pernah diisi siapa pun. Sisi server sudah dibetulkan dan
/// dijaga `ThermohygroSemuaLembarTest` di repo API, tapi yang dibuktikan di
/// sana **responsnya sudah berisi** — bukan bahwa layar HP-nya menggambar
/// dropdown itu.
///
/// Bedanya nyata, karena layar punya cabang kedua:
///
/// ```dart
/// if (field.pilihan.isEmpty) {
///   return _Readonly(label: field.label, nilai: l10n.lkThermohygroKosong);
/// }
/// ```
///
/// Cabang itu **nol kali disentuh test** sampai berkas ini ada. Jadi kalau
/// suatu hari model HP berhenti mem-parse `pilihan` — misalnya waktu bentuk
/// `grup` berubah — tiap lembar bakal diam-diam jatuh ke situ dan teknisi
/// membaca "Belum ada unit thermohygro terdaftar." di lab yang unitnya ada
/// tujuh. Nol error, dan yang hilang satu kolom yang tercetak di sertifikat.
///
/// ## Kenapa dua arah, bukan satu
///
/// Menegakkan cuma "dropdown-nya muncul" bikin cabang kosongnya bisa dihapus
/// orang tanpa satu pun test merah — padahal dia BUKAN kode mati: lab yang
/// belum mendaftarkan unit memang berhak dapat pesan itu, bukan dropdown
/// kosong yang nggak bisa dipilih. Jadi dijaga dua-duanya: ada isi → dropdown,
/// kosong → pesannya.
///
/// ## Cakupannya, apa adanya
///
/// Dua belas profil di bawah adalah yang bentuknya BENERAN dimodelkan
/// `MockLembarKerjaService`. Lima sisanya (Conductivity, Autoclave, TIDS, dan
/// Enclosure) jatuh ke cabang `_` alias bentuk pH di mock itu — menuliskannya
/// di daftar ini bakal bikin test yang kelihatan menyapu 17 lembar padahal
/// yang diperiksa lembar pH berkali-kali. Klaim 17/17 tetap di sisi server,
/// tempat bentuknya beneran lahir.
void main() {
  /// Kode profil yang `MockLembarKerjaService` punya bentuk aslinya.
  ///
  /// `ph_meter` ikut karena dia juga default `LembarKerjaScreen` DAN cabang
  /// `_` di mock — jadi satu baris ini menjaga dua jalur sekaligus.
  const profil = <String>[
    'ph_meter',
    'turbidimeter',
    'chlorine_meter',
    'refractometer',
    'spectrophotometer',
    'viscometer',
    'do_meter',
    'gas_detector',
    'tits',
    'thermocouple',
    'thermometer_glass',
    'thermohygro',
  ];

  Widget app(String kode, {bool tanpaThermohygro = false}) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(
        MockLembarKerjaService(tanpaThermohygro: tanpaThermohygro),
      ),
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
      home: LembarKerjaScreen(profil: kode),
    ),
  );

  Future<void> buka(
    WidgetTester tester,
    String kode, {
    bool tanpaThermohygro = false,
  }) async {
    // Tinggi berlebih SENGAJA: kolom thermohygro duduk di bagian kondisi
    // lingkungan, yang di lembar panjang jatuh jauh di bawah lipatan. Viewport
    // pendek bikin `find.text` nggak nemu bukan karena kolomnya hilang, tapi
    // karena `ListView` belum membangunnya — hijau yang salah alasan.
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(kode, tanpaThermohygro: tanpaThermohygro));
    // Layar generik punya debounce autosimpan; ditunggu supaya timernya
    // kebakar di dalam test.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  for (final kode in profil) {

    testWidgets('$kode: dropdown thermohygro kegambar, bukan pesan kosong', (
      tester,
    ) async {
      await buka(tester, kode);

      expect(
        find.text('Belum ada unit thermohygro terdaftar.'),
        findsNothing,
        reason:
            '$kode: server ngirim daftar unit, tapi layarnya jatuh ke cabang '
            'kosong — teknisi bakal baca "belum ada unit" di lab yang unitnya ada.',
      );

      // Label unit dari mock. Bukan cuma "ada dropdown": yang dijaga daftarnya
      // beneran ter-parse sampai ke label yang dibaca teknisi.
      expect(
        find.text('TH-2'),
        findsWidgets,
        reason: '$kode: pilihan thermohygro nggak sampai ke layar.',
      );

      // Grup Inlab/Insitu ikut kebawa — itu yang bikin teknisi tau unit mana
      // yang boleh dibawa keluar lab.
      expect(find.text('Inlab'), findsWidgets, reason: '$kode: grup hilang.');
      expect(find.text('Insitu'), findsWidgets, reason: '$kode: grup hilang.');
    });
  }

  testWidgets('lab tanpa unit thermohygro dapat pesannya, bukan dropdown kosong', (
    tester,
  ) async {
    await buka(tester, 'tits', tanpaThermohygro: true);

    // Arah sebaliknya. Tanpa test ini, cabang kosongnya kelihatan seperti kode
    // mati dan bakal dihapus orang berikutnya — lalu lab yang belum
    // mendaftarkan unit dapat dropdown kosong yang nggak bisa dipilih, tanpa
    // satu pun keterangan kenapa.
    expect(find.text('Belum ada unit thermohygro terdaftar.'), findsOneWidget);
    expect(
      find.text('TH-2'),
      findsNothing,
      reason: 'Daftarnya dikosongkan; nggak boleh ada sisa pilihan tergambar.',
    );
  });
}
