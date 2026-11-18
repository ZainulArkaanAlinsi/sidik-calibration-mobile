/// Model keanggotaan pelanggan di sisi LAB — `GET /api/customers/{customer}/anggota`
/// (kontrak `docs/perintah-frontend-super-admin.md` §3.2).
///
/// Semua `fromJson` di berkas ini sengaja TAHAN kunci yang hilang (kontrak
/// menyebut `orang`, `dinonaktifkan_oleh`, dan `pic_admin` bisa `null`), tapi
/// TIDAK menelan baris cacat: baris tanpa `id` melempar, supaya layar
/// menampilkan galat, bukan daftar yang diam-diam kurang satu orang.
library;

DateTime? _tanggal(Object? nilai) =>
    nilai is String ? DateTime.tryParse(nilai)?.toLocal() : null;

String? _teksAtauNull(Object? nilai) =>
    nilai is String && nilai.trim().isNotEmpty ? nilai : null;

int _angka(Object? nilai) => (nilai as num).toInt();

/// Orang lab singkat — `pic_admin`, `dinonaktifkan_oleh`, `diundang_oleh`.
class OrangLab {
  const OrangLab({required this.id, required this.nama, this.email});

  final int id;
  final String nama;
  final String? email;

  static OrangLab? dari(Object? json) {
    if (json is! Map) return null;
    return OrangLab(
      id: _angka(json['id']),
      nama: _teksAtauNull(json['nama']) ?? '',
      email: _teksAtauNull(json['email']),
    );
  }
}

/// Orang di sisi pelanggan (`anggota[].orang`). Bisa `null` di baris kalau
/// akun orangnya sudah tidak ada.
class OrangPelanggan {
  const OrangPelanggan({
    required this.id,
    required this.nama,
    required this.email,
    this.telepon,
    this.jabatan,
  });

  final int id;
  final String nama;
  final String email;
  final String? telepon;
  final String? jabatan;

  static OrangPelanggan? dari(Object? json) {
    if (json is! Map) return null;
    return OrangPelanggan(
      id: _angka(json['id']),
      nama: _teksAtauNull(json['nama']) ?? '',
      email: _teksAtauNull(json['email']) ?? '',
      telepon: _teksAtauNull(json['telepon']),
      jabatan: _teksAtauNull(json['jabatan']),
    );
  }
}

/// Peran anggota. Nilai asing dari server tetap terbawa di [mentah] dan
/// diperlakukan sebagai `staf` untuk label (peran yang paling sempit).
enum PeranAnggota {
  picUtama('pic_utama'),
  staf('staf');

  const PeranAnggota(this.kode);

  final String kode;

  static PeranAnggota dari(String? kode) =>
      kode == 'pic_utama' ? PeranAnggota.picUtama : PeranAnggota.staf;
}

class AnggotaPelanggan {
  const AnggotaPelanggan({
    required this.id,
    required this.peran,
    required this.aktif,
    required this.picUtamaTerakhir,
    required this.bisaDicabut,
    this.bergabungPada,
    this.dinonaktifkanPada,
    this.dinonaktifkanOleh,
    this.orang,
  });

  final int id;
  final PeranAnggota peran;

  /// `status == "aktif"`. Selain itu (`nonaktif`, nilai baru) dianggap tidak
  /// aktif: akses anggota tidak boleh tampak hidup karena label tak dikenal.
  final bool aktif;
  final DateTime? bergabungPada;
  final DateTime? dinonaktifkanPada;
  final OrangLab? dinonaktifkanOleh;

  /// Satu-satunya `pic_utama` aktif. Dari server — layar TIDAK menghitungnya.
  final bool picUtamaTerakhir;

  /// Dari server (`aktif` dan bukan PIC utama terakhir). Hanya untuk
  /// memperjelas UI; server tetap menolak walau tombol sempat tampil.
  final bool bisaDicabut;
  final OrangPelanggan? orang;

  factory AnggotaPelanggan.fromJson(Map<String, dynamic> json) {
    return AnggotaPelanggan(
      id: _angka(json['id']),
      peran: PeranAnggota.dari(json['peran'] as String?),
      aktif: json['status'] == 'aktif',
      bergabungPada: _tanggal(json['bergabung_pada']),
      dinonaktifkanPada: _tanggal(json['dinonaktifkan_pada']),
      dinonaktifkanOleh: OrangLab.dari(json['dinonaktifkan_oleh']),
      picUtamaTerakhir: json['pic_utama_terakhir'] == true,
      bisaDicabut: json['bisa_dicabut'] == true,
      orang: OrangPelanggan.dari(json['orang']),
    );
  }
}

/// Undangan yang belum dipakai, belum dibatalkan, belum kedaluwarsa. KODE
/// tidak pernah ada di sini (server hanya menyimpan hash).
class UndanganMenunggu {
  const UndanganMenunggu({
    required this.id,
    required this.email,
    required this.peran,
    this.kedaluwarsaPada,
    this.dibuatPada,
    this.diundangOleh,
  });

  final int id;
  final String email;
  final PeranAnggota peran;
  final DateTime? kedaluwarsaPada;
  final DateTime? dibuatPada;
  final OrangLab? diundangOleh;

  factory UndanganMenunggu.fromJson(Map<String, dynamic> json) {
    return UndanganMenunggu(
      id: _angka(json['id']),
      email: _teksAtauNull(json['email']) ?? '',
      peran: PeranAnggota.dari(json['peran'] as String?),
      kedaluwarsaPada: _tanggal(json['kedaluwarsa_pada']),
      dibuatPada: _tanggal(json['dibuat_pada']),
      diundangOleh: OrangLab.dari(json['diundang_oleh']),
    );
  }
}

/// Isi `data` dari `GET /customers/{customer}/anggota`.
class DataAnggotaPelanggan {
  const DataAnggotaPelanggan({
    required this.customerId,
    required this.customerNama,
    required this.maksAnggota,
    required this.jumlahAktif,
    required this.anggota,
    required this.undanganMenunggu,
    this.picAdmin,
  });

  final int customerId;
  final String customerNama;
  final int maksAnggota;
  final int jumlahAktif;
  final OrangLab? picAdmin;
  final List<AnggotaPelanggan> anggota;
  final List<UndanganMenunggu> undanganMenunggu;

  factory DataAnggotaPelanggan.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final customer = data['customer'];
    final c = customer is Map ? customer : const {};

    List<T> daftar<T>(Object? nilai, T Function(Map<String, dynamic>) buat) {
      if (nilai is! List) return const [];
      return [
        for (final e in nilai)
          if (e is Map) buat(Map<String, dynamic>.from(e)),
      ];
    }

    return DataAnggotaPelanggan(
      customerId: _angka(c['id']),
      customerNama: _teksAtauNull(c['nama']) ?? '',
      maksAnggota: (data['maks_anggota'] as num?)?.toInt() ?? 0,
      jumlahAktif: (data['jumlah_aktif'] as num?)?.toInt() ?? 0,
      picAdmin: OrangLab.dari(data['pic_admin']),
      anggota: daftar(data['anggota'], AnggotaPelanggan.fromJson),
      undanganMenunggu: daftar(
        data['undangan_menunggu'],
        UndanganMenunggu.fromJson,
      ),
    );
  }
}
