import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/folder.dart';
import '../services/auth_service.dart' show AuthException;
import '../services/folder_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final folderServiceProvider = Provider<FolderService>((ref) {
  if (AppConfig.useMock) return MockFolderService();
  return ApiFolderService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Isi satu tingkat folder. Family-nya keyed by `parentId` (null = akar),
/// jadi tiap tingkat punya cache-nya sendiri — balik dari sub-folder nggak
/// nembak ulang tingkat di atasnya.
final folderListProvider = FutureProvider.family<List<Folder>, int?>((
  ref,
  parentId,
) async {
  final token = await _token(ref);
  return ref.read(folderServiceProvider).daftar(token, parentId: parentId);
}, retry: (retryCount, error) => null);

/// Sub-folder + file di dalam satu folder.
final folderDetailProvider = FutureProvider.family<Folder, int>((
  ref,
  id,
) async {
  final token = await _token(ref);
  return ref.read(folderServiceProvider).detail(token, id);
}, retry: (retryCount, error) => null);

/// Aksi tulis Folder Manager (buat / ganti nama / hapus).
///
/// Dipisah dari provider baca supaya tiap aksi bisa nyegerin **tingkat yang
/// kena aja** — bikin sub-folder di dalam PT nggak perlu narik ulang daftar
/// PT-nya.
///
/// Semua aksi di sini **admin doang**; backend nolak role lain dengan 403.
/// Layar nyembunyiin tombolnya, tapi yang beneran njagain tetap backend.
final folderAksiProvider = Provider<FolderAksi>(FolderAksi.new);

class FolderAksi {
  FolderAksi(this._ref);

  final Ref _ref;

  Future<String?> _jalankan(
    Future<void> Function(String token) aksi, {
    required int? tingkat,
  }) async {
    final token = await _ref.read(tokenStorageProvider).read();
    if (token == null) return null;

    try {
      await aksi(token);
    } catch (e) {
      // Pesan dari backend dipakai apa adanya — dia yang paling tau konteksnya
      // ("folder otomatis yang masih ada isinya nggak bisa dihapus", "sudah ada
      // folder bernama X di lokasi ini"). Layar cuma nampilin.
      return e is AuthException ? e.message : '$e';
    }

    _segarkan(tingkat);
    return null;
  }

  /// Segerin daftar induknya + detailnya, karena jumlah isi ikut berubah.
  void _segarkan(int? parentId) {
    _ref.invalidate(folderListProvider(parentId));
    if (parentId != null) _ref.invalidate(folderDetailProvider(parentId));
  }

  /// Balikin pesan error, atau `null` kalau berhasil.
  Future<String?> buat({required String nama, int? parentId}) => _jalankan(
    (token) => _ref
        .read(folderServiceProvider)
        .buat(token, nama: nama, parentId: parentId),
    tingkat: parentId,
  );

  Future<String?> gantiNama({
    required int id,
    required String nama,
    int? parentId,
  }) => _jalankan(
    (token) => _ref.read(folderServiceProvider).ubah(token, id, nama: nama),
    tingkat: parentId,
  );

  Future<String?> hapus({required int id, int? parentId}) => _jalankan(
    (token) => _ref.read(folderServiceProvider).hapus(token, id),
    tingkat: parentId,
  );
}
