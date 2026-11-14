// Daftar komponen bersama Lab (Paket 2) di `lib/widgets/sidik/`: berkas -> kelas
// publik. SATU sumber untuk tes pendaftaran
// (`test/komponen_sidik/pendaftaran_komponen_test.dart`) dan galeri render
// (`galeri_komponen.dart`).
//
// Komponen belum dipakai layar (Paket 3 sampai 5 memakainya per layar).
// `tool/cek-berkas-yatim.sh` menghitung berkas yang diimpor dari `test/` sebagai
// terpakai, jadi pengimpor sah untuk tiap komponen adalah galeri yang
// mengimpor SEMUANYA dan tes widget masing-masing, bukan pengecualian di
// pemeriksanya. Tes pendaftaran memastikan komponen baru tidak lolos tanpa
// masuk daftar ini (dan karena itu galeri dan tes).
const daftarKomponenLab = <String, List<String>>{
  'status_tampil': ['StatusTampil', 'NadaStempel', 'KataStatus'],
  'stempel': ['Stempel'],
  'baris_daftar': ['BarisDaftar', 'MetaBaris'],
  'tombol_utama': ['TombolUtama'],
  'bilah_aksi': ['BilahAksi', 'AksiBilah'],
  'skala_tempo': ['SkalaTempo'],
  'skala_sel': ['SkalaSel', 'KeadaanTik'],
  'navigasi_adaptif': [
    'NavigasiAdaptif',
    'BarNavigasi',
    'RailNavigasi',
    'TujuanNavigasi',
    'TujuanLab',
    'TataNavigasi',
  ],
  'keadaan_kosong_galat_offline': [
    'KeadaanKosongGalatOffline',
    'BannerOffline',
    'RagamKeadaan',
  ],
  'lajur_bacaan': ['LajurBacaan', 'ModeLajur', 'LabelLajur'],
};

/// Berkas di `lib/widgets/sidik/` yang BUKAN komponen Paket 2 (sudah ada
/// sebelumnya dan dipakai layar); dikecualikan dari tes pendaftaran.
const berkasSidikLama = <String>{
  'sidik_lembar',
  'sidik_permukaan',
  'sidik_status',
  'sidik_tombol',
};
