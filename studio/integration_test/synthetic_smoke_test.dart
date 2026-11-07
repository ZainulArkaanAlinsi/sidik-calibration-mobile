import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/app.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/inti/penimpaan.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/layar/cangkang_studio.dart';
import 'package:sidik_studio/layar/masuk_screen.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/daftar_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/tema/font_studio.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'synthetic_scope.dart';

const _rootKey = ValueKey('synthetic-smoke-root');
const _identifier = String.fromEnvironment('E2E_ID');
const _password = String.fromEnvironment('E2E_SANDI');

/// Native UI + real production services + isolated Laravel/SQLite fixture.
/// Does not invoke main(), CredentialManager, updater, formula evaluation,
/// data-acuan activation or any metrological/master-workbook calculation.
void main() {
  SyntheticTransportAudit? activeAudit;
  // Bind frame callbacks in the same guarded HTTP zone as the app. A client
  // created before manifest validation fails closed instead of using defaults.
  http.runWithClient(
    () {
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

      testWidgets(
        'synthetic Studio: login, two stored sheets/formula, logout',
        (tester) async {
          final scope = SyntheticScope.load();
          final manifest = scope.manifest;
          if (AppConfig.useMock ||
              _identifier != manifest.email ||
              _password.isEmpty) {
            fail(
              'Synthetic localhost credentials and USE_MOCK=false are required.',
            );
          }
          final audit = SyntheticTransportAudit(manifest.endpoint);
          activeAudit = audit;
          addTearDown(audit.sealAndClose);
          await http.runWithClient(() async {
            final preflight = audit.createClient();
            try {
              final response = await preflight.get(manifest.endpoint.marker);
              manifest.checkMarker(
                jsonDecode(response.body) as Map<String, dynamic>,
                scope.hash,
              );
            } finally {
              preflight.close();
            }

            // No disk token or device preference may enter this app tree.
            SharedPreferences.setMockInitialValues({});
            final tokenStorage = InMemoryTokenStorage();
            await daftarkanAliasFont();
            await tester.pumpWidget(
              RepaintBoundary(
                key: _rootKey,
                child: ProviderScope(
                  overrides: [
                    ...penimpaanStudio,
                    ...penimpaanSesiStudio,
                    alamatServerStudioProvider.overrideWithValue(
                      manifest.endpoint.base.toString(),
                    ),
                    isianServerDevStudioProvider.overrideWithValue(false),
                    tokenStorageProvider.overrideWithValue(tokenStorage),
                  ],
                  child: const SidikStudioApp(),
                ),
              ),
            );
            await _until(
              tester,
              audit,
              () => find.byType(MasukStudioScreen).evaluate().isNotEmpty,
            );
            final container = ProviderScope.containerOf(
              tester.element(find.byType(SidikStudioApp)),
              listen: false,
            );
            expect(container.read(pembaruWindowsProvider), isNull);
            expect(
              container.read(alamatServerStudioProvider),
              manifest.endpoint.base.toString(),
            );
            final l10n = StudioL10n.of(
              tester.element(find.byType(MasukStudioScreen)),
            );
            expect(
              tester
                  .widgetList<TextField>(find.byType(TextField))
                  .every((field) => field.controller?.text.isEmpty ?? false),
              isTrue,
            );
            await _screenshot(tester, scope, '00-login.png');
            await tester.enterText(
              find.widgetWithText(TextField, l10n.isianIdentitas),
              _identifier,
            );
            await tester.enterText(
              find.widgetWithText(TextField, l10n.isianSandi),
              _password,
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.tap(
              find.widgetWithText(FilledButton, l10n.tombolMasuk),
            );
            await _until(
              tester,
              audit,
              () => find.byType(CangkangStudio).evaluate().isNotEmpty,
            );
            final user = container.read(authProvider).value;
            expect(user?.email, manifest.email);
            expect(user?.organizationId, manifest.organizationId);

            final navigation = find.byKey(
              kunciNavigasi(SeksiStudio.workbookAlat),
            );
            await _until(tester, audit, () => navigation.evaluate().isNotEmpty);
            await tester.ensureVisible(navigation);
            await tester.tap(navigation);
            final row = find.byKey(ValueKey('workbook-${manifest.workbookId}'));
            await _until(
              tester,
              audit,
              () =>
                  find.byType(DaftarWorkbookScreen).evaluate().isNotEmpty &&
                  row.evaluate().isNotEmpty,
            );
            expect(
              find.text(manifest.workbook['name'] as String),
              findsWidgets,
            );
            await tester.tap(row);
            await _until(
              tester,
              audit,
              () => find.byType(WorkbookScreen).evaluate().isNotEmpty,
            );

            for (var index = 0; index < manifest.sheets.length; index++) {
              final sheet = manifest.sheets[index];
              final id = sheet['id'] as int;
              final tab = find.byKey(ValueKey('tab-lembar-$id'));
              await _until(tester, audit, () => tab.evaluate().isNotEmpty);
              await tester.ensureVisible(tab);
              await tester.tap(tab);
              final pageKey = (
                workbookId: manifest.workbookId,
                lembarId: id,
                halaman: 0,
              );
              final listen = container.listen(
                halamanSelWorkbookProvider(pageKey),
                (_, _) {},
              );
              try {
                await _until(tester, audit, () => listen.read().hasValue);
                final page = listen.read().requireValue;
                expect(page.jumlahCacat, 0);
                for (final raw in sheet['expected_cells'] as List) {
                  final cell = raw as Map;
                  final address = AlamatSel.urai(cell['address'] as String)!;
                  final stored = page.pada(address.baris, address.kolom);
                  expect(stored, isNotNull);
                  expect(stored!.teks, cell['text']);
                  expect(stored.rumus, cell['formula']);
                  final painted = find.byKey(kunciSelGrid(address));
                  await _until(
                    tester,
                    audit,
                    () => painted.evaluate().isNotEmpty,
                  );
                  // Grid uses custom painting: inspect the real production grid's
                  // data source and select this exact visible cell in the UI.
                  await tester.tap(painted);
                  await tester.pump();
                  final grid = tester.widget<GridSel>(find.byType(GridSel));
                  final gridRef =
                      tester.element(find.byType(GridSel)) as WidgetRef;
                  expect(
                    grid.selBaca(gridRef, address.baris, address.kolom)?.teks,
                    cell['text'],
                  );
                }
                final formulaCells = (sheet['expected_cells'] as List)
                    .cast<Map>()
                    .where((cell) => cell['formula'] != null);
                if (formulaCells.isNotEmpty) {
                  final toggle = find.byKey(const ValueKey('tombol-rumus'));
                  await tester.tap(toggle);
                  await tester.pump();
                  expect(tester.widget<IconButton>(toggle).isSelected, isTrue);
                  for (final cell in formulaCells) {
                    final address = AlamatSel.urai(cell['address'] as String)!;
                    await tester.tap(find.byKey(kunciSelGrid(address)));
                    await tester.pump();
                    expect(
                      find.text(cell['formula'] as String, findRichText: true),
                      findsWidgets,
                    );
                  }
                }
                await _screenshot(
                  tester,
                  scope,
                  '1$index-${sheet['name']}.png',
                );
              } finally {
                listen.close();
              }
            }

            // Workbook is a full-screen root route; its back action must return
            // to the shell before the account/logout controls are visible.
            final back = find
                .descendant(
                  of: find.byType(WorkbookScreen),
                  matching: find.byTooltip(l10n.kembali),
                )
                .hitTestable();
            expect(back, findsOneWidget);
            await tester.tap(back);
            await _until(
              tester,
              audit,
              () =>
                  find.byType(WorkbookScreen).evaluate().isEmpty &&
                  find.byType(CangkangStudio).evaluate().isNotEmpty &&
                  (find
                          .byTooltip(l10n.keluar)
                          .hitTestable()
                          .evaluate()
                          .isNotEmpty ||
                      find
                          .byTooltip(l10n.menuAkun)
                          .hitTestable()
                          .evaluate()
                          .isNotEmpty),
            );

            // Exact production logout action, not a direct call to authController.
            final exit = find.byTooltip(l10n.keluar).hitTestable();
            if (exit.evaluate().isEmpty) {
              await tester.tap(find.byTooltip(l10n.menuAkun).hitTestable());
              await _until(
                tester,
                audit,
                () => find.text(l10n.keluar).evaluate().isNotEmpty,
              );
              await tester.tap(find.text(l10n.keluar).last);
            } else {
              await tester.tap(exit.first);
            }
            await _until(
              tester,
              audit,
              () =>
                  find.byType(MasukStudioScreen).evaluate().isNotEmpty &&
                  find
                      .widgetWithText(FilledButton, l10n.tombolMasuk)
                      .evaluate()
                      .isNotEmpty &&
                  !container.read(authProvider).isLoading,
            );
            expect(await tokenStorage.read(), isNull);
            expect(
              tester
                  .widgetList<TextField>(find.byType(TextField))
                  .every((field) => field.controller?.text.isEmpty ?? false),
              isTrue,
            );
            await _screenshot(tester, scope, '20-logout.png');
            for (final request in [
              'GET /__sidik_e2e',
              'POST /api/login',
              'GET /api/studio/me',
              'GET /api/studio/workbook',
              'GET /api/studio/workbook/${manifest.workbookId}',
              for (final sheet in manifest.sheets)
                'GET /api/studio/workbook/${manifest.workbookId}/lembar/${sheet['id']}',
              'POST /api/studio/logout',
            ]) {
              expect(audit.requests, contains(request));
            }
            scope.checkUnchanged();
            await audit.drain();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await audit.drain();
            audit.sealAndClose();
            await tester.pump();
            expect(audit.pendingCount, 0);
            expect(audit.failures, isEmpty);
          }, audit.createClient);
        },
        timeout: const Timeout(Duration(minutes: 8)),
      );
    },
    () {
      final audit = activeAudit;
      if (audit == null) {
        throw StateError('HTTP is forbidden before synthetic preflight.');
      }
      return audit.createClient();
    },
  );
}

Future<void> _until(
  WidgetTester tester,
  SyntheticTransportAudit audit,
  bool Function() ready,
) async {
  final end = DateTime.now().add(const Duration(seconds: 45));
  while (!ready()) {
    expect(audit.failures, isEmpty);
    final exception = tester.takeException();
    if (exception != null) {
      throw TestFailure('Synthetic UI raised a Flutter exception.');
    }
    expect(find.byType(ErrorWidget), findsNothing);
    if (DateTime.now().isAfter(end)) fail('Synthetic UI condition timed out.');
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
  expect(audit.failures, isEmpty);
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

Future<void> _screenshot(
  WidgetTester tester,
  SyntheticScope scope,
  String name,
) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_rootKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) fail('Synthetic screenshot encoding returned no PNG.');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    scope.checkOwnedPath(scope.screenshots.path);
    scope.screenshots.createSync(recursive: true);
    final file = File('${scope.screenshots.path}/$name');
    scope.checkOwnedPath(file.path);
    file.writeAsBytesSync(bytes, flush: true);
    expect(file.lengthSync(), bytes.length);
  } finally {
    image.dispose();
  }
}
