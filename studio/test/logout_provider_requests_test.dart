import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/data_acuan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/data_acuan_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/data_acuan_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';

const _oldToken = 'synthetic-unit-token';
const _user = User(
  id: 7001,
  nama: 'Synthetic Logout User',
  email: 'logout@sidik.test',
  employeeId: 'E2E-LOGOUT',
  role: UserRole.admin,
  status: UserStatus.aktif,
  organizationId: 7001,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final area in ['izin', 'workbook', 'acuan']) {
    test('logout in progress does not start another $area read', () async {
      final auth = _HeldLogout();
      final storage = InMemoryTokenStorage(_oldToken);
      final permissions = _PermissionReads();
      final workbooks = _WorkbookReads();
      final references = _ReferenceReads();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          tokenStorageProvider.overrideWithValue(storage),
          sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
          izinServiceProvider.overrideWithValue(permissions),
          workbookServiceProvider.overrideWithValue(workbooks),
          dataAcuanServiceProvider.overrideWithValue(references),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      const workbookKey = (kodeProfil: null, cari: '');
      final subscriptions = [
        container.listen(izinProvider, (_, _) {}),
        container.listen(daftarWorkbookProvider(workbookKey), (_, _) {}),
        container.listen(daftarPaketAcuanProvider, (_, _) {}),
      ];
      await container.read(izinProvider.future);
      await container.read(daftarWorkbookProvider(workbookKey).future);
      await container.read(daftarPaketAcuanProvider.future);

      Map<String, int> counts() => {
        'izin': permissions.calls,
        'workbook': workbooks.calls,
        'acuan': references.calls,
      };
      expect(counts(), {'izin': 1, 'workbook': 1, 'acuan': 1});

      final logout = container.read(authProvider.notifier).logout();
      await auth.started.future;
      try {
        expect(container.read(authProvider).isLoading, isTrue);
        expect(await storage.read(), _oldToken);
        expect(auth.logoutToken, _oldToken);
        // Flush provider rebuilds while the server logout remains unresolved.
        // No real-time delay, native HTTP, or synthetic transport is involved.
        await container.pump();
        await Future<void>.delayed(Duration.zero);
        await container.pump();
        expect(
          counts()[area],
          1,
          reason:
              'The server is still revoking this token. Auth loading must not '
              'start a new $area read. Actual reads: ${counts()}',
        );
      } finally {
        auth.release.complete();
        await logout;
        for (final subscription in subscriptions) {
          subscription.close();
        }
      }
    });
  }
}

class _HeldLogout extends MockAuthService {
  _HeldLogout() : super(jeda: Duration.zero);

  final started = Completer<void>();
  final release = Completer<void>();
  String? logoutToken;

  @override
  Future<User> me(String token) async => _user;

  @override
  Future<void> logout(String token) async {
    logoutToken = token;
    started.complete();
    await release.future;
  }
}

class _PermissionReads implements IzinService {
  int calls = 0;

  @override
  Future<Izin> ambil(String token) async {
    calls++;
    return Izin.kosong;
  }
}

class _WorkbookReads extends MockWorkbookService {
  int calls = 0;

  @override
  Future<List<WorkbookRingkas>> daftar(
    String token, {
    String? kodeProfil,
    String? cari,
  }) async {
    calls++;
    return const [];
  }
}

class _ReferenceReads extends MockDataAcuanService {
  int calls = 0;

  @override
  Future<List<PaketAcuan>> daftarPaket(String token) async {
    calls++;
    return const [];
  }
}
