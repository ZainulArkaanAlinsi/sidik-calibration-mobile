import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/dashboard_summary.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/realtime_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/realtime_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Dashboard service yang ngitung berapa kali di-fetch — buat mastiin sinyal
/// realtime beneran micu refetch.
class _HitungDashboard implements DashboardService {
  int panggilan = 0;
  final _asli = MockDashboardService(jeda: Duration.zero);

  @override
  Future<DashboardSummary> ambilRingkasan(String token) {
    panggilan++;
    return _asli.ambilRingkasan(token);
  }
}

void main() {
  group('model & mock', () {
    test('DataBerubah.fromJson: field lengkap & default aman', () {
      final a = DataBerubah.fromJson({
        'jenis': 'kalibrasi',
        'aksi': 'disetujui',
        'id': 12,
      });
      expect(a.jenis, 'kalibrasi');
      expect(a.aksi, 'disetujui');
      expect(a.id, 12);

      final b = DataBerubah.fromJson(const {});
      expect(b.jenis, '');
      expect(b.aksi, '');
      expect(b.id, isNull);
    });

    test('MockRealtimeService.pancarkan → keluar di stream', () async {
      final rt = MockRealtimeService();
      final diterima = <PeristiwaRealtime>[];
      final sub = rt.peristiwa.listen(diterima.add);

      rt.pancarkan(const DataBerubah(jenis: 'sertifikat', aksi: 'terbit'));
      rt.pancarkan(const NotifikasiMasuk());
      await Future<void>.delayed(Duration.zero);

      expect(diterima, hasLength(2));
      expect(diterima.first, isA<DataBerubah>());
      expect(diterima.last, isA<NotifikasiMasuk>());
      await sub.cancel();
    });
  });

  group('realtimeServiceProvider', () {
    test('realtime nonaktif (default test) → MockRealtimeService, no socket', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Di test REVERB_APP_KEY kosong → realtimeAktif=false → mock (no-op).
      expect(container.read(realtimeServiceProvider), isA<MockRealtimeService>());
    });
  });

  group('sinkron: sinyal realtime → refetch', () {
    ProviderContainer buatContainer(MockRealtimeService rt, _HitungDashboard dash) {
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          dashboardServiceProvider.overrideWithValue(dash),
          notificationServiceProvider.overrideWithValue(MockNotificationService()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('DataBerubah → dashboard di-fetch ulang', () async {
      final rt = MockRealtimeService();
      final dash = _HitungDashboard();
      final container = buatContainer(rt, dash);

      // Aktifkan sync (butuh di-watch) + dashboard.
      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(dashboardProvider, (_, _) {});

      // Tunggu user login → realtimeSync rebuild & subscribe ke stream mock.
      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(dashboardProvider.future);
      final sebelum = dash.panggilan;

      // Sinyal realtime data berubah.
      rt.pancarkan(const DataBerubah(jenis: 'kalibrasi', aksi: 'disetujui', id: 3));
      await Future<void>.delayed(Duration.zero);
      await container.read(dashboardProvider.future);

      expect(dash.panggilan, greaterThan(sebelum),
          reason: 'sinyal realtime harus micu refetch dashboard');
    });

    test('NotifikasiMasuk → badge unread di-muat ulang', () async {
      final rt = MockRealtimeService();
      final dash = _HitungDashboard();
      final container = buatContainer(rt, dash);

      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(unreadCountProvider, (_, _) {});

      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(unreadCountProvider.future);

      // Nggak boleh lempar; badge ke-refresh setelah sinyal notifikasi.
      rt.pancarkan(const NotifikasiMasuk());
      await Future<void>.delayed(Duration.zero);
      final jml = await container.read(unreadCountProvider.future);

      expect(jml, isA<int>());
    });
  });
}
