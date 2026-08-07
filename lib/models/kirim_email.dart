/// Apa yang beneran dikirim ke pelanggan.
///
/// Bukan cuma soal selera: `tautan` NGGAK bawa lampiran sama sekali, jadi dua
/// baris riwayat yang sama-sama "Terkirim" bisa berarti hal yang beda jauh.
/// Makanya formatnya ikut ditampilin di riwayat, bukan cuma dipakai waktu
/// ngirim.
enum FormatKirim {
  /// Dokumen resmi, dilampirkan. Default — dan yang dipakai semua kiriman
  /// sebelum pilihan ini ada.
  pdf('pdf'),

  /// Lembar Excel, dilampirkan. Buat pelanggan yang ngolah datanya lagi.
  xlsx('xlsx'),

  /// Tautan verifikasi doang, tanpa lampiran. Buat kotak masuk yang nolak
  /// lampiran, atau yang cuma perlu mastiin sertifikatnya asli.
  tautan('tautan'),

  /// Dikirim lewat WhatsApp dari HP admin, bukan dari server. Cuma muncul di
  /// RIWAYAT — bukan pilihan waktu ngirim; yang dipilih waktu ngirim itu
  /// salurannya (email/WA) lalu formatnya (pdf/xlsx/tautan).
  whatsapp('whatsapp');

  const FormatKirim(this.kode);

  /// Nilai yang dikirim & diterima backend.
  final String kode;

  /// Yang nggak dikenal jatuh ke [pdf] — bukan error. Riwayat lama (sebelum
  /// kolom `format` ada) balik tanpa field ini, dan semuanya memang PDF.
  static FormatKirim dariKode(Object? nilai) => FormatKirim.values.firstWhere(
    (f) => f.kode == '$nilai'.trim().toLowerCase(),
    orElse: () => FormatKirim.pdf,
  );
}

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
/// Hasil satu percobaan kirim — TIGA keadaan, bukan dua.
///
/// [tidakTerkirim] itu yang gampang kelewat: server nerima permintaannya, nggak
/// ada yang error, tapi emailnya nggak pernah keluar (mailer server masih
/// `log`/`array`). Dulu ini kecatat sama dengan [terkirim], jadi riwayat
/// pengiriman ngaku sertifikatnya udah sampai ke pelanggan padahal nggak.
///
/// Buat lab terakreditasi bedanya penting: riwayat ini yang dijadiin bukti
/// waktu pelanggan bilang nggak nerima.
enum HasilKirim { terkirim, tidakTerkirim, gagal }

class PercobaanEmail {
  const PercobaanEmail({
    required this.id,
    required this.ke,
    required this.cc,
    required this.hasil,
    required this.waktu,
    this.format = FormatKirim.pdf,
    this.error,
    this.oleh,
  });

  final int id;
  final List<String> ke;
  final List<String> cc;

  /// Yang beneran dikirim di percobaan ini.
  final FormatKirim format;

  final HasilKirim hasil;

  /// Beneran nyampe ke penerima. `false` buat [HasilKirim.tidakTerkirim] juga —
  /// dan itu yang bener: nggak ada yang nerima apa pun.
  bool get berhasil => hasil == HasilKirim.terkirim;

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
    // `tidak_terkirim` dicek DULUAN: dia ngandung kata "terkirim", jadi
    // pencocokan longgar di bawah bakal salah baca dia sebagai sukses.
    final hasil = switch (status) {
      'tidak_terkirim' || 'tidak terkirim' || 'belum_terkirim' =>
        HasilKirim.tidakTerkirim,
      _ => switch (json['berhasil']) {
        final bool b => b ? HasilKirim.terkirim : HasilKirim.gagal,
        _ =>
          (status.isNotEmpty
                  ? (status == 'terkirim' ||
                      status == 'berhasil' ||
                      status == 'sukses')
                  : (error == null || error.isEmpty))
              ? HasilKirim.terkirim
              : HasilKirim.gagal,
      },
    };

    final waktu =
        json['dikirim_pada'] ?? json['created_at'] ?? json['waktu'];

    return PercobaanEmail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ke: _alamat(json['ke'] ?? json['to']),
      cc: _alamat(json['cc']),
      format: FormatKirim.dariKode(json['format']),
      hasil: hasil,
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

/// Hasil `POST /certificates/{id}/catat-whatsapp`.
///
/// Server **nggak ngirim apa-apa** — dia nyatet jejaknya lalu ngasih balik teks
/// yang siap ditempel ke WhatsApp. Pesannya disusun di server, bukan di sini:
/// isinya tautan unduh yang nempel ke `qr_token` dan skema URL yang cuma
/// backend yang tahu. Kalau app nyusun sendiri, satu perubahan rute bikin
/// pelanggan nerima tautan mati — dan ketahuannya sesudah pesannya kekirim.
class HasilCatatWhatsapp {
  const HasilCatatWhatsapp({required this.pesan});

  final String pesan;

  factory HasilCatatWhatsapp.fromJson(Map<String, dynamic> json) =>
      HasilCatatWhatsapp(pesan: json['pesan'] as String? ?? '');
}

/// Isi form kirim email.
class KirimEmailPermintaan {
  const KirimEmailPermintaan({
    required this.ke,
    this.cc = const [],
    this.format = FormatKirim.pdf,
  });

  /// Backend batasi **maks 10** alamat masing-masing. Divalidasi di layar juga
  /// biar admin tau sebelum nembak server.
  static const int maksAlamat = 10;

  final List<String> ke;
  final List<String> cc;
  final FormatKirim format;

  Map<String, dynamic> toJson() => {
    'ke': ke,
    if (cc.isNotEmpty) 'cc': cc,
    'format': format.kode,
  };
}
