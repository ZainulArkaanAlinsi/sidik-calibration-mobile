/// Hasil `POST /api/imports/excel` (spesifikasi poin 12C).
///
/// Alurnya **dua langkah, dan itu disengaja**: unggah dengan `uji_coba`
/// (default) → admin baca ringkasannya → kirim ulang dengan `uji_coba: false`
/// kalau sudah cocok. Satu tombol yang langsung nulis ke database dari file
/// Excel orang lain itu cara paling cepat ngerusak master data.
library;

/// Apa yang terjadi ke satu baris file.
import '../core/utils/parse_list.dart';

enum TindakanImport {
  dibuat,
  diperbarui,
  dilewati;

  static TindakanImport fromApi(String? value) => switch (value) {
    'dibuat' => TindakanImport.dibuat,
    'diperbarui' => TindakanImport.diperbarui,
    _ => TindakanImport.dilewati,
  };
}

class BarisImport {
  const BarisImport({
    required this.baris,
    required this.tindakan,
    this.nama,
    this.alasan,
  });

  /// Nomor baris di file Excel-nya — biar admin tau persis mana yang harus
  /// dibenerin, bukan nyari-nyari sendiri.
  final int baris;

  final TindakanImport tindakan;
  final String? nama;

  /// Cuma keisi buat yang `dilewati` — kenapa dilewati.
  final String? alasan;

  factory BarisImport.fromJson(Map<String, dynamic> json) => BarisImport(
    baris: (json['baris'] as num?)?.toInt() ?? 0,
    tindakan: TindakanImport.fromApi(json['tindakan'] as String?),
    nama: json['nama'] as String?,
    alasan: json['alasan'] as String?,
  );
}

class HasilImport {
  const HasilImport({
    required this.tipe,
    required this.ujiCoba,
    required this.ringkasan,
    required this.baris,
    required this.kolomTerpetakan,
    required this.kolomDiabaikan,
    this.pesan,
  });

  /// `customers` / `standards` / `equipments`.
  final String tipe;

  /// `true` = belum ada yang disimpan.
  final bool ujiCoba;

  /// `dibaca` / `dibuat` / `diperbarui` / `dilewati`.
  final Map<String, int> ringkasan;

  final List<BarisImport> baris;

  /// Header Excel yang berhasil dicocokkan ke kolom database.
  final Map<String, String> kolomTerpetakan;

  /// Header yang nggak dikenal — **diabaikan, nggak bikin import gagal**.
  /// Ditampilin biar admin sadar kolomnya nggak kebaca, bukan diam-diam hilang.
  final List<String> kolomDiabaikan;

  final String? pesan;

  int get dibaca => ringkasan['dibaca'] ?? 0;
  int get dibuat => ringkasan['dibuat'] ?? 0;
  int get diperbarui => ringkasan['diperbarui'] ?? 0;
  int get dilewati => ringkasan['dilewati'] ?? 0;

  /// Ada yang bakal beneran berubah? Kalau nol, nerapin nggak ada gunanya.
  bool get adaPerubahan => dibuat > 0 || diperbarui > 0;

  factory HasilImport.fromJson(
    Map<String, dynamic> json, {
    String? pesan,
  }) {
    final ringkasan = json['ringkasan'] as Map<String, dynamic>? ?? const {};

    return HasilImport(
      tipe: json['tipe'] as String? ?? '',
      ujiCoba: json['uji_coba'] as bool? ?? true,
      pesan: pesan,
      ringkasan: {
        for (final e in ringkasan.entries)
          e.key: (e.value as num?)?.toInt() ?? 0,
      },
      baris: parseListAman((json['baris'] as List<dynamic>? ?? const []), BarisImport.fromJson),
      kolomTerpetakan: {
        for (final e
            in (json['kolom_terpetakan'] as Map<String, dynamic>? ?? const {})
                .entries)
          e.key: '${e.value}',
      },
      kolomDiabaikan: (json['kolom_diabaikan'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}
