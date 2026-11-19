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
String pesanPenolakanDraf(int status) => switch (status) {
  404 =>
    'Draf ini sudah diarsipkan atau dihapus admin. Salinan di HP ini tetap '
        'tersimpan; minta admin memulihkannya bila masih dibutuhkan.',
  403 =>
    'Akun ini tidak lagi boleh mengubah draf ini. Hubungi admin bila perlu.',
  409 =>
    'Draf ini berubah di tempat lain, mungkin dikirim dari perangkat lain. '
        'Buka drafnya untuk memeriksa isinya.',
  422 =>
    'Server menolak isi draf ini. Buka draf, periksa isiannya, lalu simpan '
        'lagi.',
  _ =>
    'Server menolak draf ini (kode $status). Buka draf dan periksa '
        'isiannya.',
};
