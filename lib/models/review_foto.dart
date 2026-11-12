import 'dart:typed_data';

import '../services/peta_tabel_foto.dart';
import '../services/vonis_sel_foto.dart';

/// Satu baris di layar review hasil foto — satu sel tabel yang mau dimasukkan.
///
/// [potongan] PNG potongan citra sel ini, buat diadu ke bacaannya di layar yang
/// sama. `null` = potongannya gagal dibuat (sel jatuh di luar tepi foto, atau
/// citranya sudah nggak ada). Barisnya tetap ditampilkan tanpa gambar — yang
/// hilang alat bantunya, bukan selnya.
typedef BarisReviewFoto = ({
  double titikUkur,
  int repeatNo,
  String fieldId,
  String judul,
  String teks,
  double? keyakinan,
  VonisFoto vonis,
  Uint8List? potongan,
});

/// Kunci unik satu sel — dipakai buat menjodohkan baris review dengan
/// potongan citranya, dan buat mengembalikan nilai yang disetujui.
String kunciSelFoto(double titikUkur, int repeatNo, String fieldId) =>
    '$titikUkur|$repeatNo|$fieldId';

/// Susun bahan layar review dari hasil pemetaan foto.
///
/// ## Urutannya: URUTAN KERTAS
///
/// Sampai 12 Nov 2026 yang paling butuh mata teknisi ditaruh duluan (merah,
/// lalu tidak-diketahui, lalu kuning). Itu diganti: teknisi memeriksa sel dalam
/// urutan yang sama dengan matanya menelusuri lembar (baris demi baris, kolom
/// demi kolom), karena isi cepat dengan auto-lanjut hanya masuk akal bila sel
/// berikutnya selalu tetangga sel yang baru diperiksa.
///
/// Ini KEPUTUSAN PEMILIK (isi cepat), bukan kelalaian: harganya sel merah tidak
/// lagi di atas dan bisa tenggelam di daftar panjang. Yang melindunginya
/// sekarang BUKAN urutannya, melainkan tiga pengaman yang diuji:
///
///  1. tombol Masukkan mati selama ada sel merah yang kotaknya kosong atau sel
///     kuning yang belum dicek;
///  2. layar selalu menghitung sisanya (di bawah daftar saat panel tertutup,
///     "Sisa N sel" di kepala panel isi cepat saat terbuka);
///  3. "Konfirmasi dan lanjut" memutar ke sel mana pun yang masih butuh, dan
///     mati untuk merah yang masih kosong.
///
/// Tes pengunci: `PENGAMAN urutan kertas…` (`test/foto_review_isi_cepat_test.dart`),
/// `tombol Masukkan MATI…` dan `sel KUNING wajib dicek…`
/// (`test/foto_review_screen_test.dart`). Rincian: `docs/ocr-angka-onnx.md` §10.
///
/// Urutannya `titikUkur` lalu `repeatNo`, lalu urutan masuk (jalur formulir asli
/// mengisi `titikUkur` dengan peringkat letak di kertas, lihat `urutanKertas`).
List<BarisReviewFoto> susunReviewFoto({
  required List<SelTabelFoto> sel,
  required String Function(SelTabelFoto) judul,
  Map<String, Uint8List> potongan = const {},
  AmbangKeyakinan ambang = AmbangKeyakinan.bawaan,
}) {
  final baris = [
    for (final (i, s) in sel.indexed)
      (
        urut: i,
        baris: (
          titikUkur: s.titikUkur,
          repeatNo: s.repeatNo,
          fieldId: s.fieldId,
          judul: judul(s),
          teks: s.teks,
          keyakinan: s.keyakinan,
          vonis: NilaiVonisFoto.dari(s.keyakinan, ambang: ambang),
          potongan: potongan[kunciSelFoto(s.titikUkur, s.repeatNo, s.fieldId)],
        ),
      ),
  ];

  // `List.sort` tidak stabil: urutan masuk dipakai sebagai pemutus seri.
  baris.sort((a, b) {
    final t = a.baris.titikUkur.compareTo(b.baris.titikUkur);
    if (t != 0) return t;

    final r = a.baris.repeatNo.compareTo(b.baris.repeatNo);
    if (r != 0) return r;

    return a.urut.compareTo(b.urut);
  });

  return [for (final b in baris) b.baris];
}

/// Sel yang WAJIB disentuh teknisi sebelum boleh dimasukkan.
///
/// Merah saja: kotaknya memang dikosongkan, jadi menyetujuinya tanpa mengetik
/// berarti memasukkan sel kosong. Kuning & tidak-diketahui cukup DILIHAT —
/// menuntut teknisi mengetik ulang tiga puluh sel yang bacaannya sudah benar
/// bikin dia berhenti memakai fiturnya.
bool wajibDiisi(BarisReviewFoto b) => b.vonis == VonisFoto.merah;
