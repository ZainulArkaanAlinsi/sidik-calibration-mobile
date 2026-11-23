import '../models/worksheet_template.dart' show KotakSel;

/// Satu kata hasil OCR awan (`kata[]` dari `POST /api/ocr/halaman`).
///
/// Kotaknya dinormalkan 0..1 terhadap halaman yang DIKIRIM ke backend, jadi
/// halaman itu harus citra hasil warp yang ruangnya sama dengan
/// `ukuranReferensi` templat. Foto mentah yang belum diluruskan tidak boleh
/// dipetakan: kotak sel di templat hanya berlaku di ruang citra hasil warp.
class KataHalaman {
  const KataHalaman({
    required this.teks,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    this.keyakinan,
  });

  /// Teks APA ADANYA dari OCR. Tidak pernah dibersihkan, dibulatkan, atau
  /// disesuaikan ke format sel di sini maupun di fungsi pemetaan.
  final String teks;
  final double x0;
  final double y0;
  final double x1;
  final double y1;

  /// 0..1 dari Google, `null` bila tidak diberikan. Itu keyakinan OCR umum,
  /// bukan peluang bahwa angka tulisan tangan itu benar.
  final double? keyakinan;
}

enum StatusSelPetaan {
  /// Tidak ada kata di sel. Sel kosong TETAP kosong: tidak diisi tebakan.
  kosong,

  /// Tepat satu kata, keyakinan cukup. Tetap USULAN, bukan hasil: yang
  /// memutuskan itu angka valid atau bukan hanya server, dan yang
  /// mengonfirmasi teknisi. Sengaja tidak ada status "hijau" di sini.
  usulan,

  /// Ada sesuatu yang membuat pemetaannya tidak boleh dipercaya begitu saja;
  /// alasannya ada di [HasilSelPetaan.alasan]. Teks mentahnya tetap disimpan.
  ragu,
}

enum AlasanRagu {
  keyakinanRendah,
  keyakinanTidakAda,
  lebihDariSatuKata,

  /// Satu kata menimpa dua sel atau lebih. Kata itu tidak dipecah: teksnya
  /// masuk utuh ke tiap sel yang ditimpa dan semuanya ditandai ragu.
  kataMelintasiSel,

  /// Hanya satu sel yang tersentuh, tetapi sebagian kata berada di luarnya.
  kataSebagianDiLuarSel,
}

/// Selisih pembulatan double saat membandingkan bagian luas dengan ambang.
const _toleransi = 1e-9;

class HasilSelPetaan {
  const HasilSelPetaan({
    required this.kunci,
    required this.teksMentah,
    required this.status,
    required this.alasan,
    required this.kata,
  });

  /// Kunci sel templat, dipakai APA ADANYA (jangan disusun ulang dari indeks).
  final String kunci;

  /// Kata-kata sel digabung dengan satu spasi, urut dari kiri. `null` hanya
  /// bila sel [StatusSelPetaan.kosong].
  final String? teksMentah;
  final StatusSelPetaan status;
  final Set<AlasanRagu> alasan;
  final List<KataHalaman> kata;
}

class HasilPemetaanHalaman {
  const HasilPemetaanHalaman({
    required this.sel,
    required this.tidakTerpetakan,
  });

  final Map<String, HasilSelPetaan> sel;

  /// Kata yang tidak jatuh cukup ke dalam sel mana pun (atau kotaknya rusak).
  /// Tidak dibuang diam-diam: ada teks di halaman yang tidak punya sel, dan
  /// itu layak diketahui teknisi.
  final List<KataHalaman> tidakTerpetakan;
}

/// Menempatkan kata hasil OCR awan ke sel templat. Fungsi murni: tidak ada
/// jaringan, tidak ada penilaian benar-salah angka.
///
/// Pemanggil WAJIB sudah memeriksa `WorksheetTemplate.siapPindai`; geometri sel
/// yang belum diukur dari lembar cetak asli akan mendaratkan angka di sel yang
/// salah tanpa ada yang error. Fungsi ini tidak bisa mendeteksinya.
///
/// Mengembalikan `null` bila pemetaan mustahil (ukuran referensi tidak ada atau
/// tidak positif, atau templat tanpa sel); pemanggil jatuh ke pembaca on-device.
///
/// Sebuah kata dihitung menyentuh sel bila minimal [minBagianKata] luas kata
/// itu berada di dalam sel. Menyentuh dua sel atau lebih: masuk ke semuanya
/// dengan [AlasanRagu.kataMelintasiSel]. Menyentuh satu sel tetapi kurang dari
/// [bagianBersih] luasnya di dalam sel itu: ragu dengan
/// [AlasanRagu.kataSebagianDiLuarSel]. Menyentuh nol sel: [HasilPemetaanHalaman
/// .tidakTerpetakan], jadi tinta yang separuh-separuh tidak lenyap.
///
/// [minBagianKata], [bagianBersih], dan [ambangKeyakinan] adalah nilai awal
/// BELUM diukur dari foto nyata; jangan dianggap hasil kalibrasi. Nilai di luar
/// batasnya melempar [ArgumentError] (kesalahan pemrogram, bukan data foto).
HasilPemetaanHalaman? petakanKataKeSel({
  required List<KataHalaman> kata,
  required Map<String, KotakSel> sel,
  required ({int w, int h})? ukuranReferensi,
  double ambangKeyakinan = 0.8,
  double minBagianKata = 0.3,
  double bagianBersih = 0.8,
}) {
  if (!(ambangKeyakinan >= 0 && ambangKeyakinan <= 1) ||
      !(minBagianKata > 0 && minBagianKata <= 1) ||
      !(bagianBersih >= minBagianKata && bagianBersih <= 1)) {
    throw ArgumentError(
      'ambangKeyakinan 0..1, 0 < minBagianKata <= bagianBersih <= 1; '
      'dapat $ambangKeyakinan, $minBagianKata, $bagianBersih',
    );
  }
  if (ukuranReferensi == null ||
      ukuranReferensi.w <= 0 ||
      ukuranReferensi.h <= 0 ||
      sel.isEmpty) {
    return null;
  }

  final lebar = ukuranReferensi.w.toDouble();
  final tinggi = ukuranReferensi.h.toDouble();

  // Sel berukuran nol/negatif tidak bisa menampung kata, tetapi tetap ada di
  // hasil sebagai kosong supaya kunci templat tidak hilang.
  final kotakSel = <String, ({double x0, double y0, double x1, double y1})>{};
  for (final e in sel.entries) {
    final k = e.value;
    if (!(k.w > 0 && k.h > 0)) continue;
    kotakSel[e.key] = (
      x0: k.x / lebar,
      y0: k.y / tinggi,
      x1: (k.x + k.w) / lebar,
      y1: (k.y + k.h) / tinggi,
    );
  }

  final perSel = <String, List<KataHalaman>>{};
  final melintasi = <String>{};
  final sebagianDiLuar = <String>{};
  final tidakTerpetakan = <KataHalaman>[];

  for (final w in kata) {
    final luas = (w.x1 - w.x0) * (w.y1 - w.y0);
    final sehat =
        w.teks.trim().isNotEmpty &&
        w.x0.isFinite &&
        w.y0.isFinite &&
        w.x1.isFinite &&
        w.y1.isFinite &&
        // Dua syarat terpisah: kotak terbalik di kedua sumbu menghasilkan luas
        // POSITIF dan lolos kalau cuma luas yang dicek.
        w.x1 > w.x0 &&
        w.y1 > w.y0 &&
        luas > 0;
    if (!sehat) {
      tidakTerpetakan.add(w);
      continue;
    }

    final milik = <String>[];
    var bagianTunggal = 0.0;
    for (final e in kotakSel.entries) {
      final b = e.value;
      final dx = (w.x1 < b.x1 ? w.x1 : b.x1) - (w.x0 > b.x0 ? w.x0 : b.x0);
      final dy = (w.y1 < b.y1 ? w.y1 : b.y1) - (w.y0 > b.y0 ? w.y0 : b.y0);
      if (dx <= 0 || dy <= 0) continue;
      final bagian = dx * dy / luas;
      // Toleransi wajib: kata yang persis 50/50 di perbatasan dua sel bisa
      // menghasilkan 0,49999999999999983 di satu sisi dan 0,5000000000000001
      // di sisi lain, dan tanpa toleransi sel kedua "menang" sebagai usulan
      // bersih sementara sel pertama kosong.
      if (bagian + _toleransi >= minBagianKata) {
        milik.add(e.key);
        bagianTunggal = bagian;
      }
    }

    if (milik.isEmpty) {
      tidakTerpetakan.add(w);
      continue;
    }
    if (milik.length > 1) {
      melintasi.addAll(milik);
    } else if (bagianTunggal + _toleransi < bagianBersih) {
      // Sebagian kata ada di luar sel itu (di luar sel mana pun, atau sedikit
      // di sel tetangga): penempatannya meragukan walau hanya satu sel yang lolos.
      sebagianDiLuar.add(milik.single);
    }
    for (final kunci in milik) {
      (perSel[kunci] ??= <KataHalaman>[]).add(w);
    }
  }

  final hasil = <String, HasilSelPetaan>{};
  for (final kunci in sel.keys) {
    final isi = perSel[kunci];
    if (isi == null || isi.isEmpty) {
      hasil[kunci] = HasilSelPetaan(
        kunci: kunci,
        teksMentah: null,
        status: StatusSelPetaan.kosong,
        alasan: const {},
        kata: const [],
      );
      continue;
    }

    // Sel tabel satu baris: urut dari kiri, lalu dari atas. Lebih dari satu
    // kata sudah ditandai ragu, jadi urutan ini hanya soal keterbacaan.
    final urut = [...isi]
      ..sort((a, b) {
        final c = a.x0.compareTo(b.x0);
        return c != 0 ? c : a.y0.compareTo(b.y0);
      });

    final alasan = <AlasanRagu>{};
    if (urut.length > 1) alasan.add(AlasanRagu.lebihDariSatuKata);
    if (melintasi.contains(kunci)) alasan.add(AlasanRagu.kataMelintasiSel);
    if (sebagianDiLuar.contains(kunci)) {
      alasan.add(AlasanRagu.kataSebagianDiLuarSel);
    }
    for (final k in urut) {
      final y = k.keyakinan;
      // Keyakinan di luar 0..1 (mis. 95 atau 1,5) berarti kontraknya salah
      // dibaca; tidak boleh lolos sebagai "yakin".
      if (y == null || !y.isFinite || y < 0 || y > 1) {
        alasan.add(AlasanRagu.keyakinanTidakAda);
      } else if (y < ambangKeyakinan) {
        alasan.add(AlasanRagu.keyakinanRendah);
      }
    }

    hasil[kunci] = HasilSelPetaan(
      kunci: kunci,
      teksMentah: urut.map((k) => k.teks).join(' '),
      status: alasan.isEmpty ? StatusSelPetaan.usulan : StatusSelPetaan.ragu,
      alasan: alasan,
      kata: urut,
    );
  }

  return HasilPemetaanHalaman(sel: hasil, tidakTerpetakan: tidakTerpetakan);
}
