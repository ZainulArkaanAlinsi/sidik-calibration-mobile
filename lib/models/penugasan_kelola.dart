/// Bentuk kiriman ubah penugasan (`PUT /penugasan/{id}`).
///
/// Sumber: `docs/perintah-frontend-crud-lengkap.md` §4.1 dan
/// `PenugasanUbahRequest` di repo API. Ini PENGGANTI penuh untuk `judul`,
/// `teknisi`, dan `item`; field opsional yang TIDAK dikirim dibiarkan server
/// (kolom `catatan` baris juga dipakai teknisi untuk catatan progres, jadi
/// mengosongkannya diam-diam akan menghapus tulisan orang lain).
library;

import 'order_kelola.dart' show tanggalKirim;
import 'penugasan.dart';

/// Satu baris jenis-alat di form ubah.
class BarisUbahPenugasan {
  const BarisUbahPenugasan({
    this.id,
    required this.jenisAlat,
    required this.jumlah,
    this.jumlahSelesai = 0,
    this.catatan = '',
    this.paket,
  });

  /// Dari baris tersimpan: `id` ikut dikirim supaya progres teknisi
  /// (`jumlah_selesai`) tidak hilang.
  factory BarisUbahPenugasan.dari(BarisPenugasan b) => BarisUbahPenugasan(
    id: b.id,
    jenisAlat: b.jenisAlat,
    jumlah: b.jumlah,
    jumlahSelesai: b.jumlahSelesai,
    paket: b.paket,
  );

  /// `null` = baris baru.
  final int? id;
  final String jenisAlat;
  final int jumlah;

  /// Milik teknisi; hanya ditampilkan, TIDAK pernah dikirim.
  final int jumlahSelesai;

  /// Hanya dikirim untuk baris BARU (baris lama dibiarkan server).
  final String catatan;

  /// Nomor paket/order yang tertaut (hanya tampilan).
  final String? paket;

  bool get baru => id == null;

  /// Baris yang sudah ada progresnya tidak boleh dibuang (server menolak
  /// `422 item_sudah_dikerjakan`).
  bool get sudahDikerjakan => jumlahSelesai > 0;

  BarisUbahPenugasan salin({String? jenisAlat, int? jumlah, String? catatan}) =>
      BarisUbahPenugasan(
        id: id,
        jenisAlat: jenisAlat ?? this.jenisAlat,
        jumlah: jumlah ?? this.jumlah,
        jumlahSelesai: jumlahSelesai,
        catatan: catatan ?? this.catatan,
        paket: paket,
      );

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'jenis_alat': jenisAlat.trim(),
    'jumlah': jumlah,
    // Baris lama: catatan TIDAK dikirim (dibiarkan). Baris baru: hanya bila
    // diisi.
    if (baru && catatan.trim().isNotEmpty) 'catatan': catatan.trim(),
  };
}

/// Isi form ubah penugasan.
class FormUbahPenugasan {
  const FormUbahPenugasan({
    required this.judul,
    required this.teknisi,
    required this.baris,
    this.tanggalTarget,
    this.catatan = '',
    required this.awal,
  });

  final String judul;

  /// Berurutan: yang PERTAMA jadi ketua.
  final List<int> teknisi;
  final List<BarisUbahPenugasan> baris;
  final DateTime? tanggalTarget;
  final String catatan;

  /// Penugasan sebelum diubah — pembanding agar field opsional hanya dikirim
  /// bila berubah.
  final Penugasan awal;

  static DateTime? _hari(DateTime? t) =>
      t == null ? null : DateTime(t.year, t.month, t.day);

  bool get tanggalBerubah => _hari(tanggalTarget) != _hari(awal.tanggalTarget);

  bool get catatanBerubah =>
      catatan.trim() != (awal.catatan ?? '').trim();

  Map<String, dynamic> toJson() => {
    'judul': judul.trim(),
    // Hanya bila berubah: tanggal LAMA yang sudah lewat tetap sah bila tidak
    // disentuh, dan `null` eksplisit = mengosongkan.
    if (tanggalBerubah)
      'tanggal_target': tanggalTarget == null
          ? null
          : tanggalKirim(tanggalTarget!),
    if (catatanBerubah)
      'catatan': catatan.trim().isEmpty ? null : catatan.trim(),
    'teknisi': teknisi,
    'item': [for (final b in baris) b.toJson()],
  };
}
