import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/order_kelola.dart' show tanggalDariServer;
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/kategori_kelola_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../super_admin/widgets/dialog_isian.dart';
import '../super_admin/widgets/format_sa.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'hak_crud_lab.dart';
import 'widgets/dialog_konfirmasi_crud.dart';
import 'widgets/pesan_galat_crud.dart';

/// Kategori alat: daftar (termasuk yang nonaktif), tambah, ubah nama,
/// nonaktifkan/aktifkan kembali, dan hapus yang tidak dipakai (kontrak CRUD
/// lengkap §2). Hanya yang berizin `kategori.kelola` (admin, super admin).
///
/// - **`kode` tidak pernah berubah** dan tidak diketik: server membentuknya
///   dari nama.
/// - **Nonaktif ≠ hapus**: nonaktif hanya berhenti ditawarkan untuk data baru;
///   alat lama tetap menampilkannya. Hapus hanya bila tidak dipakai apa pun,
///   dan tombolnya hanya muncul untuk kategori yang hitungannya nol (server
///   memeriksa penuh: `422 kategori_dipakai`).
/// - Semua aksi mengambil ulang daftar dari server sesudah sukses.
class KategoriKelolaScreen extends ConsumerStatefulWidget {
  const KategoriKelolaScreen({super.key});

  @override
  ConsumerState<KategoriKelolaScreen> createState() =>
      _KategoriKelolaScreenState();
}

/// Saringan sisi aplikasi (daftarnya kecil dan tidak dipaginasi server).
enum _Saring { semua, aktif, nonaktif }

class _KategoriKelolaScreenState extends ConsumerState<KategoriKelolaScreen> {
  _Saring _saring = _Saring.semua;

  KategoriKelolaController get _ctl => ref.read(kategoriKelolaProvider.notifier);

  Future<String> _token() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  void _kabari(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  void _kalauBasi(Object e) {
    if (perluMuatUlangCrud(e)) _ctl.muatUlang();
  }

  Future<void> _tambah() async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudKategoriFormTambahJudul,
      isi: l10n.crudKategoriFormTambahIsi,
      labelKolom: l10n.crudKategoriNamaLabel,
      catatan: l10n.crudKategoriNamaCatatan,
      labelAksi: l10n.crudKategoriSimpanTambah,
      satuBaris: true,
      panjangMinimal: 2,
      panjangMaksimal: 100,
      pesanPendek: l10n.crudKategoriNamaPendek,
      pesanPanjang: l10n.crudKategoriNamaPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e, simpanBaru: true),
      aksi: (nama) async => ref
          .read(kategoriKelolaServiceProvider)
          .buat(await _token(), nama: nama),
      saatGalat: _kalauBasi,
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudKategoriBerhasilBuat);
    }
  }

  Future<void> _ubahNama(Category k) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudKategoriFormUbahJudul(k.nama),
      isi: l10n.crudKategoriFormUbahIsi,
      labelKolom: l10n.crudKategoriNamaLabel,
      labelAksi: l10n.crudKategoriSimpanUbah,
      nilaiAwal: k.nama,
      satuBaris: true,
      panjangMinimal: 2,
      panjangMaksimal: 100,
      pesanPendek: l10n.crudKategoriNamaPendek,
      pesanPanjang: l10n.crudKategoriNamaPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e),
      aksi: (nama) async => ref
          .read(kategoriKelolaServiceProvider)
          .ubahNama(await _token(), k.kode, nama: nama),
      saatGalat: _kalauBasi,
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudKategoriBerhasilUbah);
    }
  }

  Future<void> _nonaktifkan(Category k) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudKategoriNonaktifJudul(k.nama),
      isi: l10n.crudKategoriNonaktifIsi,
      labelKolom: l10n.crudAlasanOpsional,
      catatan: l10n.crudAlasanCatatanOpsional,
      labelAksi: l10n.crudKategoriNonaktifAksi,
      wajib: false,
      destruktif: true,
      panjangMaksimal: 400,
      pesanPanjang: l10n.crudAlasanPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e),
      aksi: (alasan) async => ref
          .read(kategoriKelolaServiceProvider)
          .nonaktifkan(
            await _token(),
            k.kode,
            alasan: alasan.isEmpty ? null : alasan,
          ),
      saatGalat: _kalauBasi,
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudKategoriNonaktifBerhasil);
    }
  }

  Future<void> _aktifkan(Category k) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogKonfirmasiCrud(
      context,
      judul: l10n.crudKategoriAktifJudul(k.nama),
      isi: l10n.crudKategoriAktifIsi,
      labelAksi: l10n.crudKategoriAktifAksi,
      destruktif: false,
      aksi: () async => ref
          .read(kategoriKelolaServiceProvider)
          .aktifkan(await _token(), k.kode),
      saatGalat: _kalauBasi,
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudKategoriAktifBerhasil);
    }
  }

  Future<void> _hapus(Category k) async {
    final l10n = AppLocalizations.of(context);
    final ok = await tampilkanDialogKonfirmasiCrud(
      context,
      judul: l10n.crudKategoriHapusJudul(k.nama),
      isi: l10n.crudKategoriHapusIsi,
      labelAksi: l10n.crudKategoriHapusAksi,
      aksi: () async => ref
          .read(kategoriKelolaServiceProvider)
          .hapus(await _token(), k.kode),
      saatGalat: (e) {
        // `kategori_dipakai`: hitungan di layar sudah basi — muat ulang.
        _ctl.muatUlang();
      },
    );
    if (ok) {
      _ctl.muatUlang();
      _kabari(l10n.crudKategoriHapusBerhasil);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehKelolaKategori;
    final papanKetikTerbuka = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudKategoriJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : Column(
                children: [
                  Expanded(
                    child: ReadableWidth(
                      maksimum: 720,
                      child: _Daftar(
                        saring: _saring,
                        saatSaring: (s) => setState(() => _saring = s),
                        saatUbahNama: _ubahNama,
                        saatNonaktifkan: _nonaktifkan,
                        saatAktifkan: _aktifkan,
                        saatHapus: _hapus,
                      ),
                    ),
                  ),
                  if (!papanKetikTerbuka)
                    SafeArea(
                      top: false,
                      child: ReadableWidth(
                        maksimum: 720,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: AppButton(
                            key: const Key('tambah-kategori'),
                            label: l10n.crudKategoriTambah,
                            icon: Icons.add,
                            onPressed: _tambah,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Daftar extends ConsumerWidget {
  const _Daftar({
    required this.saring,
    required this.saatSaring,
    required this.saatUbahNama,
    required this.saatNonaktifkan,
    required this.saatAktifkan,
    required this.saatHapus,
  });

  final _Saring saring;
  final ValueChanged<_Saring> saatSaring;
  final ValueChanged<Category> saatUbahNama;
  final ValueChanged<Category> saatNonaktifkan;
  final ValueChanged<Category> saatAktifkan;
  final ValueChanged<Category> saatHapus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(kategoriKelolaProvider);
    final ctl = ref.read(kategoriKelolaProvider.notifier);
    final semua = async.value;
    final tampil = semua == null
        ? null
        : [
            for (final k in semua)
              if (saring == _Saring.semua ||
                  (saring == _Saring.aktif && k.aktif) ||
                  (saring == _Saring.nonaktif && !k.aktif))
                k,
          ];

    final int isi;
    final Widget Function(BuildContext, int) bangunIsi;
    if (tampil != null && tampil.isNotEmpty) {
      isi = tampil.length;
      bangunIsi = (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KartuKategori(
          key: Key('kartu-kategori-${tampil[i].kode}'),
          kategori: tampil[i],
          saatUbahNama: saatUbahNama,
          saatNonaktifkan: saatNonaktifkan,
          saatAktifkan: saatAktifkan,
          saatHapus: saatHapus,
        ),
      );
    } else if (tampil != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.category_outlined,
          teks: saring == _Saring.semua
              ? l10n.crudKategoriKosong
              : l10n.crudKategoriKosongSaring,
        ),
      );
    } else if (async.hasError) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 320,
        child: PesanLayar(
          ikon: Icons.cloud_off_outlined,
          galat: true,
          teks: async.error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.crudKategoriGagal,
          aksi: AppButton(
            label: l10n.saCobaLagi,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: ctl.muatUlang,
          ),
        ),
      );
    } else {
      isi = 4;
      bangunIsi = (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KerangkaKartu(),
      );
    }

    final pilihan = <(_Saring, String)>[
      (_Saring.semua, l10n.crudKategoriSemua),
      (_Saring.aktif, StatusBadge.labelApi('aktif', l10n)),
      (_Saring.nonaktif, StatusBadge.labelApi('nonaktif', l10n)),
    ];

    return RefreshIndicator(
      onRefresh: ctl.muatUlang,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: isi + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (nilai, label) in pilihan)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          key: Key('saring-kategori-${nilai.name}'),
                          label: Text(label),
                          selected: saring == nilai,
                          onSelected: (_) => saatSaring(nilai),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
          return bangunIsi(context, i - 1);
        },
      ),
    );
  }
}

class _KartuKategori extends StatelessWidget {
  const _KartuKategori({
    super.key,
    required this.kategori,
    required this.saatUbahNama,
    required this.saatNonaktifkan,
    required this.saatAktifkan,
    required this.saatHapus,
  });

  final Category kategori;
  final ValueChanged<Category> saatUbahNama;
  final ValueChanged<Category> saatNonaktifkan;
  final ValueChanged<Category> saatAktifkan;
  final ValueChanged<Category> saatHapus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final k = kategori;

    final menu = <(String, String)>[
      ('ubah', l10n.crudKategoriAksiUbahNama),
      if (k.aktif)
        ('nonaktifkan', l10n.crudKategoriAksiNonaktifkan)
      else
        ('aktifkan', l10n.crudKategoriAksiAktifkan),
      // Hapus hanya untuk yang tidak dipakai apa pun (hitungan server).
      if (k.bisaDihapus) ('hapus', l10n.crudKategoriAksiHapus),
    ];

    void pilih(String kode) {
      switch (kode) {
        case 'ubah':
          saatUbahNama(k);
        case 'nonaktifkan':
          saatNonaktifkan(k);
        case 'aktifkan':
          saatAktifkan(k);
        case 'hapus':
          saatHapus(k);
      }
    }

    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final sejak = tanggalDariServer(k.nonaktifPada);
    final nonaktifSejak = sejak == null ? null : tanggalSa(context, sejak);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.nama,
                        style: tema.textTheme.titleSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.crudKategoriKode(k.kode),
                        style: redup?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('menu-kategori-${k.kode}'),
                  tooltip: l10n.saAksiUntuk(k.nama),
                  icon: const Icon(Icons.more_vert),
                  onSelected: pilih,
                  itemBuilder: (_) => [
                    for (final (kode, label) in menu)
                      PopupMenuItem<String>(value: kode, child: Text(label)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusBadge.fromApi(k.aktif ? 'aktif' : 'nonaktif'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                [
                  l10n.crudPemakaiAlat(k.jumlahAlat),
                  l10n.crudPemakaiKemampuan(k.jumlahKemampuan),
                  if (k.jumlahTanpaCmc > 0)
                    l10n.crudKategoriTanpaCmc(k.jumlahTanpaCmc),
                  if (!k.aktif && nonaktifSejak != null)
                    l10n.crudKategoriNonaktifSejak(nonaktifSejak),
                ].join(' · '),
                style: redup,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KerangkaKartu extends StatelessWidget {
  const _KerangkaKartu();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 16, width: 160),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 100),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 220),
          ],
        ),
      ),
    );
  }
}
