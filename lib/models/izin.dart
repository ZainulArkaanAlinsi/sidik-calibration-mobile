import 'user.dart';

/// Matriks peran dari backend (`GET /api/me/permissions`).
///
/// Gunanya: **nyembunyiin tombol yang bakal ditolak**, bukan nampilin tombol
/// lalu user kena `403`. Sebelum ini aturannya di-hardcode di mobile
/// (`role.isAdmin`, `role.bisaInput`), dan tiap backend ganti aturan, mobile
/// ikut basi diam-diam tanpa ada yang sadar.
///
/// Daftarnya dihitung backend dari middleware rute yang beneran terdaftar,
/// jadi kalau aturannya berubah, jawabannya ikut berubah di request
/// berikutnya.
///
/// ## Kenapa ada [bolehkah] dengan `cadangan`, bukan langsung baca `boleh`
///
/// Bentuk respons endpoint ini **belum ditulis pasti** di `kontrak-api.md`.
/// Dokumen permintaan (fase 2) nyontohin `boleh` sebagai daftar nama izin
/// bertitik (`"alat.tambah"`), sementara handoff 28 Juli bilang daftarnya
/// dihitung dari **rute**, plus ada field `batasan` yang nggak ada di contoh
/// awal. Dua-duanya mungkin.
///
/// Jadi kalau sebuah izin **nggak dikenali** — entah karena namanya beda,
/// endpoint-nya belum nyala, atau requestnya gagal — [bolehkah] jatuh balik ke
/// aturan peran yang lama. Efeknya: paling buruk perilakunya sama kayak
/// sebelum PR ini, bukan tombol yang ilang semua atau muncul semua.
class Izin {
  const Izin({
    required this.role,
    required this.boleh,
    this.batasan = const {},
  });

  /// Belum tau apa-apa — semua pertanyaan dijawab pakai cadangan.
  static const kosong = Izin(role: null, boleh: {});

  /// Role menurut backend. Bisa beda dari yang disimpen mobile kalau admin
  /// baru saja mengubahnya.
  final UserRole? role;

  /// Izin yang dinyatakan backend. Kosong = backend belum ngasih tau apa-apa.
  final Set<String> boleh;

  /// "Isinya sebanyak apa" — beda dari [boleh] yang cuma jawab "kebuka apa
  /// nggak". Contoh: teknisi boleh buka Riwayat, tapi `batasan` bilang dia
  /// cuma lihat sesi miliknya sendiri.
  ///
  /// Tanpa ini, mobile nggak bisa bedain tombol yang disembunyiin dari layar
  /// yang kebuka tapi datanya lebih sedikit — dan itu dua hal beda.
  final Map<String, dynamic> batasan;

  bool get adaJawaban => boleh.isNotEmpty;

  /// [cadangan] = aturan peran lama yang dipakai kalau backend belum
  /// ngejawab soal izin ini. **Wajib diisi**, biar nggak ada pemanggil yang
  /// diam-diam nganggep "nggak dikenal" = "nggak boleh".
  bool bolehkah(String izin, {required bool cadangan}) {
    if (!adaJawaban) return cadangan;
    if (boleh.contains(izin)) return true;

    // Backend udah jawab, tapi nggak nyebut izin ini. Bisa berarti "nggak
    // boleh", bisa juga berarti nama izinnya beda dari tebakan mobile —
    // dan kita belum bisa bedain. Cadangannya dipakai, dan itu disengaja:
    // nyembunyiin tombol yang sebenarnya boleh lebih ngerepotin daripada
    // nampilin tombol yang nanti ditolak 403 dengan pesan jelas.
    return cadangan;
  }

  /// Batasan bernama, mis. `batasan['kalibrasi'] == 'sendiri'`.
  String? batasanUntuk(String kunci) {
    final nilai = batasan[kunci];
    return nilai == null ? null : '$nilai';
  }

  factory Izin.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return Izin(
      role: switch (data['role']) {
        final String s => UserRole.fromApi(s),
        _ => null,
      },
      boleh: _bacaBoleh(data['boleh']),
      batasan: switch (data['batasan']) {
        final Map<String, dynamic> m => m,
        final Map m => Map<String, dynamic>.from(m),
        _ => const {},
      },
    );
  }

  /// Dua bentuk diterima, karena belum pasti backend ngirim yang mana:
  ///
  /// - daftar: `["alat.lihat", "alat.tambah"]`
  /// - peta  : `{"alat.lihat": true, "alat.hapus": false}`
  static Set<String> _bacaBoleh(dynamic nilai) {
    if (nilai is List) {
      return nilai.map((e) => '$e').where((e) => e.isNotEmpty).toSet();
    }
    if (nilai is Map) {
      return nilai.entries
          .where((e) => e.value == true)
          .map((e) => '${e.key}')
          .toSet();
    }
    return const {};
  }
}

/// Nama izin yang dipakai mobile.
///
/// **Ini tebakan sampai bentuk pastinya dikonfirmasi** — diambil dari contoh
/// di `docs/permintaan-endpoint-fase-2.md`. Kalau backend pakai nama lain,
/// [Izin.bolehkah] jatuh ke cadangan dan perilakunya sama kayak sebelum
/// matriks peran dipasang, bukan rusak.
abstract final class NamaIzin {
  static const alatTambah = 'alat.tambah';
  static const alatUbah = 'alat.ubah';
  static const alatHapus = 'alat.hapus';

  static const kalibrasiBuat = 'kalibrasi.buat';
  static const kalibrasiSetujui = 'kalibrasi.setujui';

  static const masterDataUbah = 'master-data.ubah';
  static const akunKelola = 'akun.kelola';
  static const sertifikatKirim = 'sertifikat.kirim';
  static const tandaTanganKelola = 'tanda-tangan.kelola';
  static const folderTulis = 'folder.tulis';
}
