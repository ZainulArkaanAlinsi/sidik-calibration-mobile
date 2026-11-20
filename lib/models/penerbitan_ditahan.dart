/// Penahanan penerbitan sertifikat per jenis alat — menunggu keputusan
/// Technical Manager (TM). Kontrak: `docs/perintah-frontend-tahan-profil.md`
/// di repo API (PR #280, live 18 Nov 2026).
///
/// Ada di TIGA tempat, bentuknya sama:
///  - `data.penerbitan_ditahan` di respons sesi (`GET /calibrations/{id}`),
///  - tiap baris `kemampuan[]` di `GET /categories/{kode}` (belum dibaca app),
///  - badan `422 profil_ditahan` waktu approve ditolak.
///
/// Yang ditahan CUMA penerbitan: mengisi, pratinjau, simpan, dan hitung tetap
/// jalan. App TIDAK memutuskan apa pun di sini — daftar jenis alat, alasan, dan
/// rujukan TM semuanya dari server (aturan 0.1 kontrak): jangan menyalin daftar
/// tujuh jenis alat ke aplikasi, daftar itu berubah satu per satu begitu TM
/// menjawab tanpa rilis aplikasi.
class PenerbitanDitahan {
  const PenerbitanDitahan({
    this.ditahan = false,
    this.alasan,
    this.rujukanTm,
    this.varian = const [],
  });

  /// Tidak ditahan. Juga jawaban untuk kunci yang tidak ada (server lama):
  /// aturan 5 kontrak, "kunci yang tidak ada di respons = tidak ditahan".
  static const tidak = PenerbitanDitahan();

  /// `true` = `POST /calibrations/{id}/approve` akan dijawab `422
  /// profil_ditahan`. Hanya `true` bool sungguhan yang dihitung — string
  /// `"true"` atau angka 1 dari proxy/versi aneh TIDAK menahan tombol, supaya
  /// tebakan app tidak menggantikan keputusan server.
  final bool ditahan;

  /// Alasan siap tampil, kalimat server apa adanya (boleh panjang, ratusan
  /// karakter). Cabang UI memakai [ditahan] dan `kode`, bukan teks ini.
  final String? alasan;

  /// Nomor pertanyaan TM (`TM-4`, atau `P-1, P-2` untuk Tekanan).
  final String? rujukanTm;

  /// Kosong = seluruh jenis alat. Terisi = HANYA varian itu yang ditahan
  /// (Timbangan: `["kg"]`) — pesan ke pengguna harus menyebut variannya, bukan
  /// menyimpulkan "seluruh Timbangan ditahan".
  ///
  /// Di respons sesi kuncinya tidak ada; di `GET /categories/{kode}` berupa
  /// daftar; di badan `422` bisa berupa satu string. Ketiganya dibaca.
  final List<String> varian;

  /// Alasan yang layak dipajang: `null` bila kosong/spasi saja.
  String? get alasanTampil {
    final a = alasan?.trim() ?? '';
    return a.isEmpty ? null : a;
  }

  String? get rujukanTampil {
    final r = rujukanTm?.trim() ?? '';
    return r.isEmpty ? null : r;
  }

  /// Dari objek `penerbitan_ditahan` (respons sesi / kemampuan kategori).
  /// Apa pun selain peta berisi `ditahan: true` = [tidak].
  factory PenerbitanDitahan.fromJson(Object? json) {
    if (json is! Map) return tidak;
    if (json['ditahan'] != true) return tidak;

    return PenerbitanDitahan(
      ditahan: true,
      alasan: _teks(json['alasan']),
      rujukanTm: _teks(json['rujukan_tm']),
      varian: _daftarVarian(json['varian']),
    );
  }

  /// Dari badan `422 profil_ditahan`: kuncinya datar (`alasan`, `rujukan_tm`,
  /// `varian`) dan penahanan SUDAH pasti `true` — kodenya yang bicara. Dibaca
  /// terpisah dari [fromJson] karena badan itu tidak membawa `ditahan`.
  factory PenerbitanDitahan.dariBadan422(Map<String, dynamic> badan) =>
      PenerbitanDitahan(
        ditahan: true,
        alasan: _teks(badan['alasan']),
        rujukanTm: _teks(badan['rujukan_tm']),
        varian: _daftarVarian(badan['varian']),
      );

  static String? _teks(Object? nilai) =>
      nilai is String && nilai.trim().isNotEmpty ? nilai : null;

  static List<String> _daftarVarian(Object? nilai) => switch (nilai) {
    final String s when s.trim().isNotEmpty => [s.trim()],
    final List l => [
      for (final v in l)
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ],
    _ => const [],
  };
}
