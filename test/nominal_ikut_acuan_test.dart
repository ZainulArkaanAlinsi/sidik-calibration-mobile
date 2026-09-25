import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_volumetrik.dart';

/// **Kotak Nominal tabel kedua dst. menampilkan nominal tabel pertama.**
///
/// Chaos review 25 Sep 2026. Di lembar ber-deret-bernama (posisi 0°/90°/
/// 180°/270° Gaya, UP/DOWN Proving Ring, Hydrometer, Volumetric) yang dikirim
/// cuma nominal tabel PERTAMA. Kotak Nominal di tabel lain dulu tetap kotak
/// isian: teknisi mengetik angka yang tidak pernah dibaca siapa pun, dan angka
/// yang beda di salah satunya hilang tanpa tanda.
///
/// Dijaga di dua lapis: state (siapa acuannya) dan tampilan (kotak isiannya
/// memang hilang, angkanya ikut acuan secara langsung).
void main() {
  LembarKerjaState isianHydrometer() {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaHydrometer()),
      clientRequestId: 'uji-nominal-acuan',
    );

    isian.alat = const EquipmentLookup(
      id: 33,
      namaAlat: 'Hydrometer Uji',
      serialNumber: 'DEMO-HYD-1',
      kategori: 'volumetrik',
      status: 'aktif',
      satuan: 'g/ml',
      rangeMax: 0.65,
      resolusi: 0.0005,
    );

    return isian;
  }

  TabelHasil tabelHasil(LembarKerjaState isian, int i) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel[i];

  test('acuan nominal = baris sejajar di tabel deret-bernama pertama', () {
    final isian = isianHydrometer();
    final massa = tabelHasil(isian, 0);
    final suhu = tabelHasil(isian, 1);

    final acuan = isian.acuanNominal(suhu, 0);

    expect(acuan, isNotNull);
    expect(
      identical(
        acuan,
        isian.titikUntukBaris(isian.barisTabel(massa), 0, massa),
      ),
      isTrue,
      reason: 'Acuannya mestinya baris yang SAMA dengan yang dipakai payload.',
    );
    expect(
      isian.acuanNominal(massa, 0),
      isNull,
      reason: 'Tabel pertama itu acuannya sendiri.',
    );
  });

  test('tabel bukan deret-bernama tidak punya acuan', () {
    final isian = isianHydrometer();
    final dStem = isian.bentuk.bagian
        .expand((b) => b.tabel)
        .firstWhere(
          (t) => t.simpanKe?.startsWith('spesifikasi_alat.') ?? false,
        );

    expect(isian.acuanNominal(dStem, 0), isNull);
  });

  testWidgets('kotak Nominal tabel kedua ikut ketikan di tabel pertama', (
    tester,
  ) async {
    final isian = isianHydrometer();
    final massa = tabelHasil(isian, 0);
    final suhu = tabelHasil(isian, 1);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LembarKerjaTabel(
                tabel: suhu,
                isian: isian,
                onBerubah: () {},
                pindaiAktif: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final acuan = isian.titikUntukBaris(isian.barisTabel(massa), 0, massa)!;
    final pengikut = isian.titikUntukBaris(isian.barisTabel(suhu), 0, suhu)!;

    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && identical(w.controller, pengikut.titikCtl),
      ),
      findsNothing,
      reason: 'Kotak isian Nominal yang tidak pernah dibaca masih digambar.',
    );

    acuan.titikCtl.text = '0,610';
    await tester.pump();

    expect(find.text('0,610'), findsWidgets);
  });

  group('peran super admin', () {
    test('dikenali, berlabel benar, dan tetap baca-saja', () {
      final r = UserRole.fromApi('super_admin');

      expect(r, UserRole.superAdmin);
      expect(r.label, 'Super Admin');
      expect(r.bisaInput, isFalse);
      expect(r.isAdmin, isFalse);
      expect(r.api, 'super_admin');
    });

    test('tidak pernah ditawarkan di pilihan peran', () {
      expect(UserRole.bisaDiberikan, isNot(contains(UserRole.superAdmin)));
      expect(UserRole.bisaDiberikan, [
        UserRole.admin,
        UserRole.teknisi,
        UserRole.viewer,
      ]);
    });

    test('nilai yang dikirim ke API tidak berubah untuk peran lama', () {
      expect(UserRole.admin.api, 'admin');
      expect(UserRole.teknisi.api, 'teknisi');
      expect(UserRole.viewer.api, 'viewer');
      expect(UserRole.fromApi('peran_asing'), UserRole.viewer);
    });
  });
}
