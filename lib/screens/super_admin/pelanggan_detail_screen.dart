import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/inisial_nama.dart';
import '../../l10n/app_localizations.dart';
import '../../models/anggota_pelanggan.dart';
import '../../models/customer.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/riwayat_alat_provider.dart';
import '../../providers/super_admin_provider.dart';
import '../../services/kode_galat.dart' show kodeGalatApi;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../settings/undang_anggota_dialog.dart' show bukaUndangAnggota;
import 'hak_super_admin.dart';
import 'widgets/bagian_alat_pelanggan.dart';
import 'widgets/dialog_isian.dart';
import 'widgets/pemicu_gulir.dart';
import 'widgets/pesan_galat_sa.dart';
import 'widgets/pesan_layar.dart';

/// Detail pelanggan di sisi lab: anggota, undangan menunggu, PIC admin.
///
/// Semua aturan ("PIC utama terakhir", "bisa dicabut") datang dari SERVER
/// lewat flag di respons — layar tidak menghitungnya sendiri. Tombol yang
/// sempat tampil tapi ditolak server dijawab dengan kalimat yang menyebut
/// jalan keluarnya, lalu daftar dimuat ulang.
///
/// **Tidak ada Hapus anggota.** Anggota dicabut (dinonaktifkan) dan tetap
/// tampil sebagai jejak.
class PelangganDetailScreen extends ConsumerWidget {
  const PelangganDetailScreen({super.key, required this.pelanggan});

  final Customer pelanggan;

  void _segarkan(WidgetRef ref) =>
      ref.invalidate(anggotaPelangganProvider(pelanggan.id));

  Future<String> _token(WidgetRef ref) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    return token;
  }

  Future<void> _cabut(
    BuildContext context,
    WidgetRef ref,
    AnggotaPelanggan a,
    DataAnggotaPelanggan d,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nama = a.orang?.nama.isNotEmpty == true
        ? a.orang!.nama
        : l10n.saTanpaNamaAnggota;

    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.saCabutJudul(nama),
      isi: l10n.saCabutIsi(
        nama,
        d.customerNama.isEmpty ? pelanggan.nama : d.customerNama,
      ),
      labelKolom: l10n.saAlasanWajib,
      catatan: l10n.saAlasanCatatan,
      labelAksi: l10n.saCabutAkses,
      destruktif: true,
      untukAnggota: true,
      panjangMinimal: 3,
      pesanPendek: l10n.saAlasanPendek,
      pesanPanjang: l10n.saAlasanPanjang,
      aksi: (alasan) async => ref
          .read(anggotaPelangganServiceProvider)
          .cabut(await _token(ref), pelanggan.id, a.id, alasan: alasan),
      // Daftar basi (sudah dicabut orang lain / PIC terakhir berubah): muat
      // ulang di belakang dialog supaya tombol yang sudah tidak berlaku hilang.
      saatGalat: (e) {
        if (perluMuatUlang(e) || kodeGalatApi(e) == KodeSa.picUtamaTerakhir) {
          _segarkan(ref);
        }
      },
    );
    if (ok) {
      _segarkan(ref);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.saCabutBerhasil)));
    }
  }

  Future<void> _batalkanUndangan(
    BuildContext context,
    WidgetRef ref,
    UndanganMenunggu u,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saBatalkanJudul),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email di ISI (bisa digulir), bukan di judul: email yang sangat
              // panjang di judul tidak bisa digulir dan meluap di layar kecil.
              Text(l10n.saBatalkanUntuk(u.email)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.saBatalkanIsi),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.saBatalkanTidak),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.saBatalkanUndangan),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    String pesan;
    try {
      await ref
          .read(anggotaPelangganServiceProvider)
          .batalkanUndangan(await _token(ref), pelanggan.id, u.id);
      pesan = l10n.saBatalkanBerhasil;
    } catch (e) {
      pesan = pesanGalatSa(l10n, e);
    }
    // Berhasil atau basi (404): daftar diambil ulang dari server.
    _segarkan(ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ubahPic(
    BuildContext context,
    WidgetRef ref,
    DataAnggotaPelanggan d,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final hasil = await showDialog<_HasilPic>(
      context: context,
      builder: (_) => _DialogPicAdmin(
        customerId: pelanggan.id,
        picSekarang: d.picAdmin?.id,
      ),
    );
    if (hasil == null) return;

    _segarkan(ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hasil.dilepas ? l10n.saPicDilepas : l10n.saPicBerhasil),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehLihatAnggota;
    final bolehAlat = ref.bolehLihatAlatPelanggan;
    // Tanpa izin server TIDAK ditanya: provider anggota tidak dibuat.
    final async = boleh
        ? ref.watch(anggotaPelangganProvider(pelanggan.id))
        : null;
    // Hitungan & penanda server (kontrak §3.6). Selama belum tiba (atau gagal)
    // dipakai baris dari daftar: ringkasan tidak pernah kosong.
    final segar = boleh
        ? ref.watch(pelangganDetailSaProvider(pelanggan.id)).value
        : null;
    final sekarang = segar ?? pelanggan;

    final Widget isi;
    if (async == null) {
      isi = PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin);
    } else if (async.value case final d?) {
      isi = _Isi(
        data: d,
        pelanggan: sekarang,
        saatCabut: (a) => _cabut(context, ref, a, d),
        saatBatalkan: (u) => _batalkanUndangan(context, ref, u),
        saatUbahPic: () => _ubahPic(context, ref, d),
        saatUndang: () async {
          await bukaUndangAnggota(context, pelanggan);
          _segarkan(ref);
          ref.invalidate(pelangganDetailSaProvider(pelanggan.id));
        },
        saatSegarkan: () async {
          _segarkan(ref);
          ref.invalidate(pelangganDetailSaProvider(pelanggan.id));
          if (bolehAlat) {
            ref.read(alatPelangganProvider(pelanggan.id).notifier).muatUlang();
          }
          await ref.read(anggotaPelangganProvider(pelanggan.id).future);
        },
      );
    } else if (async.hasError) {
      final galat = async.error!;
      isi = PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: galat is TokenHilangException
            ? l10n.historySessionExpired
            : pesanGalatDetail(l10n, galat),
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: () => _segarkan(ref),
        ),
      );
    } else {
      isi = const _KerangkaDetail();
    }

    return Scaffold(
      appBar: AppBar(title: Text(pelanggan.nama)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(maksimum: 720, child: isi),
      ),
    );
  }
}

/// 404 → kalimat "mungkin sudah berubah"; selain itu kalimat gagal-muat
/// khusus layar ini (pesan server untuk 5xx tidak berguna bagi pembaca).
String pesanGalatDetail(AppLocalizations l10n, Object galat) {
  final pesan = pesanGalatSa(l10n, galat);
  return pesan == l10n.saGalatUmum ? l10n.saDetGagal : pesan;
}

class _Isi extends ConsumerWidget {
  const _Isi({
    required this.data,
    required this.pelanggan,
    required this.saatCabut,
    required this.saatBatalkan,
    required this.saatUbahPic,
    required this.saatUndang,
    required this.saatSegarkan,
  });

  final DataAnggotaPelanggan data;
  final Customer pelanggan;
  final void Function(AnggotaPelanggan) saatCabut;
  final void Function(UndanganMenunggu) saatBatalkan;
  final VoidCallback saatUbahPic;
  final VoidCallback saatUndang;
  final Future<void> Function() saatSegarkan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final bolehUndang = ref.bolehUndangAnggota;
    final bolehPic = ref.bolehUbahPicAdmin;
    final bolehCabut = ref.bolehCabutAnggota;
    final bolehAlat = ref.bolehLihatAlatPelanggan;

    return RefreshIndicator(
      onRefresh: saatSegarkan,
      // Alat dimuat per halaman (kursor) saat gulir mendekati ujung: daftar
      // alat pelanggan besar tidak pernah diminta sekaligus.
      child: PemicuGulir(
        // Tanpa izin `pelanggan.alat-lihat` pemicu gulir tidak menyentuh
        // provider alat sama sekali (membacanya saja sudah memanggil server).
        saatDekatAkhir: () {
          if (bolehAlat) {
            ref
                .read(alatPelangganProvider(pelanggan.id).notifier)
                .muatLebihBanyak();
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- ringkasan
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pelanggan.alatCount != null &&
                              pelanggan.sertifikatCount != null &&
                              pelanggan.anggotaAktifCount != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                l10n.saPelRingkas(
                                  pelanggan.alatCount!,
                                  pelanggan.sertifikatCount!,
                                  pelanggan.anggotaAktifCount!,
                                ),
                                key: const Key('ringkas-detail'),
                                style: tema.textTheme.titleSmall,
                              ),
                            ),
                          Text(
                            l10n.saDetKuota(data.jumlahAktif, data.maksAnggota),
                            key: const Key('kuota-anggota'),
                            style: tema.textTheme.bodyMedium,
                          ),
                          if (pelanggan.tanpaAkun) ...[
                            const SizedBox(height: AppSpacing.sm),
                            StatusBadge(
                              key: const Key('tanpa-akun-detail'),
                              label: l10n.saPelTanpaAkun,
                              tone: BadgeTone.warning,
                              icon: Icons.person_off_outlined,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.saDetTanpaAkunIsi,
                              style: tema.textTheme.bodySmall,
                            ),
                            if (bolehUndang) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                key: const Key('undang-cepat'),
                                label: l10n.undangAnggota,
                                icon: Icons.person_add_alt_1_outlined,
                                ringkas: true,
                                onPressed: saatUndang,
                              ),
                            ],
                          ],
                          if (pelanggan.namaNormalKosong) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.saDetNamaNormalKosong,
                              key: const Key('nama-normal-kosong'),
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.saDetPicAdmin,
                            style: tema.textTheme.labelMedium?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (data.picAdmin case final pic?) ...[
                            Text(
                              pic.nama.isEmpty ? (pic.email ?? '') : pic.nama,
                              key: const Key('pic-admin-nama'),
                              style: tema.textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((pic.email ?? '').isNotEmpty &&
                                pic.nama.isNotEmpty)
                              Text(
                                pic.email!,
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ] else
                            Text(
                              l10n.saDetPicAdminKosong,
                              key: const Key('pic-admin-kosong'),
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (bolehPic) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: l10n.saDetUbahPic,
                              icon: Icons.edit_outlined,
                              variant: AppButtonVariant.secondary,
                              ringkas: true,
                              onPressed: saatUbahPic,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // --- anggota
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.saAnggotaJudul,
                          style: tema.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (bolehUndang) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: l10n.undangAnggota,
                        icon: Icons.person_add_alt_1_outlined,
                        ringkas: true,
                        onPressed: saatUndang,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (data.anggota.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        l10n.saAnggotaKosong,
                        key: const Key('anggota-kosong'),
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final a in data.anggota)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _KartuAnggota(
                          anggota: a,
                          bolehCabut: bolehCabut,
                          saatCabut: () => saatCabut(a),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.lg),

                  // --- undangan menunggu
                  Text(l10n.saUndanganJudul, style: tema.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.undanganMenunggu.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        l10n.saUndanganKosong,
                        key: const Key('undangan-kosong'),
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final u in data.undanganMenunggu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _KartuUndangan(
                          undangan: u,
                          bolehBatalkan: bolehUndang,
                          saatBatalkan: () => saatBatalkan(u),
                        ),
                      ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              sliver: BagianAlatPelanggan(pelanggan: pelanggan),
            ),
          ],
        ),
      ),
    );
  }
}

String _tanggal(BuildContext context, DateTime? t) {
  if (t == null) return '-';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('d MMM yyyy', locale).format(t);
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nama});

  final String nama;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tema.colorScheme.secondaryContainer,
        ),
        child: Text(
          inisialNama(nama),
          style: tema.textTheme.labelLarge?.copyWith(
            color: tema.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _KartuAnggota extends StatelessWidget {
  const _KartuAnggota({
    required this.anggota,
    required this.bolehCabut,
    required this.saatCabut,
  });

  final AnggotaPelanggan anggota;
  final bool bolehCabut;
  final VoidCallback saatCabut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final orang = anggota.orang;
    final nama = (orang?.nama ?? '').trim().isEmpty
        ? l10n.saTanpaNamaAnggota
        : orang!.nama;
    final tambahan = [
      if ((orang?.jabatan ?? '').isNotEmpty) orang!.jabatan!,
      if ((orang?.telepon ?? '').isNotEmpty) orang!.telepon!,
    ].join(' · ');

    final jejak = anggota.aktif
        ? l10n.saBergabung(_tanggal(context, anggota.bergabungPada))
        : (anggota.dinonaktifkanOleh != null
              ? l10n.saDinonaktifkanOleh(
                  _tanggal(context, anggota.dinonaktifkanPada),
                  anggota.dinonaktifkanOleh!.nama,
                )
              : l10n.saDinonaktifkanSaja(
                  _tanggal(context, anggota.dinonaktifkanPada),
                ));

    return Card(
      key: Key('anggota-${anggota.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(nama: nama),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        style: tema.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((orang?.email ?? '').isNotEmpty)
                        Text(
                          orang!.email,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (tambahan.isNotEmpty)
                        Text(
                          tambahan,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusBadge(
                  label: anggota.peran == PeranAnggota.picUtama
                      ? l10n.saPeranPicUtama
                      : l10n.saPeranStaf,
                  tone: anggota.peran == PeranAnggota.picUtama
                      ? BadgeTone.info
                      : BadgeTone.neutral,
                  icon: Icons.badge_outlined,
                ),
                StatusBadge(
                  label: anggota.aktif ? l10n.statusAktif : l10n.statusNonaktif,
                  tone: anggota.aktif ? BadgeTone.success : BadgeTone.neutral,
                  icon: anggota.aktif
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              jejak,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            if (anggota.aktif && anggota.picUtamaTerakhir) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.saPicTerakhir,
                      key: Key('pic-terakhir-${anggota.id}'),
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (anggota.aktif && anggota.bisaDicabut && bolehCabut) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                button: true,
                label: '${l10n.saCabutAkses} $nama',
                onTap: saatCabut,
                excludeSemantics: true,
                child: AppButton(
                  label: l10n.saCabutAkses,
                  icon: Icons.person_remove_outlined,
                  variant: AppButtonVariant.secondary,
                  ringkas: true,
                  onPressed: saatCabut,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KartuUndangan extends StatelessWidget {
  const _KartuUndangan({
    required this.undangan,
    required this.bolehBatalkan,
    required this.saatBatalkan,
  });

  final UndanganMenunggu undangan;
  final bool bolehBatalkan;
  final VoidCallback saatBatalkan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final oleh = undangan.diundangOleh?.nama ?? '';

    return Card(
      key: Key('undangan-${undangan.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              undangan.email,
              style: tema.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusBadge(
                  label: undangan.peran == PeranAnggota.picUtama
                      ? l10n.saPeranPicUtama
                      : l10n.saPeranStaf,
                  tone: undangan.peran == PeranAnggota.picUtama
                      ? BadgeTone.info
                      : BadgeTone.neutral,
                  icon: Icons.badge_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.saUndanganBerlaku(
                _tanggal(context, undangan.kedaluwarsaPada),
              ),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            if (oleh.isNotEmpty)
              Text(
                l10n.saUndanganOleh(oleh),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (bolehBatalkan) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                button: true,
                label: '${l10n.saBatalkanUndangan} ${undangan.email}',
                onTap: saatBatalkan,
                excludeSemantics: true,
                child: AppButton(
                  label: l10n.saBatalkanUndangan,
                  icon: Icons.cancel_outlined,
                  variant: AppButtonVariant.secondary,
                  ringkas: true,
                  onPressed: saatBatalkan,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KerangkaDetail extends StatelessWidget {
  const _KerangkaDetail();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, width: 200),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(height: 12, width: 100),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 16, width: 160),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 16, width: 160),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 12, width: 220),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HasilPic {
  const _HasilPic({required this.dilepas});

  final bool dilepas;
}

/// Pilih PIC admin lab untuk pelanggan ini: satu dari admin AKTIF lab, atau
/// lepas. Admin dimuat dari `GET /users?role=admin&status=aktif`; yang
/// menjamin "admin aktif lab ini" tetap server (`422 errors.user_id`).
class _DialogPicAdmin extends ConsumerStatefulWidget {
  const _DialogPicAdmin({required this.customerId, required this.picSekarang});

  final int customerId;
  final int? picSekarang;

  @override
  ConsumerState<_DialogPicAdmin> createState() => _DialogPicAdminState();
}

class _DialogPicAdminState extends ConsumerState<_DialogPicAdmin> {
  late final Future<List<User>> _admin = _muat();
  bool _mengirim = false;
  String? _galat;

  Future<List<User>> _muat() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();
    final layanan = ref.read(penggunaSaServiceProvider);

    // Admin satu lab jumlahnya kecil; tetap ikuti paginasi (batas aman 5).
    final semua = <User>[];
    for (var h = 1; h <= 5; h++) {
      final hal = await layanan.daftar(
        token,
        peran: 'admin',
        status: 'aktif',
        halaman: h,
      );
      semua.addAll(hal.items);
      if (!hal.adaLagi) break;
    }
    return semua;
  }

  Future<void> _pilih(int? userId) async {
    if (_mengirim) return;
    setState(() {
      _mengirim = true;
      _galat = null;
    });
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();
      await ref
          .read(anggotaPelangganServiceProvider)
          .setPicAdmin(token, widget.customerId, userId);
      if (!mounted) return;
      Navigator.of(context).pop(_HasilPic(dilepas: userId == null));
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _mengirim = false;
        _galat = pesanGalatSa(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.saPicJudul),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.saPicIsi, style: tema.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<User>>(
                future: _admin,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      l10n.saPicGagalMuat,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.error,
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final daftar = snap.data!;
                  if (daftar.isEmpty) {
                    return Text(
                      l10n.saPicKosong,
                      style: tema.textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: [
                      for (final u in daftar)
                        ListTile(
                          key: Key('pic-${u.id}'),
                          contentPadding: EdgeInsets.zero,
                          enabled: !_mengirim,
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(
                            u.nama,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            u.email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: u.id == widget.picSekarang
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => _pilih(u.id),
                        ),
                    ],
                  );
                },
              ),
              if (_galat != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _galat!,
                    key: const Key('galat-pic'),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _mengirim ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.saBatal),
        ),
        if (widget.picSekarang != null)
          TextButton(
            key: const Key('lepas-pic'),
            onPressed: _mengirim ? null : () => _pilih(null),
            child: Text(l10n.saPicLepas),
          ),
      ],
    );
  }
}
