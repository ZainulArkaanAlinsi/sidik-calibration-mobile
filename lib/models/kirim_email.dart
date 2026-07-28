/// Satu percobaan kirim sertifikat ke email pelanggan.
///
/// **Termasuk yang GAGAL.** Riwayatnya sengaja nyimpen percobaan gagal juga —
/// itu justru yang dicari waktu pelanggan ngaku nggak nerima sertifikatnya.
/// Kalau yang gagal nggak dicatat, nggak ada yang bisa mbuktiin apa-apa.
///
/// > **Catatan bentuk data:** kontrak buat endpoint ini belum ditulis detail
/// > di `kontrak-api.md` — yang ada baru prosa di handoff 28 Juli. Parsingnya
/// > sengaja longgar (beberapa nama kunci diterima, semua opsional kecuali
/// > waktu) sampai bentuk pastinya dikonfirmasi. Lihat `permintaan-backend-*`.
class PercobaanEmail {
  const PercobaanEmail({
    required this.id,
    required this.ke,
    required this.cc,
    required this.berhasil,
    required this.waktu,
    this.error,
    this.oleh,
  });

  final int id;
  final List<String> ke;
  final List<String> cc;

  final bool berhasil;

  /// Pesan kegagalan dari server. Ditampilin apa adanya — admin butuh tau
  /// alasannya ("mailbox penuh" beda penanganan dari "alamat nggak ada").
  final String? error;

  final DateTime waktu;

  /// Siapa admin yang ngirim.
  final String? oleh;

  static List<String> _alamat(dynamic nilai) {
    if (nilai is List) {
      return nilai.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    // Backend bisa aja ngirim satu string dipisah koma, bukan array.
    if (nilai is String) {
      return nilai
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory PercobaanEmail.fromJson(Map<String, dynamic> json) {
    // Nama kunci status belum pasti — terima beberapa kemungkinan, dan
    // anggap GAGAL kalau nggak kebaca. Salah nandain gagal jadi berhasil
    // lebih bahaya: admin ngira udah kekirim padahal belum.
    final status = '${json['status'] ?? ''}'.toLowerCase();
    final error = json['error'] as String? ?? json['pesan_error'] as String?;
    final berhasil = switch (json['berhasil']) {
      final bool b => b,
      _ => status.isNotEmpty
          ? (status == 'terkirim' || status == 'berhasil' || status == 'sukses')
          : (error == null || error.isEmpty),
    };

    final waktu =
        json['dikirim_pada'] ?? json['created_at'] ?? json['waktu'];

    return PercobaanEmail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ke: _alamat(json['ke'] ?? json['to']),
      cc: _alamat(json['cc']),
      berhasil: berhasil,
      error: (error != null && error.isEmpty) ? null : error,
      waktu: DateTime.tryParse('${waktu ?? ''}') ?? DateTime.now(),
      oleh: switch (json['oleh']) {
        final Map<String, dynamic> m => m['nama'] as String?,
        final String s => s,
        _ => null,
      },
    );
  }
}

/// Isi form kirim email.
class KirimEmailPermintaan {
  const KirimEmailPermintaan({required this.ke, this.cc = const []});

  /// Backend batasi **maks 10** alamat masing-masing. Divalidasi di layar juga
  /// biar admin tau sebelum nembak server.
  static const int maksAlamat = 10;

  final List<String> ke;
  final List<String> cc;

  Map<String, dynamic> toJson() => {
    'ke': ke,
    if (cc.isNotEmpty) 'cc': cc,
  };
}
