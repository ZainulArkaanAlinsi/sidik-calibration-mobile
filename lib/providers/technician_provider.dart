import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/technician_service.dart';
import 'auth_provider.dart';

/// Cuma service-nya. Layar "Buat akun teknisi" tidak menyimpan data server di
/// provider mana pun (formulir sekali pakai), jadi tidak ada yang bisa
/// tertinggal waktu ganti akun; daftar akun yang berubah karenanya
/// (`userListProvider`) di-invalidate oleh layarnya.
final technicianServiceProvider = Provider<TechnicianService>((ref) {
  if (AppConfig.useMock) return MockTechnicianService();
  return ApiTechnicianService(ref.watch(apiClientProvider));
});
