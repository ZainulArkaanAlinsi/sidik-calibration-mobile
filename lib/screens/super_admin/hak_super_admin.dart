import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/izin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';

/// Gerbang layar pengelolaan Super Admin — SEMUANYA dari izin server
/// (`GET /me/permissions`), tidak pernah dari tebakan peran
/// (kontrak `docs/perintah-frontend-super-admin.md` §0 butir 1).
///
/// Kunci yang BARU di server (`pengguna.buat-admin`, `pengguna.ubah-status`,
/// `anggota-pelanggan.lihat`, `.cabut`) ditanyakan dengan `cadangan: false`:
/// bila server tidak menyebutnya, jawabannya TIDAK — aturan peran lama tidak
/// boleh menyalakan tombol yang rutenya belum ada di server. Kunci lama
/// (`pengguna.kelola`, `pengguna.setujui`, `teknisi.kelola`,
/// `anggota-pelanggan.undang`, `.pic-admin`) memakai cadangan "hak admin"
/// seperti layar lama yang sudah ada.
///
/// Menyembunyikan tombol bukan kontrol akses: server tetap menolak (403).
extension HakSuperAdmin on WidgetRef {
  bool get _hakAdmin => watch(authProvider).value?.role.hakAdmin ?? false;

  /// Pintu masuk ke seluruh bagian ini (satu baris di Kelola lab). Hanya
  /// kunci yang HANYA dipegang super admin: Master Data tidak mendapat menu
  /// baru, walau rute daftar anggota terbuka untuknya di server.
  bool get bolehPengelolaanSa =>
      bolehkah(NamaIzin.penggunaBuatAdmin, cadangan: false) ||
      bolehkah(NamaIzin.penggunaUbahStatus, cadangan: false);

  bool get bolehLihatPengguna =>
      bolehkah(NamaIzin.penggunaKelola, cadangan: _hakAdmin);
  bool get bolehBuatAdmin =>
      bolehkah(NamaIzin.penggunaBuatAdmin, cadangan: false);
  bool get bolehBuatTeknisi =>
      bolehkah(NamaIzin.teknisiKelola, cadangan: _hakAdmin);
  bool get bolehUbahStatusPengguna =>
      bolehkah(NamaIzin.penggunaUbahStatus, cadangan: false);
  bool get bolehSetujuiPengguna =>
      bolehkah(NamaIzin.penggunaSetujui, cadangan: _hakAdmin);

  bool get bolehLihatAnggota =>
      bolehkah(NamaIzin.anggotaPelangganLihat, cadangan: false);
  bool get bolehCabutAnggota =>
      bolehkah(NamaIzin.anggotaPelangganCabut, cadangan: false);
  bool get bolehUndangAnggota =>
      bolehkah(NamaIzin.anggotaPelangganUndang, cadangan: _hakAdmin);
  bool get bolehUbahPicAdmin =>
      bolehkah(NamaIzin.anggotaPelangganPicAdmin, cadangan: _hakAdmin);

  bool get bolehLihatAlatPelanggan =>
      bolehkah(NamaIzin.pelangganAlatLihat, cadangan: false);
  bool get bolehLihatRiwayatSertifikat =>
      bolehkah(NamaIzin.alatRiwayatSertifikat, cadangan: false);
  bool get bolehPindahAlat =>
      bolehkah(NamaIzin.pelangganPindahAlat, cadangan: false);
}
