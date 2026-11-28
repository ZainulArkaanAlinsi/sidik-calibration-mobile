import '../../services/history_service.dart';
import '../../services/verifikasi_sel_service.dart';
import 'lembar_kerja_state.dart';

/// Sesudah "Kirim final" sukses: konfirmasikan ke server baris-baris hasil
/// kamera yang belum terverifikasi, dengan daftar id yang eksplisit.
///
/// ## Kirim = teknisi sudah melihat lembarnya
///
/// Keputusan pemilik 27 Nov 2026: tidak ada lagi tombol/gerbang "cek bacaan
/// kamera" yang menahan Kirim. Pemeriksaannya ya teknisi itu sendiri melihat
/// lembar yang terisi otomatis (sel hasil kamera tetap bertanda kuning), lalu
/// menekan Kirim. Menekan Kirim dihitung konfirmasi teknisi; tanpa itu server
/// menolak persetujuan (422 "belum diverifikasi") dan setiap lembar foto
/// harus diverifikasi ulang admin satu per satu.
///
/// Server menandai SEMUA baris sesi ber-`input_method: ocr` sebagai belum
/// terverifikasi — termasuk yang diketik tangan. Pemisahan wewenang di server
/// tetap berlaku: yang mengonfirmasi hasil pindai tidak boleh juga
/// menyetujuinya.
///
/// Mengembalikan jumlah baris yang dikonfirmasi (0 = tidak memanggil server).
Future<int> verifikasiBarisSelDicek({
  required String token,
  required int sesiId,
  required LembarKerjaState isian,
  required HistoryService riwayat,
  required VerifikasiSelService verifikasi,
}) async {
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
