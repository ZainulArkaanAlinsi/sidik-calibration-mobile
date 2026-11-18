/// Pindahkan alat (beserta sertifikatnya) ke PT lain — pratinjau lalu
/// eksekusi (`POST /customers/{customer}/pindahkan-alat`, kontrak
/// `docs/perintah-frontend-super-admin.md` §3.7).
///
/// Semua angka dihitung SERVER. Layar hanya menampilkannya: jumlah alat,
/// sertifikat terdampak, siapa mulai/berhenti melihat. Sertifikat tidak
/// pernah diubah; hanya `equipments.customer_id`.
library;

int _angka(Object? nilai) => nilai is num ? nilai.toInt() : 0;

String _teks(Object? nilai) => nilai is String ? nilai : '';

/// PT di pratinjau (`dari` / `ke`).
class RingkasPt {
  const RingkasPt({
    required this.id,
    required this.nama,
    this.anggotaAktifCount = 0,
  });

  final int id;
  final String nama;
  final int anggotaAktifCount;

  static RingkasPt dari(Object? json) {
    final m = json is Map ? json : const {};
    return RingkasPt(
      id: _angka(m['id']),
      nama: _teks(m['nama']),
      anggotaAktifCount: _angka(m['anggota_aktif_count']),
    );
  }
}

class AlatDipindah {
  const AlatDipindah({
    required this.id,
    required this.nama,
    this.nomorSeri = '',
    this.jumlahSertifikat = 0,
  });

  final int id;
  final String nama;
  final String nomorSeri;
  final int jumlahSertifikat;

  static AlatDipindah dari(Map<String, dynamic> json) => AlatDipindah(
    id: (json['id'] as num).toInt(),
    nama: _teks(json['nama_alat']),
    nomorSeri: _teks(json['serial_number']),
    jumlahSertifikat: _angka(json['jumlah_sertifikat']),
  );
}

/// Anggota PT yang mulai/berhenti melihat alat setelah dipindah.
class OrangTerdampak {
  const OrangTerdampak({
    required this.id,
    required this.nama,
    required this.email,
  });

  final int id;
  final String nama;
  final String email;

  static OrangTerdampak dari(Map<String, dynamic> json) => OrangTerdampak(
    id: _angka(json['id']),
    nama: _teks(json['nama']),
    email: _teks(json['email']),
  );
}

/// Peringatan pratinjau. `kode` stabil (`paket_tidak_dipindah`,
/// `arsip_tidak_dipindah`, `isi_sertifikat_tetap`); `pesan` boleh berubah di
/// server, jadi layar memakai kalimat lokal untuk kode yang dikenal dan
/// `pesan` hanya untuk kode baru.
class PeringatanPindah {
  const PeringatanPindah({required this.kode, required this.pesan});

  final String kode;
  final String pesan;
}

List<T> _daftar<T>(Object? nilai, T Function(Map<String, dynamic>) buat) {
  if (nilai is! List) return const [];
  return [
    for (final e in nilai)
      if (e is Map) buat(Map<String, dynamic>.from(e)),
  ];
}

/// `data` dari respons pratinjau (`dry_run: true`).
class PratinjauPindahAlat {
  const PratinjauPindahAlat({
    required this.dari,
    required this.ke,
    required this.jumlahAlat,
    required this.alat,
    required this.sertifikatTerdampak,
    required this.sertifikatTerlihatPelanggan,
    required this.anggotaMulaiMelihat,
    required this.anggotaBerhentiMelihat,
    required this.paketTerkaitCount,
    required this.peringatan,
  });

  final RingkasPt dari;
  final RingkasPt ke;
  final int jumlahAlat;
  final List<AlatDipindah> alat;

  /// Semua sertifikat dari alat-alat itu, status apa pun.
  final int sertifikatTerdampak;

  /// Yang `terbit` + `dibatalkan` (tampil di aplikasi pelanggan).
  final int sertifikatTerlihatPelanggan;
  final List<OrangTerdampak> anggotaMulaiMelihat;
  final List<OrangTerdampak> anggotaBerhentiMelihat;
  final int paketTerkaitCount;
  final List<PeringatanPindah> peringatan;

  factory PratinjauPindahAlat.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return PratinjauPindahAlat(
      dari: RingkasPt.dari(data['dari']),
      ke: RingkasPt.dari(data['ke']),
      jumlahAlat: _angka(data['jumlah_alat']),
      alat: _daftar(data['alat'], AlatDipindah.dari),
      sertifikatTerdampak: _angka(data['sertifikat_terdampak']),
      sertifikatTerlihatPelanggan: _angka(
        data['sertifikat_terlihat_pelanggan'],
      ),
      anggotaMulaiMelihat: _daftar(
        data['anggota_mulai_melihat'],
        OrangTerdampak.dari,
      ),
      anggotaBerhentiMelihat: _daftar(
        data['anggota_berhenti_melihat'],
        OrangTerdampak.dari,
      ),
      paketTerkaitCount: _angka(data['paket_terkait_count']),
      peringatan: _daftar(
        data['peringatan'],
        (m) =>
            PeringatanPindah(kode: _teks(m['kode']), pesan: _teks(m['pesan'])),
      ),
    );
  }
}

/// `data` dari respons eksekusi.
class HasilPindahAlat {
  const HasilPindahAlat({
    required this.dari,
    required this.ke,
    required this.jumlahAlat,
    required this.sertifikatTerdampak,
    required this.sertifikatTerlihatPelanggan,
  });

  final RingkasPt dari;
  final RingkasPt ke;
  final int jumlahAlat;
  final int sertifikatTerdampak;
  final int sertifikatTerlihatPelanggan;

  factory HasilPindahAlat.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return HasilPindahAlat(
      dari: RingkasPt.dari(data['dari']),
      ke: RingkasPt.dari(data['ke']),
      jumlahAlat: _angka(data['jumlah_alat']),
      sertifikatTerdampak: _angka(data['sertifikat_terdampak']),
      sertifikatTerlihatPelanggan: _angka(
        data['sertifikat_terlihat_pelanggan'],
      ),
    );
  }
}
