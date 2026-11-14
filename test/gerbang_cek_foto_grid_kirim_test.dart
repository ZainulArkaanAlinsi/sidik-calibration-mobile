import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart'
    show CalibrationStatus;
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/contoh_sel_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/verifikasi_sel_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_enclosure.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/penampung_contoh_sel.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/verifikasi_sel_service.dart';

/// Foto GRID per set point (Enclosure) lalu Kirim: konfirmasi pasca-kirim.
///
/// Jalur foto grid tidak menyalakan `adaIsianDariFoto`. Bila konfirmasi
/// pasca-kirim bergantung pada bendera itu, barisnya (lahir `is_verified=false`)
/// tidak pernah dikonfirmasi dan sesi tersangkut di antrean admin. Test ini
/// menjalankan tombol Kirim di layar sungguhan.
void main() {
  const userId = 1;

  // Dropdown alat di layar hanya menerima alat dari daftar mock; yang diuji di
  // sini gerbang foto grid, bukan jenis alatnya.
  const alat = EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Mettler Toledo',
    model: 'Five Easy',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA CONTOH MANDIRI',
    pelangganAlamat: 'Jl. Contoh Primer A-10, Kab. Bandung',
  );

  setUp(() => MockStore.instance.reset());

  testWidgets('foto grid, semua dicek, Kirim: baris dikonfirmasi lewat id '
      'eksplisit', (tester) async {
    // Salinan HP: grid Oven berisi hasil foto, semuanya sudah dikonfirmasi.
    final s = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaOven()),
      clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a99',
    )..alat = alat;
    final sp = s.grid!.setPoint.first;
    sp.titikCtl.text = '100';
    final masuk = sp.terapkanHasilFotoPosisi([
      for (var b = 1; b <= 2; b++)
        for (final r in s.grid!.bentuk.pengulangan)
          (barisKe: b, repeatNo: r, teks: '10$b,$r', keyakinan: 0.99),
    ]);
    expect(masuk, greaterThan(0), reason: 'prasyarat: foto grid mendarat');
    for (final k in s.daftarSelCek().map((x) => x.kunci).toList()) {
      s.konfirmasiSelCek(k);
    }
    expect(s.jumlahPerluCek, 0);
    expect(
      s.adaIsianDariFoto,
      isFalse,
      reason: 'jalur foto grid tidak menyalakan bendera lama (inti kasus ini)',
    );

    final draf = DrafLokal(
      userId: userId,
      clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a99',
      profil: 'oven',
      equipmentId: alat.id,
      disimpanPada: DateTime.utc(2026, 11, 13, 6),
      isian: s.salinanLokal(),
    );
    s.dispose();

    final hp = SimpananDrafLokalMemori();
    await hp.simpan(draf);

    final verifikasi = MockVerifikasiSelService();
    final lembar = MockLembarKerjaService();
    final riwayat = _RiwayatBaris([
      for (var i = 1; i <= 3; i++)
        RawMeasurement.fromJson({
          'id': 500 + i,
          'titik_ke': 1,
          'titik_ukur': 100,
          'pembacaan_ke': i,
          'pembacaan': 100 + i / 10,
          'is_verified': false,
          'ocr_raw_text': '10$i',
        }),
      RawMeasurement.fromJson({
        'id': 599,
        'titik_ke': 1,
        'titik_ukur': 100,
        'pembacaan_ke': 9,
        'pembacaan': 1.0,
        'is_verified': true,
      }),
    ]);

    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          lembarKerjaServiceProvider.overrideWithValue(lembar),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
          simpananDrafLokalProvider.overrideWithValue(hp),
          historyServiceProvider.overrideWithValue(riwayat),
          verifikasiSelServiceProvider.overrideWithValue(verifikasi),
          // Penampung contoh sel membaca folder aplikasi (IO nyata, yang di
          // widget test tidak pernah selesai): diganti yang tidak menyentuh disk.
          penampungContohSelProvider.overrideWith(
            (ref) async =>
                PenampungContohSel(SimpananContohSel(Directory.systemTemp)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(authProvider);

              return LembarKerjaScreen(profil: 'oven', drafLokal: draf);
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final lanjut = find.byIcon(Icons.arrow_forward);
    for (var i = 0; i < 4 && lanjut.evaluate().isNotEmpty; i++) {
      await tester.ensureVisible(lanjut);
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }

    final kirim = find.widgetWithText(FilledButton, 'Kirim ke admin');
    expect(kirim, findsOneWidget);
    expect(
      tester.widget<FilledButton>(kirim).onPressed,
      isNotNull,
      reason: 'semua sel kamera sudah dicek: Kirim hidup',
    );

    await tester.ensureVisible(kirim);
    await tester.tap(kirim);
    await tester.pumpAndSettle();

    // Ringkasan sebelum kirim (kolom identitas yang kosong = peringatan saja).
    final tetapKirim = find.byKey(const ValueKey('ringkasan-kirim'));
    if (tetapKirim.evaluate().isNotEmpty) {
      await tester.tap(tetapKirim);
      await tester.pumpAndSettle();
    }
    // Pertanyaan peringatan lembar (mis. "Temperature Type belum dipilih") dan
    // konfirmasi angka: dijawab "kirim"; keduanya TANYA, bukan gerbang kamera.
    for (final jawab in ['Angkanya emang segitu — kirim', 'Kirim sekarang']) {
      final tombol = find.text(jawab);
      if (tombol.evaluate().isNotEmpty) {
        await tester.tap(tombol);
        await tester.pumpAndSettle();
      }
    }

    expect(lembar.jumlahKirim, 1, reason: 'prasyarat: kiriman final berangkat');
    expect(
      verifikasi.panggilan,
      hasLength(1),
      reason:
          'foto grid tidak menyalakan adaIsianDariFoto: konfirmasi pasca-kirim '
          'harus tetap jalan (adaBacaanKamera)',
    );
    expect(verifikasi.panggilan.single.ids, [501, 502, 503]);
  });
}

/// Riwayat yang menjawab detail sesi dengan baris mentah yang ditentukan.
class _RiwayatBaris extends MockHistoryService {
  _RiwayatBaris(this._baris);

  final List<RawMeasurement> _baris;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail(
        id: id,
        namaAlat: 'Oven Memmert',
        status: CalibrationStatus.menungguApproval,
        tanggalKalibrasi: DateTime(2026, 11, 13),
        namaTeknisi: 'Teknisi Uji',
        pembacaanMentah: _baris,
      );
}
