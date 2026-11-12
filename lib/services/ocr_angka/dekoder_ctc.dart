import 'dart:math' as math;
import 'dart:typed_data';

/// Hasil dekode CTC greedy satu sel.
class HasilDekodeCtc {
  const HasilDekodeCtc({
    required this.teks,
    required this.peluangKarakter,
    required this.jalur,
    this.valid = true,
  });

  /// Keluaran model tak bisa dipakai (nilai NaN, tak hingga, atau negatif):
  /// tidak ada bacaan, tidak pernah jadi usulan. Pemanggil menahan selnya.
  const HasilDekodeCtc.tidakValid()
    : this(teks: '', peluangKarakter: const [], jalur: 0, valid: false);

  /// Bacaan mentah (hanya karakter alfabet). Kosong = model tidak melihat isi.
  final String teks;

  /// Peluang puncak tiap karakter di [teks], setelah dinormalkan ulang.
  final List<double> peluangKarakter;

  /// Skor sel `jalur`: rata-rata geometrik peluang maksimum SEMUA frame
  /// (blank ikut). 0 bila [teks] kosong.
  ///
  /// **Bukan peluang benar.** Di rig skor ini terlalu yakin (ECE 0,44–0,57):
  /// ~0,99 pada sel yang benar hanya ±60%. Hanya peringkat dan ambang yang
  /// bermakna; jangan tampilkan sebagai persen.
  final double jalur;

  /// `false` bila ada nilai tak finit atau negatif di keluaran model.
  final bool valid;
}

/// Pemilihan kolom keluaran model + dekode CTC greedy. Sama dengan
/// `MesinPaddle._jalan/_hasil` dan `dekode.dekode` di rig `sidik-ocr-eval`.
class DekoderCtc {
  const DekoderCtc._();

  /// Alfabet whitelist; kolom ke-0 whitelist adalah blank, kolom ke-1.. = huruf
  /// ini berurutan.
  static const alfabet = '0123456789.,-';

  /// Ambil kolom whitelist dari keluaran model `[frame, kelas]` (baris demi
  /// baris). [kolom] = indeks kelas model untuk `[blank, ...alfabet]`.
  ///
  /// Keluaran model PP-OCR sudah softmax. Seperti rig, bila baris pertama tidak
  /// berjumlah 1 (selisih > 0,01) keluaran dianggap logit dan di-softmax dulu.
  /// Hasil: `[frame, kolom.length]` peluang MENTAH (belum dinormalkan ulang).
  static Float64List ambilKolom(
    Float32List keluaran,
    int frame,
    int kelas,
    List<int> kolom,
  ) {
    if (frame < 1 || kelas < 1 || keluaran.length < frame * kelas) {
      throw ArgumentError('keluaran ${keluaran.length} < $frame×$kelas');
    }
    for (final k in kolom) {
      if (k < 0 || k >= kelas) {
        throw ArgumentError('kolom $k di luar 0..${kelas - 1}');
      }
    }

    var jumlah0 = 0.0;
    for (var k = 0; k < kelas; k++) {
      jumlah0 += keluaran[k];
    }
    final softmax = (jumlah0 - 1.0).abs() > 1e-2;

    final hasil = Float64List(frame * kolom.length);
    for (var t = 0; t < frame; t++) {
      var maks = double.negativeInfinity;
      var penyebut = 1.0;
      if (softmax) {
        for (var k = 0; k < kelas; k++) {
          maks = math.max(maks, keluaran[t * kelas + k]);
        }
        penyebut = 0;
        for (var k = 0; k < kelas; k++) {
          penyebut += math.exp(keluaran[t * kelas + k] - maks);
        }
      }
      for (var j = 0; j < kolom.length; j++) {
        final v = keluaran[t * kelas + kolom[j]];
        hasil[t * kolom.length + j] = softmax
            ? math.exp(v - maks) / penyebut
            : v.toDouble();
      }
    }

    return hasil;
  }

  /// Dekode greedy dari peluang mentah `[frame, 1 + alfabet.length]`
  /// (kolom 0 = blank).
  ///
  /// Tiap frame dinormalkan ulang ke blank + whitelist, argmax per frame, blank
  /// dibuang, karakter kembar berurutan dilebur (blank memisahkan); peluang
  /// karakter = puncak di run-nya.
  static HasilDekodeCtc dekode(
    Float64List mentah,
    int frame, {
    String alfabet = DekoderCtc.alfabet,
  }) {
    final lebar = alfabet.length + 1;
    if (frame < 1 || mentah.length != frame * lebar) {
      throw ArgumentError('mentah ${mentah.length} != $frame×$lebar');
    }

    // Peluang harus finit dan tidak negatif. NaN yang lolos sampai sini akan
    // menghasilkan skor NaN, dan `NaN < ambang` salah: sel lolos jadi usulan.
    for (final v in mentah) {
      if (!v.isFinite || v < 0) return const HasilDekodeCtc.tidakValid();
    }

    final teks = StringBuffer();
    final pk = <double>[];
    var prev = -1;
    var jumlahLog = 0.0;

    for (var t = 0; t < frame; t++) {
      var jumlah = 0.0;
      for (var k = 0; k < lebar; k++) {
        jumlah += mentah[t * lebar + k];
      }
      final pembagi = math.max(jumlah, 1e-9);

      var arg = 0;
      var mx = mentah[t * lebar] / pembagi;
      for (var k = 1; k < lebar; k++) {
        final p = mentah[t * lebar + k] / pembagi;
        if (p > mx) {
          mx = p;
          arg = k;
        }
      }

      if (arg != 0) {
        if (arg != prev) {
          teks.write(alfabet[arg - 1]);
          pk.add(mx);
        } else if (mx > pk.last) {
          pk[pk.length - 1] = mx;
        }
      }
      prev = arg;
      jumlahLog += math.log(math.max(mx, 1e-9));
    }

    return HasilDekodeCtc(
      teks: teks.toString(),
      peluangKarakter: pk,
      jalur: pk.isEmpty ? 0.0 : math.exp(jumlahLog / frame),
    );
  }
}
