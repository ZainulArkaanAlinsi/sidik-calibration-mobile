import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/ganti_sandi_service.dart';
import 'auth_provider.dart';

/// Cuma service-nya. Layar Ganti sandi tidak menyimpan apa pun dari server di
/// provider (formulir sekali pakai), dan sandi TIDAK PERNAH masuk state yang
/// bertahan — kolomnya hidup di `TextEditingController` layar saja dan
/// dikosongkan begitu permintaan selesai.
final gantiSandiServiceProvider = Provider<GantiSandiService>((ref) {
  if (AppConfig.useMock) return MockGantiSandiService();
  return ApiGantiSandiService(ref.watch(apiClientProvider));
});
