/// Revisi & pembatalan sertifikat (sisi LAB, kontrak A1–A3 di
/// `docs/perintah-frontend-revisi-koreksi.md` repo API).
///
/// Semua parser di sini **defensif**: server lama tidak mengirim satu pun field
/// baru, jadi yang hilang jatuh ke bawaan yang aman (`berlaku`, tanpa tombol),
/// bukan melempar.
library;

/// Label dokumen yang ditampilkan di samping `status` teknis sertifikat.
///
/// `status` (terbit / menunggu_generate / gagal / dibatalkan) menjawab "sudah
/// jadi atau belum"; [StatusDokumen] menjawab "masih sah atau tidak".
enum StatusDokumen {
  berlaku('berlaku'),
  digantikan('digantikan'),
  dibatalkan('dibatalkan'),
  belumTerbit('belum_terbit');

  const StatusDokumen(this.kode);

  final String kode;

  /// Kode asing / kosong (server lama) → `null`, supaya pemanggil bisa jatuh ke
  /// turunan dari `status` teknis.
  static StatusDokumen? dariApi(String? kode) {
    for (final s in values) {
      if (s.kode == kode) return s;
    }
    return null;
  }
}

/// Rujukan ke sertifikat lain: pendahulu (`revisi_dari`), pengganti
/// (`digantikan_oleh`), atau sumber jadwal (`jatuh_ke`).
class RujukanSertifikat {
  const RujukanSertifikat({
    required this.id,
    required this.nomor,
    this.status,
    this.berlakuSampai,
  });

  final int id;
  final String nomor;

  /// Hanya ada di `digantikan_oleh`: status teknis revisi (mis. masih
  /// `menunggu_generate`).
  final String? status;

  /// Hanya ada di `jatuh_ke`: `YYYY-MM-DD`.
  final String? berlakuSampai;

  /// Revisinya sendiri masih dirender di antrean.
  bool get masihDiproses => status == 'menunggu_generate';

  static RujukanSertifikat? dariJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! num) return null;
    return RujukanSertifikat(
      id: id.toInt(),
      nomor: raw['nomor'] as String? ?? '—',
      status: raw['status'] as String?,
      berlakuSampai: raw['berlaku_sampai'] as String?,
    );
  }
}

/// Delapan kunci yang boleh dikoreksi (urutannya = urutan formulir revisi).
abstract final class KunciDataCetak {
  static const pemilik = 'pemilik';
  static const alamat = 'alamat';
  static const merk = 'merk';
  static const tipe = 'tipe';
  static const nomorSeri = 'nomor_seri';
  static const lokasiKalibrasi = 'lokasi_kalibrasi';
  static const tanggalKalibrasi = 'tanggal_kalibrasi';
  static const berlakuSampai = 'berlaku_sampai';

  static const semua = [
    pemilik,
    alamat,
    merk,
    tipe,
    nomorSeri,
    lokasiKalibrasi,
    tanggalKalibrasi,
    berlakuSampai,
  ];

  /// Dua kunci bertanggal polos `YYYY-MM-DD`.
  static const tanggal = {tanggalKalibrasi, berlakuSampai};
}

/// Nilai yang TERCETAK di sertifikat (dari snapshot) — isian awal formulir
/// revisi. Dibaca per kunci; kunci yang hilang = string kosong.
class DataCetak {
  const DataCetak(this.nilai);

  final Map<String, String> nilai;

  String operator [](String kunci) => nilai[kunci] ?? '';

  static DataCetak? dariJson(Object? raw) {
    if (raw is! Map) return null;
    return DataCetak({
      for (final k in KunciDataCetak.semua)
        if (raw[k] != null) k: '${raw[k]}',
    });
  }
}

/// `dampak_pembatalan` — hanya di detail, hanya kalau `bisa_dibatalkan`.
class DampakPembatalan {
  const DampakPembatalan({this.jadwalDikosongkan = false, this.jatuhKe});

  /// Satu-satunya sertifikat sah alat ini: jadwal kalibrasi ulangnya dikosongkan.
  final bool jadwalDikosongkan;

  /// Sertifikat sah sebelumnya yang jadi sumber jadwal alat.
  final RujukanSertifikat? jatuhKe;

  static DampakPembatalan? dariJson(Object? raw) {
    if (raw is! Map) return null;
    return DampakPembatalan(
      jadwalDikosongkan: raw['jadwal_dikosongkan'] == true,
      jatuhKe: RujukanSertifikat.dariJson(raw['jatuh_ke']),
    );
  }
}

/// 422 dari aksi tulis (revisi, batalkan, terima/tolak koreksi), sudah dipilah
/// per kunci `errors`.
///
/// Dua bentuk yang dibedakan kontrak: galat validasi (`errors` terisi, mis.
/// `perubahan.nomor_seri`) dan galat keadaan (`{message}` saja).
class GalatAksi implements Exception {
  const GalatAksi(this.pesan, {this.errors = const {}});

  final String pesan;
  final Map<String, List<String>> errors;

  /// Pesan pertama untuk [kunci], atau `null`.
  String? untuk(String kunci) {
    final l = errors[kunci];
    return l == null || l.isEmpty ? null : l.first;
  }

  bool get adaGalatIsian => errors.isNotEmpty;

  static GalatAksi dariBody(String pesan, Map<String, dynamic> body) {
    final mentah = body['errors'];
    final hasil = <String, List<String>>{};
    if (mentah is Map) {
      mentah.forEach((k, v) {
        if (v is List) hasil['$k'] = [for (final e in v) '$e'];
        if (v is String) hasil['$k'] = [v];
      });
    }
    return GalatAksi(pesan, errors: hasil);
  }

  @override
  String toString() => pesan;
}
