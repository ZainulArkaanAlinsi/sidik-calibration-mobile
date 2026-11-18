import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/izin.dart';
import '../../providers/izin_provider.dart';

/// Gerbang layar CRUD lab (Order, Penugasan, Kategori alat, Arsip draf) —
/// semuanya dari izin server (`GET /me/permissions`), bukan tebakan peran
/// (kontrak `docs/perintah-frontend-crud-lengkap.md` §0 butir 1).
///
/// Menyembunyikan tombol BUKAN kontrol akses: server tetap menolak (403).
///
/// - **Kunci BARU** di server (`kategori.kelola`, `penugasan.ubah`,
///   `penugasan.batalkan`, `kalibrasi.arsipkan`, `kalibrasi.pulihkan`) ditanya
///   dengan `cadangan: false`: bila server tidak menyebutnya, jawabannya TIDAK.
/// - **Order** belum punya kunci izin sendiri di `MatriksIzin::PETA`. Rute
///   tulisnya (`POST/PUT/DELETE /orders`) satu grup `role:admin` dengan
///   `POST /customers`, jadi bertanya ke `pelanggan.kelola` — pola yang sama
///   dengan Audit yang menumpang `pengguna.kelola`. Cadangannya juga `false`:
///   baris baru di Kelola lab tidak boleh muncul dari tebakan peran selama
///   jawaban `/me/permissions` belum ada. Bila server menambah `order.kelola`,
///   ganti di SATU tempat ini.
extension HakCrudLab on WidgetRef {
  bool get bolehKelolaOrder =>
      bolehkah(NamaIzin.pelangganKelola, cadangan: false);

  bool get bolehKelolaKategori =>
      bolehkah(NamaIzin.kategoriKelola, cadangan: false);

  bool get bolehUbahPenugasan =>
      bolehkah(NamaIzin.penugasanUbah, cadangan: false);

  bool get bolehBatalkanPenugasan =>
      bolehkah(NamaIzin.penugasanBatalkan, cadangan: false);

  bool get bolehArsipkanDraf =>
      bolehkah(NamaIzin.kalibrasiArsipkan, cadangan: false);

  /// Daftar & pemulihan arsip draf (kunci `kalibrasi.pulihkan`: admin dan
  /// super admin saja).
  bool get bolehPulihkanDraf =>
      bolehkah(NamaIzin.kalibrasiPulihkan, cadangan: false);

  /// Pintu masuk ke seluruh bagian ini (satu baris di Kelola lab): muncul bila
  /// ada SATU saja pintu di dalamnya yang boleh dibuka.
  bool get bolehPengelolaanData =>
      bolehKelolaOrder ||
      bolehKelolaKategori ||
      bolehUbahPenugasan ||
      bolehBatalkanPenugasan ||
      bolehPulihkanDraf;
}
