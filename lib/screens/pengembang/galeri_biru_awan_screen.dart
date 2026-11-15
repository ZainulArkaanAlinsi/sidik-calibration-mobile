import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../widgets/biru_awan/chip_saring.dart';
import '../../widgets/biru_awan/isian_sidik.dart';
import '../../widgets/biru_awan/kartu_sidik24.dart';
import '../../widgets/biru_awan/kepala_layar.dart';
import '../../widgets/biru_awan/panel_baris.dart';
import '../../widgets/biru_awan/segmen_pil.dart';
import '../../widgets/biru_awan/stempel_sidik.dart';
import '../../widgets/biru_awan/tombol_bulat.dart';
import '../../widgets/biru_awan/tombol_sidik.dart';
import '../../widgets/biru_awan/ubin_ikon.dart';
import '../../widgets/sidik/status_tampil.dart';

/// Galeri komponen dasar Biru Awan (L3a), KHUSUS PENGEMBANG.
///
/// Tidak ada rute di navigasi pengguna. Satu-satunya pintu masuk adalah baris
/// "Komponen Biru Awan" di `design_system_screen.dart` yang hanya dibuat di
/// build debug (`kDebugMode`). Teks di sini contoh data pemanggil, bukan teks
/// produk, jadi tidak lewat l10n.
///
/// Belum ada layar yang memakai komponen ini; halaman ini tempat meninjau
/// bentuk, keadaan, dan dua tema sebelum layar L5 dst. memakainya.
class GaleriBiruAwanScreen extends StatelessWidget {
  const GaleriBiruAwanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bagian = <Widget>[
      const _BagianTombol(),
      const _BagianTombolBulat(),
      const _BagianIsian(),
      const _BagianStempel(),
      const _BagianChipSegmen(),
      const _BagianKartu(),
      const _BagianPanel(),
      const _BagianKepala(),
      const _BagianGerak(),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const KepalaAnak(judul: 'Galeri Biru Awan', nomor: 'L3a'),
            for (var i = 0; i < bagian.length; i++)
              MasukBerurutan(
                indeks: i,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: bagian[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu bagian galeri: judul, keterangan, isi.
class _Bagian extends StatelessWidget {
  const _Bagian({required this.judul, this.keterangan, required this.anak});

  final String judul;
  final String? keterangan;
  final List<Widget> anak;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            judul,
            style: HurufBiruAwan.judulBagian.copyWith(color: m.tinta),
          ),
        ),
        if (keterangan != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              keterangan!,
              style: HurufBiruAwan.keteranganKecil.copyWith(color: m.tinta2),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final a in anak) ...[
          a,
          const SizedBox(height: JarakBiruAwan.blok),
        ],
      ],
    );
  }
}

class _BagianTombol extends StatelessWidget {
  const _BagianTombol();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'TombolSidik',
      keterangan:
          'Utama 56 (satu per layar); tegas, sekunder, teks, bahaya 48.',
      anak: [
        TombolSidik(label: 'Kirim untuk approval', onPressed: () {}),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TombolSidik(
              label: 'Ringkasan',
              ragam: RagamTombolSidik.tegas,
              onPressed: () {},
            ),
            TombolSidik(
              label: 'Simpan draf',
              ragam: RagamTombolSidik.sekunder,
              ikon: Icons.save_outlined,
              onPressed: () {},
            ),
            TombolSidik(
              label: 'Batal',
              ragam: RagamTombolSidik.teks,
              onPressed: () {},
            ),
            TombolSidik(
              label: 'Tarik sertifikat',
              ragam: RagamTombolSidik.bahaya,
              onPressed: () {},
            ),
          ],
        ),
        const TombolSidik(
          label: 'Kirim untuk approval',
          onPressed: null,
          alasanMati: 'Isi 2 sel wajib dulu.',
        ),
        TombolSidik(label: 'Menyimpan', onPressed: () {}, sibuk: true),
      ],
    );
  }
}

class _BagianTombolBulat extends StatelessWidget {
  const _BagianTombolBulat();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'TombolBulat',
      keterangan: 'Gambar 44, 48, 60; area sentuh minimum 48.',
      anak: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TombolBulat(
              ikon: Icons.add,
              label: 'Tambah',
              ragam: RagamTombolBulat.primer,
              ukuran: UkuranTombolBulat.kecil,
              onPressed: () {},
            ),
            TombolBulat(
              ikon: Icons.arrow_back,
              label: 'Kembali',
              onPressed: () {},
            ),
            TombolBulat(
              ikon: Icons.menu,
              label: 'Buka menu',
              ragam: RagamTombolBulat.navy,
              onPressed: () {},
            ),
            TombolBulat(
              ikon: Icons.play_arrow_rounded,
              label: 'Mulai kalibrasi',
              ragam: RagamTombolBulat.primer,
              ukuran: UkuranTombolBulat.mulai,
              onPressed: () {},
            ),
            const TombolBulat(
              ikon: Icons.search,
              label: 'Cari',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}

class _BagianIsian extends StatelessWidget {
  const _BagianIsian();

  @override
  Widget build(BuildContext context) {
    return const _Bagian(
      judul: 'IsianSidik',
      keterangan: 'Biasa, fokus (ketuk kotaknya), galat, mati.',
      anak: [
        IsianSidik(label: 'Nama lengkap', petunjuk: 'mis. Rekan Teknisi'),
        IsianSidik(
          label: 'Kode teknisi',
          mono: true,
          wajib: true,
          bantuan: 'Kecetak di sertifikat yang ditandatangani',
        ),
        IsianSidik(label: 'Email', galat: 'Format email belum lengkap'),
        IsianSidik(
          label: 'Organisasi',
          enabled: false,
          petunjuk: 'PT Sistem Dirgantara Inovasi Teknologi',
        ),
      ],
    );
  }
}

class _BagianStempel extends StatelessWidget {
  const _BagianStempel();

  @override
  Widget build(BuildContext context) {
    const kode = [
      'draft',
      'menunggu_approval',
      'perlu_revisi',
      'disetujui',
      'PASS',
      'FAIL',
      'overdue',
      'expired',
      'dibatalkan',
    ];
    return _Bagian(
      judul: 'StempelSidik',
      keterangan:
          'Nada dari pemetaan status yang ada. FAIL navy pekat; keputusan '
          'kosong netral, tidak pernah hijau.',
      anak: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final k in kode) StempelSidik(StatusTampil.dariKode(k)),
            StempelSidik.keputusan(null),
            const StempelSidik.teks(
              teks: '1 FAIL',
              nada: NadaStempel.gagal,
              ikon: Icons.cancel_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _BagianChipSegmen extends StatefulWidget {
  const _BagianChipSegmen();

  @override
  State<_BagianChipSegmen> createState() => _BagianChipSegmenState();
}

enum _Peran { teknisi, admin, viewer }

class _BagianChipSegmenState extends State<_BagianChipSegmen> {
  int _chip = 0;
  _Peran _peran = _Peran.teknisi;

  @override
  Widget build(BuildContext context) {
    const label = ['Semua', 'Ada FAIL', 'Lewat jadwal'];
    const jumlah = [4, 1, 6];
    const isi = [IsiBiruAwan.kuning, IsiBiruAwan.koral, IsiBiruAwan.netral];
    return _Bagian(
      judul: 'ChipSaring dan SegmenPil',
      keterangan: 'Chip 44 dengan jumlah; segmen 56 untuk 2 sampai 3 pilihan.',
      anak: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < label.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                ChipSaring(
                  label: label[i],
                  jumlah: jumlah[i],
                  isiJumlah: isi[i],
                  terpilih: _chip == i,
                  onTap: () => setState(() => _chip = i),
                ),
              ],
            ],
          ),
        ),
        SegmenPil<_Peran>(
          label: 'Peran',
          nilai: _peran,
          onChanged: (p) => setState(() => _peran = p),
          item: const [
            SegmenPilItem(nilai: _Peran.teknisi, label: 'Teknisi'),
            SegmenPilItem(nilai: _Peran.admin, label: 'Admin'),
            SegmenPilItem(nilai: _Peran.viewer, label: 'Viewer'),
          ],
        ),
      ],
    );
  }
}

class _BagianKartu extends StatelessWidget {
  const _BagianKartu();

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    Widget isi(String judul, String sub) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(judul, style: HurufBiruAwan.judulBaris.copyWith(color: m.tinta)),
        Text(
          sub,
          style: HurufBiruAwan.keteranganKecil.copyWith(color: m.tinta2),
        ),
      ],
    );
    return _Bagian(
      judul: 'KartuSidik24',
      keterangan: 'Sudut 24, datar. Bisa diketuk: skala 0,97 saat ditekan.',
      anak: [
        KartuSidik24(child: isi('Kartu biasa', 'Hanya wadah, tanpa aksi')),
        KartuSidik24(
          onTap: () {},
          child: isi('Kartu bisa diketuk', 'Oven Memmert, PT Karya Logam'),
        ),
        KartuSidik24(
          terpilih: true,
          onTap: () {},
          child: isi('Kartu terpilih', 'Kabut dengan garis primer 2 dp'),
        ),
        KartuSidik24(
          latar: LatarKartu.galat,
          child: isi('Kartu galat', 'Koral tipis untuk peringatan'),
        ),
      ],
    );
  }
}

class _BagianPanel extends StatelessWidget {
  const _BagianPanel();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'PanelBaris, BarisMenu64, BarisDaftar72, UbinIkon',
      keterangan: 'Menu 64 dengan ubin bulat 44; daftar 72 dengan ubin 48.',
      anak: [
        PanelBaris(
          anak: [
            BarisMenu64(
              judul: 'Pelanggan',
              keterangan: 'Kelola daftar pelanggan lab',
              ikon: Icons.people_outline,
              onTap: () {},
            ),
            BarisMenu64(
              judul: 'Standar acuan',
              keterangan: 'Kelola alat standar lab',
              ikon: Icons.science_outlined,
              warna: IsiBiruAwan.hijau,
              onTap: () {},
            ),
            BarisMenu64(
              judul: 'Data teknisi',
              keterangan: 'Akun teknisi, peran, dan kode',
              ikon: Icons.badge_outlined,
              warna: IsiBiruAwan.awan,
              onTap: () {},
            ),
            BarisMenu64(
              judul: 'Buat akun teknisi',
              ikon: Icons.person_add_alt,
              warna: IsiBiruAwan.kuning,
              onTap: () {},
            ),
            BarisMenu64(
              judul: 'Rumus kalibrasi',
              keterangan: 'Parameter dan riwayat versi',
              ikon: Icons.functions,
              warna: IsiBiruAwan.koralTipis,
              onTap: () {},
            ),
          ],
        ),
        PanelBaris.daftar(
          anak: [
            BarisDaftar72(
              judul: 'Oven Memmert',
              keterangan: 'PT Karya Logam',
              nomor: 'KAL/2026/11/0001',
              awal: const UbinIkon.baris(ikon: Icons.thermostat),
              akhir: StempelSidik(StatusTampil.dariKode('overdue')),
              onTap: () {},
            ),
            BarisDaftar72(
              judul: 'Pressure Gauge',
              keterangan: 'PT Tirta Contoh',
              awal: const UbinIkon.baris(ikon: Icons.speed),
              akhir: StempelSidik.keputusan('FAIL'),
              onTap: () {},
            ),
            BarisDaftar72(
              judul: 'Timbangan Analitik',
              keterangan: 'PT Kaldu Sari',
              awal: const UbinIkon.baris(ikon: Icons.scale_outlined),
              akhir: StempelSidik.keputusan(null),
            ),
          ],
        ),
      ],
    );
  }
}

class _BagianKepala extends StatelessWidget {
  const _BagianKepala();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'KepalaTab dan KepalaAnak',
      keterangan: 'Kepala layar dari dock, dan kepala layar yang di-push.',
      anak: [
        KepalaTab(
          judul: 'SIDIK Lab',
          subjudul: 'Admin, Master Data',
          aksi: [
            TombolBulat(
              ikon: Icons.notifications_none,
              label: 'Notifikasi',
              onPressed: () {},
            ),
            TombolBulat(
              ikon: Icons.menu,
              label: 'Buka menu',
              ragam: RagamTombolBulat.navy,
              onPressed: () {},
            ),
          ],
        ),
        KepalaAnak(
          judul: 'Standar acuan',
          nomor: 'KAL/2026/11/0001',
          onKembali: () {},
          aksi: TombolBulat(
            ikon: Icons.add,
            label: 'Tambah standar',
            ragam: RagamTombolBulat.primer,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _BagianGerak extends StatefulWidget {
  const _BagianGerak();

  @override
  State<_BagianGerak> createState() => _BagianGerakState();
}

class _BagianGerakState extends State<_BagianGerak> {
  int _putaran = 0;

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'MasukBerurutan dan TekanSkala',
      keterangan:
          'Masuk 240 ms naik 12 dp, berurutan 35 ms. "Kurangi gerak" di sistem '
          'membuat semuanya langsung tampil.',
      anak: [
        TombolSidik(
          label: 'Putar ulang',
          ragam: RagamTombolSidik.sekunder,
          ikon: Icons.replay,
          onPressed: () => setState(() => _putaran++),
        ),
        Column(
          key: ValueKey(_putaran),
          children: [
            for (var i = 0; i < 4; i++)
              MasukBerurutan(
                indeks: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: KartuSidik24(
                    child: Text('Butir ${i + 1}', style: HurufBiruAwan.label),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
