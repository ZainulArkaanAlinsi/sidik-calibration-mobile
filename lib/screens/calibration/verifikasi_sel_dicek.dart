import '../../services/history_service.dart';
import '../../services/verifikasi_sel_service.dart';
import 'lembar_kerja_state.dart';

/// Sesudah "Kirim final" sukses: konfirmasikan ke server baris-baris yang
/// BOLEH dikonfirmasi — dan hanya itu.
///
/// ## Kenapa bukan lagi panggilan massal
///
/// Dulu satu dialog konfirmasi disusul `verifikasiPembacaan` tanpa daftar id
/// (= semua yang belum dicek), jadi satu ketukan mengesahkan seluruh bacaan
/// kamera. Sekarang gerbang di layar menahan Kirim sampai setiap sel hasil
/// kamera dicek teknisi satu per satu ([LembarKerjaState.jumlahPerluCek]), dan
/// yang dikirim ke server adalah daftar id baris yang eksplisit.
///
/// Server menandai SEMUA baris sesi ber-`input_method: ocr` sebagai belum
/// terverifikasi — termasuk yang diketik tangan. Baris tanpa sel kamera di
/// baliknya memang tidak punya yang perlu dicek; baris yang punya, selnya sudah
/// dicek (gerbang). Selama masih ada satu saja sel yang belum dicek, TIDAK ada
/// baris yang dikonfirmasi.
///
/// Mengembalikan jumlah baris yang dikonfirmasi (0 = tidak memanggil server).
Future<int> verifikasiBarisSelDicek({
  required String token,
  required int sesiId,
  required LembarKerjaState isian,
  required HistoryService riwayat,
  required VerifikasiSelService verifikasi,
}) async {
  // Jaring terakhir: gerbang di layar sudah menahan, ini menolak lagi kalau
  // ada jalur yang menembusnya.
  if (isian.jumlahPerluCek > 0) return 0;

  // Tidak ada sel hasil kamera sama sekali: tidak ada yang perlu dikonfirmasi.
  if (isian.daftarSelCek().isEmpty && !isian.adaIsianDariFoto) return 0;

  final detail = await riwayat.ambilDetail(token, sesiId);
  final ids = [
    for (final r in detail.pembacaanMentah)
      if (!r.isVerified) r.id,
  ];
  if (ids.isEmpty) return 0;

  await verifikasi.verifikasi(token, sesiId, ids);

  return ids.length;
}
