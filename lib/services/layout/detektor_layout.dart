import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Satu wilayah hasil deteksi tata letak (PP-DocLayout): `Table`, `Text`,
/// `Title`, `Header`, `Footer`, dst. Koordinat dalam piksel foto yang
/// dikirim ke detektor.
class WilayahLayout {
  const WilayahLayout({
    required this.kelas,
    required this.skor,
    required this.kotak,
  });

  final String kelas;
  final double skor;
  final Rect kotak;

  bool get tabel => kelas.toLowerCase() == 'table';
}

class HasilLayout {
  const HasilLayout({
    required this.wilayah,
    required this.lebar,
    required this.tinggi,
    required this.durasiMs,
  });

  final List<WilayahLayout> wilayah;
  final int lebar;
  final int tinggi;
  final int durasiMs;

  List<WilayahLayout> get tabel => [
    for (final w in wilayah)
      if (w.tabel) w,
  ];

  int get jumlahTabel => tabel.length;
}

/// Tahap yang sedang dikerjakan detektor — untuk layar pemuatan.
enum TahapLayout { menyiapkanModel, mengunduhModel, memeriksaModel, mendeteksi }

/// Laporan kemajuan. [bagian] 0..1 hanya bermakna untuk
/// [TahapLayout.mengunduhModel]; tahap lain `null` (tak tentu).
typedef KemajuanLayout = void Function(TahapLayout tahap, double? bagian);

/// Sebab layout detection tidak bisa jalan. Pemanggil menawarkan "muat ulang"
/// atau "lanjut tanpa layout"; pembacaan sel TIDAK bergantung padanya.
enum SebabLayoutGagal {
  /// Platform bukan Android (Windows/iOS/web): dilewati tanpa pesan galat.
  platformTakDidukung,

  /// Unduhan model gagal setelah coba ulang (jaringan/server).
  unduhGagal,

  /// Berkas model terunduh tetapi sha256-nya tidak cocok dengan yang dikunci
  /// di kode. Berkas dibuang; bukan galat jaringan.
  modelRusak,

  /// Pengguna menolak mengunduh lewat data seluler.
  unduhDitolak,

  /// Native/ONNX gagal memuat atau mendeteksi.
  deteksiGagal,
}

class LayoutGagal implements Exception {
  const LayoutGagal(this.sebab, [this.rincian]);

  final SebabLayoutGagal sebab;
  final String? rincian;

  @override
  String toString() =>
      'LayoutGagal(${sebab.name}${rincian == null ? '' : ': $rincian'})';
}

/// Antarmuka detektor tata letak. Implementasi nyata (`DetektorLayoutOcrKit`)
/// hanya Android; sisanya memakai [DetektorLayoutTakTersedia].
///
/// Foto TIDAK PERNAH keluar dari perangkat lewat antarmuka ini: sumbernya
/// byte di memori yang ditulis sementara ke direktori cache aplikasi lalu
/// dihapus.
abstract interface class DetektorLayout {
  /// Apakah detektor bisa dipakai di platform ini (bukan: modelnya sudah
  /// terunduh).
  bool get tersedia;

  /// Menyiapkan model (unduh bila perlu). [izinUnduh] ditanya sekali sebelum
  /// unduhan dimulai. Melempar [LayoutGagal].
  Future<void> siapkan({
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  });

  /// Mendeteksi tata letak (menyiapkan model dulu bila belum). Melempar
  /// [LayoutGagal].
  Future<HasilLayout> deteksi(
    Uint8List jpeg, {
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  });
}

/// Platform tanpa layout detection (Windows, iOS, web, test): `tersedia`
/// false, jadi alur pindai langsung memakai jalur ML Kit yang ada.
class DetektorLayoutTakTersedia implements DetektorLayout {
  const DetektorLayoutTakTersedia();

  @override
  bool get tersedia => false;

  @override
  Future<void> siapkan({
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) => Future.error(const LayoutGagal(SebabLayoutGagal.platformTakDidukung));

  @override
  Future<HasilLayout> deteksi(
    Uint8List jpeg, {
    KemajuanLayout? kemajuan,
    Future<bool> Function()? izinUnduh,
  }) => Future.error(const LayoutGagal(SebabLayoutGagal.platformTakDidukung));
}

/// Petunjuk dari hasil deteksi untuk teknisi. HANYA petunjuk: tidak mengubah
/// vonis sel, tidak mengisi apa pun, dan tidak menghentikan pembacaan.
enum PeringatanLayout {
  /// Tidak ada wilayah `Table` di foto.
  tabelTakTerdeteksi,

  /// Ada tabel yang menyentuh tepi foto (kemungkinan terpotong).
  tabelTerpotong,
}

/// Menurunkan [PeringatanLayout] dari [hasil]. `null` (layout dilewati atau
/// gagal) -> tanpa petunjuk. Margin tepi = 1% sisi pendek foto.
///
/// Akurasi deteksi Tabel pada foto lapangan BELUM terukur (belum ada foto
/// nyata); karena itu keluarannya cuma petunjuk, bukan gerbang.
List<PeringatanLayout> peringatanDariLayout(HasilLayout? hasil) {
  if (hasil == null) return const [];
  if (hasil.jumlahTabel == 0) {
    return const [PeringatanLayout.tabelTakTerdeteksi];
  }

  final sisiPendek = hasil.lebar < hasil.tinggi ? hasil.lebar : hasil.tinggi;
  final margin = sisiPendek * 0.01;

  final terpotong = hasil.tabel.any(
    (t) =>
        t.kotak.left <= margin ||
        t.kotak.top <= margin ||
        t.kotak.right >= hasil.lebar - margin ||
        t.kotak.bottom >= hasil.tinggi - margin,
  );

  return terpotong ? const [PeringatanLayout.tabelTerpotong] : const [];
}
