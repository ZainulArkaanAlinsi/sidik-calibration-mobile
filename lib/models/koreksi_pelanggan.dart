/// Koreksi data yang diajukan pelanggan dari aplikasinya —
/// `GET /api/koreksi-pelanggan` (antrean) & `/{id}` (detail), sisi LAB
/// (kontrak A4 di `docs/perintah-frontend-revisi-koreksi.md` repo API).
///
/// Parser defensif: bentuk yang tak dikenal jatuh ke bawaan aman, bukan
/// melempar — kartunya tetap tampil.
library;

export 'revisi_sertifikat.dart' show GalatAksi;

enum StatusKoreksi {
  menunggu('menunggu'),
  diterima('diterima'),
  ditolak('ditolak'),
  lainnya('');

  const StatusKoreksi(this.kode);

  final String kode;

  static StatusKoreksi dariApi(String? kode) => values.firstWhere(
    (s) => s.kode == kode && s != lainnya,
    orElse: () => lainnya,
  );

  /// Hanya `menunggu` yang bisa diputuskan; sisanya dijawab 422.
  bool get bisaDiputuskan => this == menunggu;
}

enum JenisKoreksi {
  alat('alat'),
  sertifikat('sertifikat');

  const JenisKoreksi(this.kode);

  final String kode;

  static JenisKoreksi dariApi(String? kode) =>
      kode == 'sertifikat' ? sertifikat : alat;
}

/// Satu foto pelat nama (`{id, url}`). Gambarnya ditarik lewat
/// `GET /foto-pelanggan/{id}` dengan header yang sama seperti panggilan API
/// lain, BUKAN dari [url] (bukan tautan publik).
class FotoPelanggan {
  const FotoPelanggan({required this.id, this.url});

  final int id;
  final String? url;

  static FotoPelanggan? dariJson(Object? raw) {
    if (raw is! Map || raw['id'] is! num) return null;
    return FotoPelanggan(
      id: (raw['id'] as num).toInt(),
      url: raw['url'] as String?,
    );
  }

  static List<FotoPelanggan> daftar(Object? raw) => [
    if (raw is List)
      for (final f in raw)
        if (FotoPelanggan.dariJson(f) case final FotoPelanggan x) x,
  ];
}

/// Satu baris perubahan: label siap tampil, nilai lama → nilai yang diminta.
class PerubahanKoreksi {
  const PerubahanKoreksi({
    required this.field,
    required this.label,
    this.lama,
    this.baru,
  });

  final String field;
  final String label;
  final String? lama;
  final String? baru;

  factory PerubahanKoreksi.fromJson(Map<String, dynamic> j) {
    final field = j['field'] as String? ?? '';
    return PerubahanKoreksi(
      field: field,
      label: j['label'] as String? ?? field,
      lama: j['lama'] == null ? null : '${j['lama']}',
      baru: j['baru'] == null ? null : '${j['baru']}',
    );
  }
}

/// Hasil penerbitan revisi sertifikat dari koreksi yang diterima.
class RevisiKoreksi {
  const RevisiKoreksi({required this.id, required this.nomor, this.status});

  final int id;
  final String nomor;
  final String? status;
}

class Koreksi {
  const Koreksi({
    required this.id,
    required this.jenis,
    required this.status,
    this.pelangganId,
    this.pelangganNama,
    this.diajukanOleh,
    this.diajukanPada,
    this.alatId,
    this.alatNama,
    this.alatSerial,
    this.sertifikatId,
    this.sertifikatNomor,
    this.perubahan = const [],
    this.catatan,
    this.foto = const [],
    this.tanggapan,
    this.ditinjauOleh,
    this.ditinjauPada,
    this.revisi,
  });

  final int id;
  final JenisKoreksi jenis;
  final StatusKoreksi status;
  final int? pelangganId;
  final String? pelangganNama;
  final String? diajukanOleh;
  final DateTime? diajukanPada;

  /// Untuk `jenis: sertifikat` berisi alat sertifikat itu.
  final int? alatId;
  final String? alatNama;
  final String? alatSerial;

  /// Hanya untuk `jenis: sertifikat`.
  final int? sertifikatId;
  final String? sertifikatNomor;

  final List<PerubahanKoreksi> perubahan;
  final String? catatan;
  final List<FotoPelanggan> foto;

  /// Dibaca pelanggan apa adanya.
  final String? tanggapan;
  final String? ditinjauOleh;
  final DateTime? ditinjauPada;

  /// Sertifikat pengganti, kalau koreksi sertifikat diterima.
  final RevisiKoreksi? revisi;

  Koreksi salin({
    StatusKoreksi? status,
    String? tanggapan,
    List<PerubahanKoreksi>? perubahan,
    String? ditinjauOleh,
    DateTime? ditinjauPada,
    RevisiKoreksi? revisi,
  }) => Koreksi(
    id: id,
    jenis: jenis,
    status: status ?? this.status,
    pelangganId: pelangganId,
    pelangganNama: pelangganNama,
    diajukanOleh: diajukanOleh,
    diajukanPada: diajukanPada,
    alatId: alatId,
    alatNama: alatNama,
    alatSerial: alatSerial,
    sertifikatId: sertifikatId,
    sertifikatNomor: sertifikatNomor,
    perubahan: perubahan ?? this.perubahan,
    catatan: catatan,
    foto: foto,
    tanggapan: tanggapan ?? this.tanggapan,
    ditinjauOleh: ditinjauOleh ?? this.ditinjauOleh,
    ditinjauPada: ditinjauPada ?? this.ditinjauPada,
    revisi: revisi ?? this.revisi,
  );

  static String? _nama(Object? raw) => switch (raw) {
    final Map m => m['nama'] as String?,
    final String s => s,
    _ => null,
  };

  factory Koreksi.fromJson(Map<String, dynamic> j) {
    final pelanggan = j['pelanggan'];
    final alat = j['alat'];
    final sert = j['sertifikat'];
    final revisi = j['revisi'];

    return Koreksi(
      id: (j['id'] as num).toInt(),
      jenis: JenisKoreksi.dariApi(j['jenis'] as String?),
      status: StatusKoreksi.dariApi(j['status'] as String?),
      pelangganId: pelanggan is Map ? (pelanggan['id'] as num?)?.toInt() : null,
      pelangganNama: _nama(pelanggan),
      diajukanOleh: _nama(j['diajukan_oleh']),
      diajukanPada: DateTime.tryParse(j['diajukan_pada'] as String? ?? ''),
      alatId: alat is Map ? (alat['id'] as num?)?.toInt() : null,
      alatNama: alat is Map ? alat['nama'] as String? : null,
      alatSerial: alat is Map ? alat['serial'] as String? : null,
      sertifikatId: sert is Map ? (sert['id'] as num?)?.toInt() : null,
      sertifikatNomor: sert is Map ? sert['nomor'] as String? : null,
      perubahan: [
        for (final p in (j['perubahan'] as List<dynamic>? ?? const []))
          if (p is Map<String, dynamic>) PerubahanKoreksi.fromJson(p),
      ],
      catatan: j['catatan'] as String?,
      foto: FotoPelanggan.daftar(j['foto']),
      tanggapan: j['tanggapan'] as String?,
      ditinjauOleh: _nama(j['ditinjau_oleh']),
      ditinjauPada: DateTime.tryParse(j['ditinjau_pada'] as String? ?? ''),
      revisi: revisi is Map && revisi['id'] is num
          ? RevisiKoreksi(
              id: (revisi['id'] as num).toInt(),
              nomor: revisi['nomor'] as String? ?? '—',
              status: revisi['status'] as String?,
            )
          : null,
    );
  }
}

/// Satu halaman antrean + angka badge (`meta.jumlah.menunggu`, tidak ikut
/// tersaring oleh tab yang sedang terbuka).
class HalamanKoreksi {
  const HalamanKoreksi({
    required this.items,
    this.total = 0,
    this.jumlahMenunggu = 0,
  });

  final List<Koreksi> items;
  final int total;
  final int jumlahMenunggu;
}

/// Kode status yang dikirim sebagai `?status=`.
abstract final class SaringanKoreksi {
  static const menunggu = 'menunggu';
  static const diterima = 'diterima';
  static const ditolak = 'ditolak';
  static const semua = 'semua';
}
