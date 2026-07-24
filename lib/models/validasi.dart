/// Hasil pemeriksaan ulang sebelum sertifikat terbit
/// (`GET /api/calibrations/{id}/validasi`, spesifikasi poin 11).
///
/// Backend ngitung ULANG semua angka dari pembacaan mentah, terus ngadu sama
/// yang tersimpan. Kalau beda, ada yang berubah di antaranya — data alat
/// diedit, standar diganti, atau barisnya disentuh langsung di DB. Itu justru
/// kasus yang paling nggak mungkin ketahuan dengan dilihat mata.
library;

/// Tiga tingkat, karena nggak semuanya sama beratnya. Tingkat asing dianggap
/// [info] — paling aman: nggak nahan apa-apa dan tetap kelihatan.
import '../core/utils/parse_list.dart';

enum TingkatTemuan {
  /// Sertifikat NGGAK BOLEH terbit. Approve diblokir tanpa syarat.
  error,

  /// Angka hasil hitung ulang beda dari yang tersimpan. Admin boleh lanjut,
  /// tapi harus sadar & eksplisit (`abaikan_peringatan: true`).
  peringatan,

  /// Kolom administratif sertifikat masih kosong. Nggak nahan penerbitan.
  info;

  static TingkatTemuan fromApi(String? value) => switch (value) {
    'error' => TingkatTemuan.error,
    'peringatan' => TingkatTemuan.peringatan,
    _ => TingkatTemuan.info,
  };
}

class Temuan {
  const Temuan({
    required this.tingkat,
    required this.kode,
    required this.pesan,
    this.konteks = const {},
  });

  final TingkatTemuan tingkat;

  /// Kode mesin, mis. `hitung_ulang_beda`. Ditampilin kecil di bawah pesan —
  /// berguna waktu admin lapor ke yang ngurus backend.
  final String kode;

  final String pesan;
  final Map<String, dynamic> konteks;

  factory Temuan.fromJson(Map<String, dynamic> json) => Temuan(
    tingkat: TingkatTemuan.fromApi(json['tingkat'] as String?),
    kode: json['kode'] as String? ?? '',
    pesan: json['pesan'] as String? ?? '',
    konteks: json['konteks'] as Map<String, dynamic>? ?? const {},
  );
}

class HasilValidasi {
  const HasilValidasi({
    required this.valid,
    required this.bolehTerbit,
    required this.temuan,
    required this.ringkasan,
  });

  /// Nggak ada temuan sama sekali di luar `info`.
  final bool valid;

  /// Nggak ada yang fatal. Peringatan masih bisa dilewatin admin secara sadar.
  final bool bolehTerbit;

  final List<Temuan> temuan;

  /// Jumlah per tingkat, langsung dari backend — jangan dihitung ulang di sini.
  final Map<TingkatTemuan, int> ringkasan;

  int jumlah(TingkatTemuan tingkat) => ringkasan[tingkat] ?? 0;

  /// Approve bakal ditolak sekali dengan `butuh_konfirmasi` — layar mesti
  /// siapin dialognya.
  bool get perluKonfirmasi => bolehTerbit && !valid;

  List<Temuan> pada(TingkatTemuan tingkat) =>
      temuan.where((t) => t.tingkat == tingkat).toList();

  factory HasilValidasi.fromJson(Map<String, dynamic> json) {
    final ringkasan = json['ringkasan'] as Map<String, dynamic>? ?? const {};

    return HasilValidasi(
      valid: json['valid'] as bool? ?? false,
      bolehTerbit: json['boleh_terbit'] as bool? ?? false,
      temuan: parseListAman((json['temuan'] as List<dynamic>? ?? const []), Temuan.fromJson),
      ringkasan: {
        for (final t in TingkatTemuan.values)
          t: (ringkasan[t.name] as num?)?.toInt() ?? 0,
      },
    );
  }
}
