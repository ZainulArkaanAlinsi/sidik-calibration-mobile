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

  // Keempat nama di bawah SEBELUMNYA ditebak (`master-data.ubah`,
  // `akun.kelola`, `folder.tulis`) dan nggak pernah ada di `MatriksIzin::PETA`
  // punya server. Akibatnya nggak keliatan di mana-mana: `bolehkah` jatuh ke
  // cadangan aturan peran hardcode buat nama yang nggak dikenal, jadi
  // tombolnya tetap jalan — cuma pakai aturan yang matriks peran ini ada buat
  // menggantikannya. Lima dari sebelas nama mati begitu.
  //
  // Sekarang disamain sama nama di server, dan dijaga dua arah:
  // `MeIzinTest::test_nama_izin_yang_ditanya_mobile_ada_semua` di repo API, dan
  // `test/nama_izin_test.dart` di sini.
  static const standarKelola = 'standar.kelola';
  static const penggunaKelola = 'pengguna.kelola';
  static const sertifikatKirim = 'sertifikat.kirim';
  static const tandaTanganKelola = 'tanda-tangan.kelola';
  static const arsipFolderKelola = 'arsip.folder.kelola';

  // Satu izin per MENU, bukan satu payung buat empat menu.
  //
  // Nama lama `master-data.ubah` itu payung yang nggak pernah ada di server,
  // jadi dia SELALU jatuh ke cadangan `role.isAdmin` — dan selama jawabannya
  // selalu "admin doang", payung sama izin-per-menu kelihatan sama saja.
  //
  // Begitu namanya disamain jadi `standar.kelola`, payungnya berubah jadi
  // JAWABAN NYATA dari server, dan artinya nggak lagi sama: satu rute pindah
  // blok — `POST /standards` keluar dari `role:admin`, persis jenis perubahan
  // yang MatriksIzin ada buat nyebarinnya otomatis — bikin teknisi kebagian
  // `standar.kelola`, lalu menu Pelanggan, Impor Excel, dan Organisasi ikut
  // nyala di sidebar-nya. Ketiganya tetap admin-only di server, jadi yang dia
  // dapat 403 begitu diketuk. Itu persis kegagalan yang matriks peran ini ada
  // buat mencegahnya, cuma sekarang sumbernya nama yang salah pasang.
  static const pelangganKelola = 'pelanggan.kelola';

  // Ruangan & Metode digerbangi izin BACA, bukan kelola: menunya membuka layar
  // DAFTAR, dan `GET api/rooms` / `GET api/calibration-methods` memang terbuka
  // buat teknisi & viewer. Tombol tulis di dalamnya punya penjaganya sendiri
  // (`role.isAdmin` di kedua layar), jadi menggerbangi menunya dengan
  // `*.kelola` cuma menyembunyikan layar baca yang sah — bukan tombol yang
  // bakal 403.
  static const ruanganLihat = 'ruangan.lihat';
  static const metodeLihat = 'metode.lihat';
  static const teknisiKelola = 'teknisi.kelola';
  static const imporExcel = 'impor.excel';
  static const organisasiUbah = 'organisasi.ubah';
}
