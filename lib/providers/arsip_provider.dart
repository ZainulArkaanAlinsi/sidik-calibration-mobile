import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/arsip.dart';
import '../services/arsip_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final arsipServiceProvider = Provider<ArsipService>(
  (ref) => ApiArsipService(ref.watch(apiClientProvider)),
);

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Daftar folder perusahaan (akar Arsip). Family-nya keyed by kata kunci
/// pencarian — ganti kata kunci = kueri baru.
final arsipPerusahaanProvider =
    FutureProvider.family<List<ArsipPerusahaan>, String>((ref, cari) async {
      final token = await _token(ref);
      return ref.read(arsipServiceProvider).daftarPerusahaan(token, cari: cari);
    }, retry: (retryCount, error) => null);

/// Alamat satu folder yang lagi dibuka.
///
/// Dibungkus jadi tipe sendiri (bukan `int` polos) karena pintu masuknya ada
/// dua: lewat perusahaan (folder akarnya dibikin backend kalau belum ada) dan
/// lewat id folder langsung. Kalau dua-duanya `int`, gampang ketuker — dan
/// ketukernya nggak keliatan sampai layarnya nampilin folder perusahaan lain.
class AlamatFolder {
  const AlamatFolder.perusahaan(this.id) : lewatPerusahaan = true;
  const AlamatFolder.folder(this.id) : lewatPerusahaan = false;

  final int id;
  final bool lewatPerusahaan;

  @override
  bool operator ==(Object other) =>
      other is AlamatFolder &&
      other.id == id &&
      other.lewatPerusahaan == lewatPerusahaan;

  @override
  int get hashCode => Object.hash(id, lewatPerusahaan);
}

final arsipIsiFolderProvider =
    FutureProvider.family<ArsipIsiFolder, AlamatFolder>((ref, alamat) async {
      final token = await _token(ref);
      final service = ref.read(arsipServiceProvider);

      return alamat.lewatPerusahaan
          ? service.bukaPerusahaan(token, alamat.id)
          : service.bukaFolder(token, alamat.id);
    }, retry: (retryCount, error) => null);

/// Aksi nyusun folder. Balikin `null` kalau sukses, atau pesan error dari
/// backend kalau gagal — layar yang nampilin, biar pesan 422 yang udah
/// diformat backend ("Folder masih ada isinya...") kekirim apa adanya.
class ArsipAksi {
  ArsipAksi(this._ref);

  final Ref _ref;

  Future<String?> _jalankan(Future<void> Function(String token) aksi) async {
    try {
      final token = await _token(_ref);
      await aksi(token);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> bikin({required int parentId, required String nama}) =>
      _jalankan((t) => _ref
          .read(arsipServiceProvider)
          .bikinFolder(t, parentId: parentId, nama: nama));

  Future<String?> ubahNama({required int folderId, required String nama}) =>
      _jalankan((t) => _ref
          .read(arsipServiceProvider)
          .ubahNama(t, folderId: folderId, nama: nama));

  Future<String?> pindah({required int folderId, required int parentId}) =>
      _jalankan((t) => _ref
          .read(arsipServiceProvider)
          .pindahFolder(t, folderId: folderId, parentId: parentId));

  Future<String?> hapus(int folderId) =>
      _jalankan((t) => _ref.read(arsipServiceProvider).hapusFolder(t, folderId));

  Future<String?> pindahBerkas({required int sesiId, required int folderId}) =>
      _jalankan((t) => _ref
          .read(arsipServiceProvider)
          .pindahBerkas(t, sesiId: sesiId, folderId: folderId));
}

final arsipAksiProvider = Provider<ArsipAksi>(ArsipAksi.new);
