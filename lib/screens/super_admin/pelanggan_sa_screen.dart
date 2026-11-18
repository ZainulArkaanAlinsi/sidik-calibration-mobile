import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/super_admin_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'hak_super_admin.dart';
import 'pelanggan_detail_screen.dart';
import 'widgets/pesan_layar.dart';

/// Pelanggan & anggota — daftar perusahaan pelanggan (cari + paginasi) yang
/// membuka detail anggota/undangan/PIC.
///
/// Layar ini hanya PINTU ke detail anggota. Tambah/ubah/hapus data pelanggan
/// tetap di layar Pelanggan yang sudah ada (Kelola lab) dan tidak diubah.
class PelangganSaScreen extends ConsumerStatefulWidget {
  const PelangganSaScreen({super.key});

  @override
  ConsumerState<PelangganSaScreen> createState() => _PelangganSaScreenState();
}

class _PelangganSaScreenState extends ConsumerState<PelangganSaScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;
  bool _memuatLagi = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _cariBerubah(String kata) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(pelangganSaProvider.notifier).cari(kata);
    });
  }

  Future<void> _muatLagi() async {
    if (_memuatLagi) return;
    setState(() => _memuatLagi = true);
    try {
      await ref.read(pelangganSaProvider.notifier).muatLebihBanyak();
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Tanpa izin: layar terkunci dan server TIDAK ditanya apa pun (provider
    // daftar bahkan tidak dibuat).
    if (!ref.bolehLihatAnggota) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.saPelJudul)),
        body: PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin),
      );
    }

    final async = ref.watch(pelangganSaProvider);
    final ctl = ref.read(pelangganSaProvider.notifier);
    final data = async.value;

    final int isi;
    final Widget Function(BuildContext, int) bangunIsi;
    if (data != null && data.items.isNotEmpty) {
      isi = data.items.length + (data.adaLagi ? 1 : 0);
      bangunIsi = (context, i) {
        if (i == data.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: AppButton(
                label: l10n.saMuatLagi,
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                isLoading: _memuatLagi,
                onPressed: _muatLagi,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _KartuPelanggan(pelanggan: data.items[i]),
        );
      };
    } else if (data != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.business_outlined,
          teks: l10n.saPelKosong,
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
              : l10n.saPelGagal,
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saPelJudul)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          maksimum: 720,
          child: RefreshIndicator(
            onRefresh: ctl.muatUlang,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: isi + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Semantics(
                      label: l10n.saPelCari,
                      child: TextField(
                        key: const Key('cari-pelanggan'),
                        controller: _cari,
                        onChanged: _cariBerubah,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.saPelCari,
                        ),
                      ),
                    ),
                  );
                }
                return bangunIsi(context, i - 1);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuPelanggan extends StatelessWidget {
  const _KartuPelanggan({required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final kontak = [
      if (pelanggan.contactPerson.trim().isNotEmpty)
        pelanggan.contactPerson.trim(),
      if (pelanggan.telepon.trim().isNotEmpty) pelanggan.telepon.trim(),
    ].join(' · ');

    return Card(
      child: InkWell(
        key: Key('pelanggan-${pelanggan.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PelangganDetailScreen(pelanggan: pelanggan),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pelanggan.nama,
                        style: tema.textTheme.titleSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (kontak.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          kontak,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      // Hitungan dari SERVER (kontrak §3.6); server lama tanpa
                      // hitungan jatuh ke jumlah alat saja.
                      Text(
                        pelanggan.alatCount != null &&
                                pelanggan.sertifikatCount != null &&
                                pelanggan.anggotaAktifCount != null
                            ? l10n.saPelRingkas(
                                pelanggan.alatCount!,
                                pelanggan.sertifikatCount!,
                                pelanggan.anggotaAktifCount!,
                              )
                            : l10n.custEquipmentCount(pelanggan.jumlahAlat),
                        key: Key('ringkas-${pelanggan.id}'),
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Ada alat/sertifikat tetapi tidak ada satu orang pun
                      // yang bisa melihatnya: tonjolkan, dengan jalan keluar
                      // (Undang anggota) di detail.
                      if (pelanggan.tanpaAkun) ...[
                        const SizedBox(height: AppSpacing.xs),
                        StatusBadge(
                          key: Key('tanpa-akun-${pelanggan.id}'),
                          label: l10n.saPelTanpaAkun,
                          tone: BadgeTone.warning,
                          icon: Icons.person_off_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
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
            SkeletonBox(height: 16, width: 180),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 120),
          ],
        ),
      ),
    );
  }
}
