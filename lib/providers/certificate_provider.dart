import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/certificate_snapshot.dart';
import '../services/certificate_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final certificateServiceProvider = Provider<CertificateService>((ref) {
  if (AppConfig.useMock) return MockCertificateService();
  return ApiCertificateService(ref.watch(apiClientProvider));
});

/// Isi sertifikat buat pratinjau. Family-nya keyed by id sertifikat (bukan id
/// sesi) — satu sesi bisa punya sertifikat revisi nanti.
final certificateDetailProvider =
    FutureProvider.family<CertificateDetail, int>((ref, certificateId) async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref
          .read(certificateServiceProvider)
          .detail(token, certificateId);
    }, retry: (retryCount, error) => null);
