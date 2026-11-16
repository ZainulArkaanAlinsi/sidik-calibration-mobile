import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';
import '../../core/theme/token_umpan_balik_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../widgets/biru_awan/avatar_inisial.dart';
import '../../widgets/biru_awan/banner_sidik.dart';
import '../../widgets/biru_awan/bilah_langkah.dart';
import '../../widgets/biru_awan/chip_saring.dart';
import '../../widgets/biru_awan/dialog_sidik.dart';
import '../../widgets/biru_awan/garis_waktu.dart';
import '../../widgets/biru_awan/grafik_batang.dart';
import '../../widgets/biru_awan/hero_langit.dart';
import '../../widgets/biru_awan/isian_sidik.dart';
import '../../widgets/biru_awan/kartu_sidik24.dart';
import '../../widgets/biru_awan/keadaan_sidik.dart';
import '../../widgets/biru_awan/kepala_layar.dart';
import '../../widgets/biru_awan/kolom_cari.dart';
import '../../widgets/biru_awan/lembar_bawah_sidik.dart';
import '../../widgets/biru_awan/lencana.dart';
import '../../widgets/biru_awan/panel_baris.dart';
import '../../widgets/biru_awan/segmen_pil.dart';
import '../../widgets/biru_awan/stempel_sidik.dart';
import '../../widgets/biru_awan/stepper_tegak.dart';
import '../../widgets/biru_awan/toast_sidik.dart';
import '../../widgets/biru_awan/tombol_bulat.dart';
import '../../widgets/biru_awan/tombol_sidik.dart';
import '../../widgets/biru_awan/ubin_ikon.dart';
import '../../widgets/biru_awan/ubin_kpi.dart';
import '../../widgets/sidik/status_tampil.dart';

/// Galeri komponen dasar Biru Awan (L3a, L3b, dan elemen umpan balik L2),
/// KHUSUS PENGEMBANG.
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
      const _BagianHeroKpi(),
      const _BagianGrafikRiwayat(),
      const _BagianLangkah(),
      const _BagianKontrolKecil(),
      const _BagianToast(),
      const _BagianDialogLembar(),
      const _BagianBanner(),
      const _BagianKeadaan(),
      const _BagianGerak(),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const KepalaAnak(judul: 'Galeri Biru Awan', nomor: 'L3b + L2'),
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

/// L3b: HeroLangit dan UbinKpi (beranda admin).
class _BagianHeroKpi extends StatelessWidget {
  const _BagianHeroKpi();

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return _Bagian(
      judul: 'HeroLangit dan UbinKpi',
      keterangan:
          'Hero langit 212 dengan motif skala (bukan awan); ubin KPI min 112, '
          'angka 36/800. Angka dari pemanggil.',
      anak: [
        HeroLangit(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antrean approval',
                style: HurufLanjutBiruAwan.labelKpi.copyWith(color: m.tinta),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('4', style: HurufLanjutBiruAwan.angkaHero),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'menunggu, 1 ada FAIL',
                      style: HurufBiruAwan.labelKecil,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TombolSidik(
                label: 'Buka antrean',
                ragam: RagamTombolSidik.tegas,
                ikon: Icons.arrow_forward,
                lebarPenuh: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const Row(
          children: [
            Expanded(
              child: UbinKpi(
                label: 'Total alat',
                nilai: '128',
                catatan: 'se-lab',
              ),
            ),
            SizedBox(width: JarakBiruAwan.blok),
            Expanded(
              child: UbinKpi(
                label: 'Lewat jadwal',
                nilai: '6',
                ragam: RagamUbinKpi.koral,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: UbinKpi(
                label: 'Draft kalibrasi',
                nilai: '3',
                ragam: RagamUbinKpi.kabut,
              ),
            ),
            const SizedBox(width: JarakBiruAwan.blok),
            Expanded(
              child: UbinKpi(
                label: 'Sertifikat bulan ini',
                nilai: '21',
                catatan: '+4',
                ragam: RagamUbinKpi.hijau,
                onTap: () {},
              ),
            ),
          ],
        ),
        const UbinKpi(
          label: 'Menunggu approval',
          nilai: '4',
          ragam: RagamUbinKpi.navy,
        ),
      ],
    );
  }
}

/// L3b: GrafikBatang dan GarisWaktu.
class _BagianGrafikRiwayat extends StatelessWidget {
  const _BagianGrafikRiwayat();

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return _Bagian(
      judul: 'GrafikBatang dan GarisWaktu',
      keterangan:
          'Batang tumbuh 240 ms sekali; hari ini primer. Garis waktu: pelaku '
          'tebal, detail bebas.',
      anak: [
        const KartuSidik24(
          child: GrafikBatang(
            semantik: 'Grafik pekerjaan, 7 hari',
            sorot: 6,
            penandaSorot: 'hari ini',
            batang: [
              BatangGrafik(label: 'Sen', nilai: 5, teksNilai: '5'),
              BatangGrafik(label: 'Sel', nilai: 8, teksNilai: '8'),
              BatangGrafik(label: 'Rab', nilai: 6, teksNilai: '6'),
              BatangGrafik(label: 'Kam', nilai: 9, teksNilai: '9'),
              BatangGrafik(label: 'Jum', nilai: 4, teksNilai: '4'),
              BatangGrafik(label: 'Sab', nilai: 0, teksNilai: '0'),
              BatangGrafik(label: 'Min', nilai: 7, teksNilai: '7'),
            ],
          ),
        ),
        KartuSidik24(
          child: GarisWaktu(
            butir: [
              ButirGarisWaktu(
                waktu: 'Hari ini, 08.42',
                pelaku: 'Admin',
                kalimat: 'mengubah U standar Buffer pH 10,01',
                detail: Text(
                  '0,02 menjadi 0,03',
                  style: SidikTheme.gayaAngka(
                    ukuran: 14,
                    berat: FontWeight.w600,
                  ).copyWith(color: m.tinta),
                ),
              ),
              const ButirGarisWaktu(
                waktu: 'Kemarin, 16.10',
                kalimat: 'Sesi dikirim untuk approval',
              ),
              const ButirGarisWaktu(
                waktu: '12 Nov, 09.00',
                pelaku: 'Siti',
                kalimat: 'membuat draf',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// L3b: StepperTegak dan BilahLangkah.
class _BagianLangkah extends StatelessWidget {
  const _BagianLangkah();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'StepperTegak dan BilahLangkah',
      keterangan: 'Selesai, sekarang, belum: bukan hanya warna.',
      anak: [
        const BilahLangkah(
          label: ['Alat', 'Data', 'Lembar', 'Kirim'],
          aktif: 1,
        ),
        KartuSidik24(
          child: StepperTegak(
            langkah: [
              const LangkahStepper(
                judul: 'Lembar kerja',
                keadaan: KeadaanLangkah.selesai,
                keterangan: 'Beres',
              ),
              LangkahStepper(
                judul: 'Perhitungan & approval',
                keadaan: KeadaanLangkah.sekarang,
                penanda: StempelSidik.teks(
                  teks: 'Lagi di sini',
                  nada: NadaStempel.tunggu,
                  ikon: Icons.place_outlined,
                ),
              ),
              const LangkahStepper(
                judul: 'Sertifikat terbit',
                keadaan: KeadaanLangkah.belum,
              ),
              const LangkahStepper(
                judul: 'Kekirim ke pelanggan',
                keadaan: KeadaanLangkah.belum,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// L3b: AvatarInisial, Lencana, LoncengBerlencana, KolomCari.
class _BagianKontrolKecil extends StatefulWidget {
  const _BagianKontrolKecil();

  @override
  State<_BagianKontrolKecil> createState() => _BagianKontrolKecilState();
}

class _BagianKontrolKecilState extends State<_BagianKontrolKecil> {
  final _cari = TextEditingController();
  String _dicari = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'AvatarInisial, Lencana, KolomCari',
      keterangan:
          'Avatar 36/48/52/84; lencana koral 22, kuning 26, titik 10; kolom '
          'cari 56 (cincin fokus di luar).',
      anak: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AvatarInisial.dariNama(
              'Siti Aminah',
              ukuran: UkuranAvatarInisial.kecil,
            ),
            AvatarInisial.dariNama('Siti Aminah'),
            AvatarInisial.dariNama(
              'Siti Aminah',
              ukuran: UkuranAvatarInisial.laci,
              ragam: RagamAvatarInisial.langit,
            ),
            AvatarInisial.dariNama(
              'Budi Santoso',
              ukuran: UkuranAvatarInisial.besar,
              ragam: RagamAvatarInisial.putih,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Lencana(jumlah: 7),
            const Lencana(jumlah: 120),
            const Lencana(jumlah: 3, ragam: RagamLencana.kuning),
            const Lencana.titik(),
            LoncengBerlencana(
              label: 'Notifikasi, 12 belum dibaca',
              jumlah: 12,
              onPressed: () {},
            ),
          ],
        ),
        KolomCari(
          petunjuk: 'Cari nama, nomor seri, atau besaran',
          controller: _cari,
          onCari: (v) => setState(() => _dicari = v),
        ),
        Text(
          _dicari.isEmpty ? 'Belum ada pencarian' : 'Dicari: $_dicari',
          style: HurufBiruAwan.keteranganKecil.copyWith(
            color: SidikMaterial.of(context).tinta2,
          ),
        ),
        const KolomCari(petunjuk: 'Cari (mati)', enabled: false),
      ],
    );
  }
}

/// L2: toast. Kartu statis tiap jenis, lalu tombol yang memanggil
/// `tampilkanToast` sungguhan (satu sekaligus; yang baru menggantikan).
class _BagianToast extends StatelessWidget {
  const _BagianToast();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'ToastSidik',
      keterangan:
          'Kartu putih; sukses, info, peringatan, galat; kabar masuk navy. '
          'Galat dan toast beraksi tidak hilang sendiri.',
      anak: [
        ToastSidik(
          jenis: JenisToast.sukses,
          judul: 'Draf tersimpan',
          isi: 'Lembar kerja pH Meter disimpan di HP ini.',
          onTutup: () {},
        ),
        ToastSidik(
          jenis: JenisToast.info,
          judul: 'Jadwal teknisi tersimpan',
          isi: 'Pelanggan diberi tahu lewat aplikasinya.',
          aksi: 'Lihat',
          onAksi: () {},
          onTutup: () {},
        ),
        ToastSidik(
          jenis: JenisToast.peringatan,
          judul: 'Server lambat',
          isi: 'Permintaan masih jalan. Jangan tutup aplikasi.',
          onTutup: () {},
        ),
        ToastSidik(
          jenis: JenisToast.galat,
          judul: 'Gagal mengirim',
          isi: 'Tanpa koneksi. Dicoba lagi otomatis.',
          aksi: 'Coba lagi',
          onAksi: () {},
          onTutup: () {},
        ),
        ToastSidik(
          jenis: JenisToast.kabar,
          judul: 'Lembar kerja baru masuk',
          isi: '1 lembar kerja baru masuk antrean approval',
          aksi: 'Buka',
          onAksi: () {},
          onTutup: () {},
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TombolSidik(
              label: 'Toast sukses',
              ragam: RagamTombolSidik.sekunder,
              onPressed: () => tampilkanToast(
                context,
                jenis: JenisToast.sukses,
                judul: 'Draf tersimpan',
                isi: 'Hilang sendiri 4 detik.',
              ),
            ),
            TombolSidik(
              label: 'Toast galat',
              ragam: RagamTombolSidik.sekunder,
              onPressed: () => tampilkanToast(
                context,
                jenis: JenisToast.galat,
                judul: 'Gagal mengirim',
                isi: 'Tetap sampai ditutup.',
                aksi: 'Coba lagi',
                onAksi: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// L2: dialog konfirmasi dan lembar bawah.
class _BagianDialogLembar extends StatelessWidget {
  const _BagianDialogLembar();

  @override
  Widget build(BuildContext context) {
    final u = WarnaUmpanBalikBiruAwan.of(context);
    return _Bagian(
      judul: 'DialogSidik dan LembarBawahSidik',
      keterangan:
          'Dialog: aksi berkata kerja jelas, bahaya merah. Lembar bawah: '
          'maksimal 80 % layar, usap turun atau ketuk latar untuk menutup.',
      anak: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: u.scrim,
            borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: DialogSidik(
                ikon: Icons.send_outlined,
                judul: 'Kirim untuk approval?',
                isi:
                    'Lembar kerja tidak bisa diubah setelah dikirim, kecuali '
                    'admin meminta revisi.',
                aksi: 'Kirim',
                onAksi: () {},
                batal: 'Batal',
                onBatal: () {},
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: u.scrim,
            borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: DialogSidik(
                ikon: Icons.delete_outline,
                judul: 'Hapus folder ini?',
                isi:
                    'Berkas di dalamnya ikut terhapus. Sertifikat terbit tidak '
                    'terpengaruh.',
                aksi: 'Hapus',
                onAksi: () {},
                batal: 'Batal',
                onBatal: () {},
                bahaya: true,
              ),
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TombolSidik(
              label: 'Buka dialog',
              ragam: RagamTombolSidik.sekunder,
              onPressed: () => tampilkanDialogSidik(
                context,
                ikon: Icons.send_outlined,
                judul: 'Kirim untuk approval?',
                isi: 'Lembar kerja tidak bisa diubah setelah dikirim.',
                aksi: 'Kirim',
                batal: 'Batal',
              ),
            ),
            TombolSidik(
              label: 'Buka lembar bawah',
              ragam: RagamTombolSidik.sekunder,
              onPressed: () => tampilkanLembarBawahSidik<void>(
                context,
                judul: 'Kirim sertifikat lewat',
                bangun: (_) => const Text('Email, WhatsApp, atau tautan.'),
              ),
            ),
          ],
        ),
        LembarBawahSidik(
          judul: 'Kirim sertifikat lewat',
          onTutup: () {},
          child: Text(
            'Isi lembar bergulir; tombol utama penuh di bawah isi.',
            style: HurufBiruAwan.keterangan,
          ),
        ),
      ],
    );
  }
}

/// L2: banner (menempel di bawah kepala layar, bukan melayang).
class _BagianBanner extends StatelessWidget {
  const _BagianBanner();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'BannerSidik',
      keterangan:
          'Tanpa koneksi (navy), pembaruan (langit + tombol navy), peringatan '
          'data (kuning tipis).',
      anak: [
        const BannerSidik.tanpaKoneksi(
          teks: 'Tanpa koneksi. Data terakhir 08.42',
        ),
        BannerSidik.pembaruan(
          teks: 'Versi baru tersedia',
          aksi: 'Pasang',
          onAksi: () {},
        ),
        BannerSidik.peringatan(
          teks: 'Standar acuan Buffer pH 10,01 berakhir dalam 12 hari.',
          onTutup: () {},
        ),
      ],
    );
  }
}

/// L2: keadaan memuat, kosong, dan galat.
class _BagianKeadaan extends StatelessWidget {
  const _BagianKeadaan();

  @override
  Widget build(BuildContext context) {
    return _Bagian(
      judul: 'KeadaanSidik',
      keterangan:
          'Kosong: ubin langit + satu aksi. Galat: pesan apa adanya + "Coba '
          'lagi". Memuat: kerangka (denyut terbatas) atau spinner > 400 ms.',
      anak: [
        KeadaanKosong(
          judul: 'Belum ada draf',
          isi:
              'Lembar kerja yang kamu simpan lewat Simpan draf menunggu di '
              'sini.',
          aksi: 'Mulai kalibrasi',
          onAksi: () {},
        ),
        KeadaanGalat(
          judul: 'Gagal memuat antrean',
          isi: 'Periksa koneksi lalu coba lagi. Data terakhir tetap tampil.',
          aksi: 'Coba lagi',
          onAksi: () {},
        ),
        const KeadaanMemuat.kerangka(baris: 2, label: 'Memuat antrean'),
        const KeadaanMemuat.spinner(label: 'Memuat sertifikat'),
      ],
    );
  }
}
