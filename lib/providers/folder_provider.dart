import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/folder.dart';
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
