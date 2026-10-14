import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pengirim_draf_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/konfirmasi_draf_tertunda.dart';

import 'support/simpanan_tiruan.dart';

/// Keluar akun dengan draf yang belum sampai server (keputusan review
/// draf-offline 14 Okt 2026, K-30-09):
///
///  - dicoba kirim sekali dulu;
///  - yang tersisa ditanyakan, dengan janji yang jujur (tetap di tablet,
///    dikirim waktu login lagi);
///  - logout-nya sendiri NGGAK menghapus draf apa pun.
void main() {
  pasangSimpananTiruan();

  const userId = 1; // `mock-token-1`

  DrafLokal draf(int sesiId, StatusDrafLokal status) => DrafLokal(
    userId: userId,
    sesiId: sesiId,
    clientRequestId: '0b7c6a52-3f7e-4d55-9a3b-2c1d0e9f8a7$sesiId',
    profil: 'ph_meter',
    disimpanPada: DateTime.now().toUtc(),
    status: status,
    kiriman: const {'status': 'draft'},
    isian: const {},
  );

  Future<({bool? Function() hasil})> pasang(
    WidgetTester tester, {
    required SimpananDrafLokal hp,
    required PengirimDrafService pengirim,
  }) async {
    bool? hasil;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          simpananDrafLokalProvider.overrideWithValue(hp),
          pengirimDrafServiceProvider.overrideWithValue(pengirim),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authProvider).value;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      hasil = await konfirmasiKeluarDenganDrafTertunda(
                        context,
                        ref,
                      );
                      if (hasil == true) {
                        await ref.read(authProvider.notifier).logout();
                      }
                    },
                    child: Text(user == null ? 'sudah keluar' : 'keluar'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (hasil: () => hasil);
  }

  testWidgets('masih ada draf belum terkirim sesudah dicoba kirim: ditanya, '
      'dan logout nggak menghapus drafnya', (tester) async {
    final hp = SimpananDrafLokalMemori();
    await hp.simpan(draf(1, StatusDrafLokal.belumTersinkron));
    await hp.simpan(draf(2, StatusDrafLokal.perluDiperbaiki));
    await hp.simpan(draf(3, StatusDrafLokal.lokal));
    final pengirim = _Pengirim(offline: true);

    final t = await pasang(tester, hp: hp, pengirim: pengirim);

    await tester.tap(find.text('keluar'));
    await tester.pumpAndSettle();

    expect(pengirim.dicoba, greaterThan(0), reason: 'Nggak dicoba kirim dulu.');
    expect(
      find.text(
        '2 draf belum terkirim. Draf tetap disimpan di tablet ini dan '
        'dikirim saat kamu login lagi.',
      ),
      findsOneWidget,
    );

    // Batal: tetap login.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(t.hasil(), isFalse);
    expect(find.text('keluar'), findsOneWidget);

    // Keluar: logout jalan, drafnya tetap di HP.
    await tester.tap(find.text('keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(t.hasil(), isTrue);
    expect(find.text('sudah keluar'), findsOneWidget);
    expect(
      (await hp.daftar(userId)).map((d) => d.sesiId).toSet(),
      {1, 2, 3},
      reason: 'Logout menghapus draf.',
    );
  });

  testWidgets('drafnya berhasil terkirim waktu dicoba: langsung keluar tanpa '
      'ditanya', (tester) async {
    final hp = SimpananDrafLokalMemori();
    await hp.simpan(draf(1, StatusDrafLokal.belumTersinkron));
    final pengirim = _Pengirim();

    final t = await pasang(tester, hp: hp, pengirim: pengirim);

    await tester.tap(find.text('keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(t.hasil(), isTrue);
    expect(await hp.daftar(userId), isEmpty);
  });

  testWidgets('nggak ada draf tertunda: keluar tanpa mengirim apa pun', (
    tester,
  ) async {
    final hp = SimpananDrafLokalMemori();
    await hp.simpan(draf(3, StatusDrafLokal.lokal));
    final pengirim = _Pengirim();

    final t = await pasang(tester, hp: hp, pengirim: pengirim);

    await tester.tap(find.text('keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(t.hasil(), isTrue);
    expect(pengirim.dicoba, 0);
  });
}

class _Pengirim implements PengirimDrafService {
  _Pengirim({this.offline = false});

  final bool offline;
  int dicoba = 0;

  @override
  Future<SesiDibuat> buat(
    String token, {
    required bool matriks,
    required Map<String, dynamic> body,
  }) async {
    dicoba++;
    if (offline) throw const KoneksiException('offline');
    return (id: 900, status: 'draft');
  }

  @override
  Future<int> perbarui(
    String token, {
    required bool matriks,
    required int id,
    required Map<String, dynamic> body,
  }) async {
    dicoba++;
    if (offline) throw const KoneksiException('offline');
    return id;
  }
}
