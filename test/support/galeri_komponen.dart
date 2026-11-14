// Galeri komponen bersama Lab (`lib/widgets/sidik/`, Paket 2) untuk harness
// render: tiap komponen dalam semua keadaannya (normal, kosong, panjang, galat,
// mati, sibuk). Dipakai `test/tampilan/render_komponen_lab_test.dart`, yang
// memeriksa luapan, kontras, pedoman sentuh + label, dan menulis PNG.
//
// Data SINTETIS (nama alat dan PT fiktif generik), tanpa pelanggan nyata.
// Galeri mengimpor SEMUA komponen: tak satu pun berkas komponen yatim dari
// harness (lihat `daftar_komponen.dart`).
import 'package:flutter/material.dart';
import 'package:sidik_calibration/core/theme/app_spacing.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/widgets/sidik/baris_daftar.dart';
import 'package:sidik_calibration/widgets/sidik/bilah_aksi.dart';
import 'package:sidik_calibration/widgets/sidik/keadaan_kosong_galat_offline.dart';
import 'package:sidik_calibration/widgets/sidik/lajur_bacaan.dart';
import 'package:sidik_calibration/widgets/sidik/navigasi_adaptif.dart';
import 'package:sidik_calibration/widgets/sidik/skala_sel.dart';
import 'package:sidik_calibration/widgets/sidik/skala_tempo.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';
import 'package:sidik_calibration/widgets/sidik/stempel.dart';
import 'package:sidik_calibration/widgets/sidik/tombol_utama.dart';

const namaAlatPanjang =
    'Termometer Digital Presisi Tinggi dengan Probe Stainless Steel Tipe K '
    'dan Layar Ganda';
const namaPtPanjang = 'PT Maju Jaya Sentosa Abadi Perkasa Nusantara Raya';

/// Caption kecil di atas tiap contoh (hanya untuk galeri; bukan komponen).
class _Catatan extends StatelessWidget {
  const _Catatan(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Text(teks, style: Theme.of(context).textTheme.bodySmall),
  );
}

Widget _tepi(Widget anak) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: anak,
);

/// Halaman 1: stempel status, semua kode.
Widget galeriStempel() {
  const kode = [
    'draft',
    'menunggu_approval',
    'perlu_revisi',
    'disetujui',
    'PASS',
    'FAIL',
    'aktif',
    'nonaktif',
    'valid',
    'warning',
    'expired',
    'overdue',
    'terbit',
    'menunggu_generate',
    'gagal',
    'pending',
    'ditarik',
    'baru',
    'diproses',
    'selesai',
    'dibatalkan',
    'berlaku',
    'digantikan',
    'belum_terbit',
    'kode_asing',
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Catatan('Stempel: semua kode status (ikon + kata)'),
      _tepi(
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final k in kode) Stempel(StatusTampil.dariKode(k)),
            Stempel(StatusTampil.dariKode('disetujui', keputusan: 'PASS')),
            Stempel(StatusTampil.dariKode('disetujui', keputusan: 'FAIL')),
          ],
        ),
      ),
      const _Catatan('Stempel jadwal: Lewat jadwal, Segera, Berlaku'),
      _tepi(
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final h in [-12, 0, 30, 31]) Stempel(StatusTampil.jadwal(h)),
          ],
        ),
      ),
      const _Catatan('Tenang (tanpa latar), keadaan normal'),
      _tepi(
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Stempel(StatusTampil.jadwal(120), tenang: true),
            Stempel(StatusTampil.dariKode('PASS'), tenang: true),
            Stempel(StatusTampil.dariKode('draft'), tenang: true),
          ],
        ),
      ),
      const _Catatan('Kata panjang membungkus di ruang sempit (160 dp)'),
      _tepi(
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 160,
            child: Stempel(StatusTampil.dariKode('expired')),
          ),
        ),
      ),
    ],
  );
}

/// Halaman 2: baris daftar.
Widget galeriBaris() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const _Catatan('BarisDaftar: normal, stempel di kanan'),
    BarisDaftar(
      judul: 'Timbangan Digital Ohaus',
      keterangan: 'CV Sentosa Abadi',
      status: StatusTampil.dariKode('disetujui', keputusan: 'FAIL'),
      meta: const [
        MetaBaris('Menunggu 3 hari', ikon: Icons.schedule),
        MetaBaris('2 peringatan', ikon: Icons.error_outline),
      ],
      onTap: () {},
    ),
    BarisDaftar(
      judul: 'Termometer Digital Fluke',
      keterangan: 'PT Maju Jaya',
      status: StatusTampil.dariKode('disetujui', keputusan: 'PASS'),
      onTap: () {},
    ),
    const _Catatan('BarisDaftar: judul dan pelanggan panjang, stempel panjang'),
    BarisDaftar(
      judul: namaAlatPanjang,
      keterangan: namaPtPanjang,
      status: StatusTampil.dariKode('expired'),
      meta: const [
        MetaBaris('Menunggu persetujuan admin lab', ikon: Icons.schedule),
      ],
      onTap: () {},
    ),
    const _Catatan('BarisDaftar: hanya baca, tanpa stempel, tanpa pemisah'),
    const BarisDaftar(
      judul: 'Autoklaf Tuttnauer',
      keterangan: 'Draf tersimpan 10.42',
      pemisah: false,
    ),
    const _Catatan('BarisDaftar: dengan skala jatuh tempo dan skala sel'),
    BarisDaftar(
      judul: 'Pressure Gauge WIKA',
      keterangan: 'PT Maju Jaya',
      status: StatusTampil.jadwal(-12),
      tambahan: const SkalaTempo(hari: -12, tanggal: '1 Nov 2026'),
      onTap: () {},
    ),
    BarisDaftar(
      judul: 'Oven Memmert UN55',
      keterangan: 'CV Sentosa Abadi',
      status: StatusTampil.dariKode('draft'),
      tambahan: const SkalaSel(terisi: 18, total: 24),
      onTap: () {},
    ),
    const _Catatan('BarisDaftar: penanda di kiri'),
    BarisDaftar(
      judul: 'Multimeter Fluke 87V',
      keterangan: 'Dikembalikan admin kemarin. 1 angka perlu diperbaiki.',
      awal: const Icon(Icons.edit_note),
      status: StatusTampil.dariKode('perlu_revisi'),
      onTap: () {},
    ),
  ],
);

/// Halaman 3: tombol utama dan bilah aksi.
Widget galeriAksi() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const _Catatan('TombolUtama: normal, dengan ikon'),
    _tepi(TombolUtama(label: 'Lanjutkan', onPressed: () {})),
    const SizedBox(height: AppSpacing.sm),
    _tepi(
      TombolUtama(label: 'Kirim ke admin', ikon: Icons.send, onPressed: () {}),
    ),
    const _Catatan('TombolUtama: mati dengan alasan, sibuk'),
    _tepi(
      const TombolUtama(
        label: 'Kirim ke admin',
        onPressed: null,
        alasanMati: 'Isi 2 sel wajib dulu.',
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    _tepi(TombolUtama(label: 'Kirim ke admin', onPressed: () {}, sibuk: true)),
    const _Catatan('TombolUtama: label panjang membungkus'),
    _tepi(
      TombolUtama(
        label: 'Kirim lembar kerja ke admin untuk diperiksa dan disetujui',
        ikon: Icons.send,
        onPressed: () {},
      ),
    ),
    const _Catatan('BilahAksi: utama + satu sekunder (lebar layar)'),
    BilahAksi(
      utama: AksiBilah(label: 'Kirim ke admin', onPressed: () {}),
      sekunder: [AksiBilah(label: 'Simpan draf', onPressed: () {})],
    ),
    const _Catatan('BilahAksi: dibatasi 320 dp (bertumpuk)'),
    Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: BilahAksi(
          utama: AksiBilah(label: 'Kirim ke admin', onPressed: () {}),
          sekunder: [AksiBilah(label: 'Simpan draf', onPressed: () {})],
        ),
      ),
    ),
    const _Catatan('BilahAksi: dua sekunder, ikon, mati dengan alasan'),
    BilahAksi(
      utama: const AksiBilah(
        label: 'Kirim ke admin',
        ikon: Icons.send,
        onPressed: null,
      ),
      sekunder: [
        AksiBilah(label: 'Simpan draf', onPressed: () {}),
        AksiBilah(label: 'Kembali', ikon: Icons.arrow_back, onPressed: () {}),
      ],
      alasanMati: 'Isi 2 sel wajib dulu.',
    ),
    const _Catatan('BilahAksi: sibuk; hanya utama'),
    BilahAksi(
      utama: AksiBilah(label: 'Kirim ke admin', onPressed: () {}),
      sekunder: [AksiBilah(label: 'Simpan draf', onPressed: () {})],
      sibuk: true,
    ),
    BilahAksi(
      utama: AksiBilah(label: 'Mulai kalibrasi', onPressed: () {}),
    ),
  ],
);

/// Halaman 4: skala jatuh tempo dan skala sel.
Widget galeriSkala() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const _Catatan('SkalaTempo di baris: Lewat jadwal 12 hari'),
    _tepi(const SkalaTempo(hari: -12, tanggal: '1 Nov 2026')),
    const _Catatan(
      'SkalaTempo di baris: Lewat jadwal 2 hari (ekor 8%), 200 hari',
    ),
    _tepi(const SkalaTempo(hari: -2, tanggal: '12 Nov 2026')),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaTempo(hari: -200, tanggal: '28 Apr 2026')),
    const _Catatan('SkalaTempo di baris: Segera 12 hari, hari ini, 30 hari'),
    _tepi(const SkalaTempo(hari: 12, tanggal: '26 Nov 2026')),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaTempo(hari: 0, tanggal: '14 Nov 2026')),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaTempo(hari: 30, tanggal: '14 Des 2026')),
    const _Catatan('SkalaTempo: lewat jadwal tanpa tanggal (hari null)'),
    _tepi(const SkalaTempo(hari: null)),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaTempo(hari: null, detail: true)),
    const _Catatan('SkalaTempo di baris "Berlaku": satu kalimat, tanpa batang'),
    _tepi(const SkalaTempo(hari: 240, tanggal: '13 Jul 2027')),
    const _Catatan('SkalaTempo detail alat: lewat, segera, jauh'),
    _tepi(const SkalaTempo(hari: -12, tanggal: '1 Nov 2026', detail: true)),
    const SizedBox(height: AppSpacing.lg),
    _tepi(const SkalaTempo(hari: 12, tanggal: '26 Nov 2026', detail: true)),
    const SizedBox(height: AppSpacing.lg),
    _tepi(const SkalaTempo(hari: 240, tanggal: '13 Jul 2027', detail: true)),
    const _Catatan('SkalaSel: 12 dari 30, kosong, penuh, tanpa sel'),
    _tepi(const SkalaSel(terisi: 12, total: 30)),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaSel(terisi: 0, total: 30)),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaSel(terisi: 30, total: 30)),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaSel(terisi: 0, total: 0)),
    const _Catatan(
      'SkalaSel: 60 sel (satu tik per sel) dan 150 sel (kelompok)',
    ),
    _tepi(const SkalaSel(terisi: 41, total: 60)),
    const SizedBox(height: AppSpacing.md),
    _tepi(const SkalaSel(terisi: 67, total: 150)),
  ],
);

/// Halaman 5: navigasi.
Widget galeriNavigasi() => Builder(
  builder: (context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Catatan('BarNavigasi admin: 5 tab, lencana Antrean 3'),
        BarNavigasi(
          tujuan: TujuanLab.admin(l, persetujuan: 3),
          indeks: 1,
          onPilih: (_) {},
        ),
        const _Catatan(
          'BarNavigasi admin: lencana 120 menjadi 99+, tab Beranda',
        ),
        BarNavigasi(
          tujuan: TujuanLab.admin(l, persetujuan: 120),
          indeks: 0,
          onPilih: (_) {},
        ),
        const _Catatan('BarNavigasi teknisi: 2 tab'),
        BarNavigasi(tujuan: TujuanLab.teknisi(l), indeks: 0, onPilih: (_) {}),
        const _Catatan('RailNavigasi admin: 80 dp berlabel'),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 420,
            child: RailNavigasi(
              tujuan: TujuanLab.admin(l, persetujuan: 3),
              indeks: 2,
              onPilih: (_) {},
            ),
          ),
        ),
        const _Catatan('NavigasiAdaptif di lebar HP (bar)'),
        SizedBox(
          height: 260,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 392),
              child: NavigasiAdaptif(
                tujuan: TujuanLab.admin(l, persetujuan: 5),
                indeks: 0,
                onPilih: (_) {},
                isi: const _IsiContoh(),
              ),
            ),
          ),
        ),
        // Contoh lebar 1000 dp hanya di viewport tablet (di HP akan meluap).
        Builder(
          builder: (context) => MediaQuery.sizeOf(context).width < 1000
              ? const SizedBox.shrink()
              : const _NavigasiLebar(),
        ),
      ],
    );
  },
);

class _NavigasiLebar extends StatelessWidget {
  const _NavigasiLebar();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Catatan('NavigasiAdaptif di 1000 dp (rail), admin'),
      SizedBox(
        height: 460,
        child: _Lebar1000(
          NavigasiAdaptif(
            tujuan: TujuanLab.admin(
              AppLocalizations.of(context),
              persetujuan: 5,
            ),
            indeks: 1,
            onPilih: (_) {},
            isi: const _IsiContoh(),
          ),
        ),
      ),
      const _Catatan('NavigasiAdaptif teknisi di 1000 dp: tanpa navigasi'),
      SizedBox(
        height: 120,
        child: _Lebar1000(
          NavigasiAdaptif(
            tujuan: TujuanLab.teknisi(AppLocalizations.of(context)),
            indeks: 0,
            onPilih: (_) {},
            isi: const _IsiContoh(),
          ),
        ),
      ),
    ],
  );
}

/// Memaksa [anak] selebar 1000 dp walau induknya dibatasi 720 dp (isi galeri),
/// supaya navigasi memilih rail seperti di tablet sungguhan.
class _Lebar1000 extends StatelessWidget {
  const _Lebar1000(this.anak);
  final Widget anak;

  @override
  Widget build(BuildContext context) => OverflowBox(
    alignment: Alignment.centerLeft,
    minWidth: 1000,
    maxWidth: 1000,
    child: anak,
  );
}

class _IsiContoh extends StatelessWidget {
  const _IsiContoh();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: const Center(child: Text('Isi layar')),
  );
}

/// Halaman 6: keadaan kosong, galat, offline, dan banner.
Widget galeriKeadaan() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const _Catatan('Banner offline di atas daftar'),
    const BannerOffline(
      teks:
          'Tanpa sambungan. Draf tetap tersimpan di perangkat; pengiriman '
          'ditahan sampai tersambung.',
    ),
    const _Catatan('Kosong dengan tindakan'),
    KeadaanKosongGalatOffline(
      ragam: RagamKeadaan.kosong,
      judul: 'Belum ada draf',
      penjelasan: 'Mulai lembar baru dari tombol di bawah.',
      labelAksi: 'Mulai kalibrasi',
      onAksi: () {},
    ),
    const _Catatan('Kosong sebagai aksi utama 56 dp'),
    KeadaanKosongGalatOffline(
      ragam: RagamKeadaan.kosong,
      judul: 'Belum ada kalibrasi',
      penjelasan: 'Pilih alat untuk memulai lembar pertama.',
      labelAksi: 'Mulai kalibrasi',
      onAksi: () {},
      aksiUtama: true,
    ),
    const _Catatan('Galat dengan "Coba lagi"'),
    KeadaanKosongGalatOffline(
      ragam: RagamKeadaan.galat,
      judul: 'Daftar tidak bisa dimuat',
      penjelasan: 'Server tidak menjawab. Periksa sambungan, lalu coba lagi.',
      labelAksi: 'Coba lagi',
      onAksi: () {},
    ),
    const _Catatan('Offline tanpa data tersimpan'),
    KeadaanKosongGalatOffline(
      ragam: RagamKeadaan.offline,
      judul: 'Tidak ada sambungan',
      penjelasan: 'Daftar ini belum pernah dimuat di perangkat ini.',
      labelAksi: 'Coba lagi',
      onAksi: () {},
    ),
    const _Catatan('Teks panjang, tanpa tindakan'),
    const KeadaanKosongGalatOffline(
      ragam: RagamKeadaan.galat,
      judul:
          'Lembar kerja Termometer Digital Presisi Tinggi tidak bisa dibuka '
          'karena versi aplikasi lebih lama dari versi lembar',
      penjelasan:
          'Perbarui aplikasi dari pesan pembaruan yang muncul, lalu buka '
          'kembali lembar ini. Draf Anda tetap aman di perangkat.',
    ),
  ],
);

/// Halaman 7: Lajur Bacaan.
Widget galeriLajur() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const _Catatan('Lajur Bacaan (otomatis menurut ukuran layar)'),
    LajurBacaan(
      judul: 'Set point 150 °C',
      subjudul: 'Detik ke-20',
      posisi: (ke: 8, dari: 30),
      pengulangan: (ke: 3, dari: 5),
      nilai: '150,0',
      satuan: '°C',
      onUbah: (_) {},
      onBerikutnya: () {},
      onPakaiPapanKetik: () {},
    ),
    const _Catatan('Lajur keypad (dipaksa): kosong, dengan catatan saran foto'),
    LajurBacaan(
      mode: ModeLajur.keypad,
      judul: 'Set point 200 °C',
      subjudul: 'Detik ke-20',
      posisi: (ke: 9, dari: 30),
      pengulangan: (ke: 1, dari: 5),
      nilai: '',
      satuan: '°C',
      catatan: 'Saran dari foto, belum dipastikan. Periksa angkanya.',
      onUbah: (_) {},
      onBerikutnya: () {},
    ),
    const _Catatan('Lajur keypad (dipaksa): angka 12 karakter, nama panjang'),
    LajurBacaan(
      mode: ModeLajur.keypad,
      judul: 'Pembacaan UUT titik ukur 1000 mbar pada pengulangan kelima',
      subjudul: 'Pembacaan standar kedua',
      posisi: (ke: 30, dari: 30),
      pengulangan: (ke: 5, dari: 5),
      nilai: '-1234567,890',
      satuan: 'mbar',
      onUbah: (_) {},
      onBerikutnya: () {},
    ),
    const _Catatan('Lajur keypad (dipaksa): Berikutnya mati dengan alasan'),
    LajurBacaan(
      mode: ModeLajur.keypad,
      judul: 'Set point 250 °C',
      nilai: '25',
      satuan: '°C',
      onUbah: (_) {},
      onBerikutnya: null,
      alasanMati: 'Sel terakhir. Gunakan Kirim ke admin.',
    ),
    const _Catatan('Lajur ringkas (papan ketik sistem yang mengetik)'),
    LajurBacaan(
      mode: ModeLajur.ringkas,
      judul: 'Set point 150 °C',
      subjudul: 'Detik ke-20',
      posisi: (ke: 8, dari: 30),
      nilai: '150,0',
      satuan: '°C',
      onUbah: (_) {},
      onBerikutnya: () {},
      onPakaiKeypad: () {},
    ),
    const _Catatan('Lajur keypad di kolom tablet 380 dp'),
    Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: LajurBacaan(
          mode: ModeLajur.keypad,
          judul: 'Set point 150 °C',
          subjudul: 'Detik ke-20',
          posisi: (ke: 8, dari: 30),
          pengulangan: (ke: 3, dari: 5),
          nilai: '150,0',
          satuan: '°C',
          onUbah: (_) {},
          onBerikutnya: () {},
        ),
      ),
    ),
  ],
);

/// Halaman galeri: nama -> pembangun.
final galeriHalaman = <String, Widget Function()>{
  'stempel': galeriStempel,
  'baris': galeriBaris,
  'aksi': galeriAksi,
  'skala': galeriSkala,
  'navigasi': galeriNavigasi,
  'keadaan': galeriKeadaan,
  'lajur': galeriLajur,
};
