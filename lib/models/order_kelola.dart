/// Bentuk kiriman tulis Order (`POST/PUT /orders`) — dipakai layar kelola order.
///
/// Sumber bentuk: `OrderRequest` + `OrderController` di repo API
/// (`store`/`update`/`destroy`). Nomor order TIDAK pernah dikirim: server yang
/// membuatnya (`ORD/YYYY/MM/NNNN`) dalam satu transaksi.
library;

import 'order.dart';

/// Status order yang diterima server (`Order::statuses()`).
abstract final class StatusOrder {
  static const baru = 'baru';
  static const diproses = 'diproses';
  static const selesai = 'selesai';
  static const dibatalkan = 'dibatalkan';

  static const semua = [baru, diproses, selesai, dibatalkan];
}

/// `yyyy-MM-dd` dari komponen tanggal (tanpa zona waktu, supaya tanggal yang
/// dipilih orang tidak bergeser sehari saat diubah ke UTC).
String tanggalKirim(DateTime tanggal) =>
    '${tanggal.year.toString().padLeft(4, '0')}-'
    '${tanggal.month.toString().padLeft(2, '0')}-'
    '${tanggal.day.toString().padLeft(2, '0')}';

/// Tanggal (tanpa jam) dari nilai tanggal server.
///
/// Server menyimpan `tanggal_masuk`/`tanggal_janji_selesai` sebagai tanggal
/// dan zona aplikasinya `Asia/Jakarta` (UTC+7); `toIso8601ZuluString()`
/// mengubah "16 Nov 00:00 WIB" menjadi `2026-11-15T17:00:00Z`. Membaca bidang
/// UTC-nya mentah-mentah memberi tanggal SEHARI lebih awal. Jadi dikembalikan
/// ke WIB dulu, tidak bergantung pada zona HP. Nilai tengah malam UTC
/// (mis. data uji) tetap jatuh di tanggal yang sama.
DateTime? tanggalDariServer(DateTime? t) {
  if (t == null) return null;
  final wib = t.toUtc().add(const Duration(hours: 7));
  return DateTime(wib.year, wib.month, wib.day);
}

/// Janji selesai sudah lewat dan order belum selesai/dibatalkan.
///
/// Dihitung dari TANGGAL WIB ([tanggalDariServer]), bukan dari instan UTC:
/// janji "30 Nov" tiba sebagai `29 Nov 17:00Z`, dan membandingkannya mentah
/// dengan jam sekarang menandai order "terlambat" sejak 30 Nov 00:00, padahal
/// janjinya masih berlaku sepanjang hari itu. Order yang dibatalkan tidak
/// pernah dianggap terlambat (pekerjaan itu memang tidak jadi).
bool orderTerlambat(OrderKalibrasi o, {DateTime? sekarang}) {
  final janji = tanggalDariServer(o.tanggalJanjiSelesai);
  if (janji == null ||
      o.status == StatusOrder.selesai ||
      o.status == StatusOrder.dibatalkan) {
    return false;
  }
  final n = sekarang ?? DateTime.now();
  return janji.isBefore(DateTime(n.year, n.month, n.day));
}

/// Satu baris alat di form order.
class ItemOrderForm {
  const ItemOrderForm({
    required this.alatId,
    required this.namaAlat,
    this.serialNumber = '',
    this.teknisiId,
    this.namaTeknisi,
    this.kondisiTerima = '',
    this.kelengkapan = '',
    this.catatan = '',
  });

  /// Dari baris order yang sudah tersimpan (mode ubah).
  factory ItemOrderForm.dariItem(OrderItem item) => ItemOrderForm(
    alatId: item.alatId ?? 0,
    namaAlat: item.namaAlat,
    serialNumber: item.serialNumber,
    teknisiId: item.teknisiId,
    namaTeknisi: item.namaTeknisi,
    kondisiTerima: item.kondisiTerima ?? '',
    kelengkapan: item.kelengkapan ?? '',
    catatan: item.catatan ?? '',
  );

  final int alatId;
  final String namaAlat;
  final String serialNumber;
  final int? teknisiId;
  final String? namaTeknisi;
  final String kondisiTerima;
  final String kelengkapan;
  final String catatan;

  /// `teknisiId` memakai pembungkus supaya "kosongkan teknisi" (null) bisa
  /// dibedakan dari "tidak diubah".
  ItemOrderForm salin({
    ({int? id, String? nama})? teknisi,
    String? kondisiTerima,
    String? kelengkapan,
    String? catatan,
  }) => ItemOrderForm(
    alatId: alatId,
    namaAlat: namaAlat,
    serialNumber: serialNumber,
    teknisiId: teknisi == null ? teknisiId : teknisi.id,
    namaTeknisi: teknisi == null ? namaTeknisi : teknisi.nama,
    kondisiTerima: kondisiTerima ?? this.kondisiTerima,
    kelengkapan: kelengkapan ?? this.kelengkapan,
    catatan: catatan ?? this.catatan,
  );

  static String? _atauNull(String s) => s.trim().isEmpty ? null : s.trim();

  Map<String, dynamic> toJson() => {
    'equipment_id': alatId,
    'teknisi_id': teknisiId,
    'kondisi_terima': _atauNull(kondisiTerima),
    'kelengkapan': _atauNull(kelengkapan),
    'catatan': _atauNull(catatan),
  };
}

/// Isi form order yang siap dikirim.
class FormOrder {
  const FormOrder({
    required this.pelangganId,
    required this.tanggalMasuk,
    required this.items,
    this.tanggalJanjiSelesai,
    this.status,
    this.catatan = '',
  });

  final int pelangganId;
  final DateTime tanggalMasuk;
  final DateTime? tanggalJanjiSelesai;

  /// Hanya dikirim saat UBAH (order baru selalu `baru` di server).
  final String? status;
  final String catatan;
  final List<ItemOrderForm> items;

  /// [buat] true = `POST`: ikut `customer_id`, tanpa `status`. Mode ubah tidak
  /// mengirim `customer_id` (pelanggan order tidak diganti dari aplikasi).
  Map<String, dynamic> toJson({required bool buat}) => {
    if (buat) 'customer_id': pelangganId,
    'tanggal_masuk': tanggalKirim(tanggalMasuk),
    // `null` eksplisit = mengosongkan janji selesai saat ubah.
    'tanggal_janji_selesai': tanggalJanjiSelesai == null
        ? null
        : tanggalKirim(tanggalJanjiSelesai!),
    if (!buat && status != null) 'status': status,
    'catatan': catatan.trim().isEmpty ? null : catatan.trim(),
    'items': [for (final i in items) i.toJson()],
  };
}
