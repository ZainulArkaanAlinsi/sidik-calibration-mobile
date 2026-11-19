/// Kalimat untuk teknisi waktu server MENOLAK draf yang tertahan di antrean
/// HP (status lokal `perlu_diperbaiki`).
///
/// Dipilih dari STATUS HTTP-nya, tidak pernah dari teks server. Alasannya
/// bukti nyata (uji kontrak app-API 19 Nov 2026, `kontrak/hasil/probe-http.json`
/// PR-A5, PR-A6): draf yang diarsipkan admin dijawab `404` dengan
/// `{"message":"No query results for model [App\Models\CalibrationSession]
/// 25"}`, yaitu nama kelas model Eloquent, dan antrean dulu menampilkannya
/// apa adanya ("Perlu diperbaiki: No query results for model ..."). Pesan
/// validasi Laravel juga berbahasa Inggris. Teks server boleh berubah kapan
/// saja; yang tetap hanya artinya status.
///
/// Salinan di HP TIDAK hilang saat ditolak (ditandai, tetap tersimpan), dan
/// kalimat 404 menyebut itu supaya teknisi tidak menulis ulang dari nol.
/// Kalimatnya sengaja pendek: kartu antrean memotong keterangan di tiga baris.
///
/// ## Dua kasus 404 yang BEDA
///
/// "Diarsipkan atau dihapus admin" hanya benar untuk 404 pada draf yang SUDAH
/// ada di server ([sudahDiServer]: `PUT`/sinkron ke `sesiId`, atau `PUT`
/// penyusul sesudah `POST` berhasil). `POST` draf BARU yang dijawab 404 berarti
/// alamatnya tidak dikenal server (aplikasi dan server tidak sepaham), bukan
/// draf yang hilang — kalimatnya lain.
///
/// ## 422 tidak membuang pesan validasi
///
/// Bila badan memuat `errors`, pesan validasi PERTAMA ikut ditampilkan (teknisi
/// perlu tahu isian mana yang salah), dipotong 120 karakter. Itu satu-satunya
/// teks server yang dipakai, dan hanya untuk 422.
String pesanPenolakanDraf(
  int status, {
  bool sudahDiServer = true,
  Map<String, dynamic>? badan,
}) => switch (status) {
  404 when !sudahDiServer =>
    'Server tidak mengenali tujuan draf ini (kode 404). Perbarui aplikasi, '
        'lalu hubungi admin bila berulang. Salinan di HP tetap tersimpan.',
  404 =>
    'Draf ini sudah diarsipkan atau dihapus admin. Salinan di HP tetap '
        'tersimpan.',
  403 =>
    'Akun ini tidak lagi boleh mengubah draf ini. Hubungi admin bila perlu.',
  409 =>
    'Draf ini berubah di tempat lain, mungkin dikirim dari perangkat lain. '
        'Buka drafnya untuk memeriksa isinya.',
  422 => _pesan422(badan),
  _ =>
    'Server menolak draf ini (kode $status). Buka draf dan periksa '
        'isiannya.',
};

String _pesan422(Map<String, dynamic>? badan) {
  const dasar =
      'Server menolak isi draf ini. Buka draf, periksa isiannya, lalu simpan '
      'lagi.';
  final pertama = _validasiPertama(badan);
  return pertama == null ? dasar : 'Server menolak isi draf ini: $pertama';
}

/// Pesan validasi pertama dari `errors` (`errors.<kolom>[0]`), dipotong.
String? _validasiPertama(Map<String, dynamic>? badan) {
  final errors = badan?['errors'];
  if (errors is! Map) return null;
  for (final nilai in errors.values) {
    final teks = switch (nilai) {
      final List l when l.isNotEmpty => '${l.first}',
      final String t => t,
      _ => '',
    }.trim();
    if (teks.isEmpty) continue;
    return teks.length <= 120 ? teks : '${teks.substring(0, 119)}…';
  }
  return null;
}
