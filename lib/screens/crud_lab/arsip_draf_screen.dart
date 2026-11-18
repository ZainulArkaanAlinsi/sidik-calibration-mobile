import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/arsip_draf.dart';
import '../../models/order_kelola.dart' show tanggalDariServer;
import '../../providers/arsip_draf_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../super_admin/widgets/dialog_isian.dart';
import '../super_admin/widgets/format_sa.dart';
import '../super_admin/widgets/pesan_layar.dart';
import 'hak_crud_lab.dart';
import 'widgets/pesan_galat_crud.dart';

/// Arsip draf lembar kerja (admin/super admin): daftar draf yang diarsipkan,
/// dengan alasan dan siapa yang mengarsipkan, plus Pulihkan.
///
/// Mengarsipkan BUKAN hapus: pembacaan mentah dan nomor sesi tidak hilang.
/// Detail satu draf terarsip tetap `404` di server, jadi ringkasan di kartu
/// ini cukup untuk memutuskan memulihkan. Hanya untuk yang berizin
/// `kalibrasi.pulihkan` (kunci yang sama membuka daftarnya, `403 hanya_admin`
/// bagi peran lain).
class ArsipDrafScreen extends ConsumerStatefulWidget {
  const ArsipDrafScreen({super.key});

  @override
  ConsumerState<ArsipDrafScreen> createState() => _ArsipDrafScreenState();
}

class _ArsipDrafScreenState extends ConsumerState<ArsipDrafScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;
  bool _memuatLagi = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  ArsipDrafController get _ctl => ref.read(arsipDrafProvider.notifier);

  void _cariBerubah(String kata) {
    _debounce?.cancel();
    // 400 ms: mencari tiap ketikan menembak API tiap huruf.
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _ctl.cariKata(kata);
    });
  }

  Future<void> _muatLagi() async {
    if (_memuatLagi) return;
    setState(() => _memuatLagi = true);
    try {
      await _ctl.muatLebihBanyak();
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  Future<void> _pulihkan(DrafArsipan d) async {
    final l10n = AppLocalizations.of(context);
    final nomor = d.nomorSesi ?? d.namaAlat;
    final ok = await tampilkanDialogIsian(
      context,
      judul: l10n.crudArsipPulihkanJudul(nomor),
      isi: l10n.crudArsipPulihkanIsi,
      labelKolom: l10n.crudAlasanOpsional,
      catatan: l10n.crudAlasanCatatanOpsional,
      labelAksi: l10n.crudArsipPulihkanAksi,
      wajib: false,
      panjangMaksimal: 400,
      pesanPanjang: l10n.crudAlasanPanjang,
      petakanGalat: (e) => pesanGalatCrud(l10n, e),
      aksi: (alasan) async {
        final token = await ref.read(tokenStorageProvider).read();
        if (token == null) throw const TokenHilangException();
        await ref
            .read(arsipDrafServiceProvider)
            .pulihkan(token, d.id, alasan: alasan.isEmpty ? null : alasan);
      },
      saatGalat: (e) {
        // `tidak_diarsipkan`/404: daftar di layar sudah basi.
        if (perluMuatUlangCrud(e)) _ctl.muatUlang();
      },
    );
    if (ok) {
      _ctl.muatUlang();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.crudArsipPulihkanBerhasil)),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boleh = ref.bolehPulihkanDraf;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.crudArsipJudul)),
      body: SafeArea(
        top: false,
        child: !boleh
            ? PesanLayar(ikon: Icons.lock_outline, teks: l10n.crudTanpaIzin)
            : ReadableWidth(
                maksimum: 720,
                child: _Daftar(
                  cari: _cari,
                  saatCari: _cariBerubah,
                  memuatLagi: _memuatLagi,
                  saatMuatLagi: _muatLagi,
                  saatPulihkan: _pulihkan,
                ),
              ),
      ),
    );
  }
}

class _Daftar extends ConsumerWidget {
  const _Daftar({
    required this.cari,
    required this.saatCari,
    required this.memuatLagi,
    required this.saatMuatLagi,
    required this.saatPulihkan,
  });

  final TextEditingController cari;
  final ValueChanged<String> saatCari;
  final bool memuatLagi;
  final VoidCallback saatMuatLagi;
  final ValueChanged<DrafArsipan> saatPulihkan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final async = ref.watch(arsipDrafProvider);
    final ctl = ref.read(arsipDrafProvider.notifier);
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
                isLoading: memuatLagi,
                onPressed: saatMuatLagi,
              ),
            ),
          );
        }
        final d = data.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _KartuArsip(
            key: Key('kartu-arsip-${d.id}'),
            draf: d,
            saatPulihkan: () => saatPulihkan(d),
          ),
        );
      };
    } else if (data != null) {
      isi = 1;
      bangunIsi = (_, _) => SizedBox(
        height: 280,
        child: PesanLayar(
          ikon: Icons.inventory_2_outlined,
          teks: ctl.cari.isEmpty
              ? l10n.crudArsipKosong
              : l10n.crudArsipKosongCari,
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
              : pesanGalatCrudAtau(l10n, async.error!, l10n.crudArsipGagal),
          aksi: AppButton(
            label: l10n.saCobaLagi,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: ctl.muatUlang,
          ),
        ),
      );
    } else {
      isi = 3;
      bangunIsi = (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _KerangkaKartu(),
      );
    }

    return RefreshIndicator(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.crudArsipIntro,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    label: l10n.crudArsipCari,
                    child: TextField(
                      key: const Key('cari-arsip'),
                      controller: cari,
                      onChanged: saatCari,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.crudArsipCari,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return bangunIsi(context, i - 1);
        },
      ),
    );
  }
}

/// Galat memuat daftar: 403 `hanya_admin` dan kawan-kawannya memakai kalimat
/// khusus; selain itu kalimat umum daftar ([cadangan]).
String pesanGalatCrudAtau(
  AppLocalizations l10n,
  Object galat,
  String cadangan,
) {
  final pesan = pesanGalatCrud(l10n, galat);
  return pesan == l10n.saGalatUmum ? cadangan : pesan;
}

class _KartuArsip extends StatelessWidget {
  const _KartuArsip({super.key, required this.draf, required this.saatPulihkan});

  final DrafArsipan draf;
  final VoidCallback saatPulihkan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final d = draf;
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final nomor = (d.nomorSesi ?? '').isEmpty
        ? l10n.crudArsipTanpaNomor
        : d.nomorSesi!;
    final pada = tanggalDariServer(d.arsip.pada);
    final tgl = pada == null ? null : tanggalSa(context, pada);
    final oleh = (d.arsip.olehNama ?? '').trim();
    final jejak = oleh.isNotEmpty && tgl != null
        ? l10n.crudArsipOleh(oleh, tgl)
        : tgl != null
        ? l10n.crudArsipOlehTanpaNama(tgl)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nomor,
              style: tema.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              [
                d.namaAlat,
                if (d.nomorSeri.isNotEmpty) d.nomorSeri,
              ].where((e) => e.isNotEmpty).join(' · '),
              style: tema.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (d.namaPelanggan.isNotEmpty)
              Text(
                d.namaPelanggan,
                style: redup,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (d.namaTeknisi.isNotEmpty)
              Text(
                l10n.crudOrderTeknisiNama(d.namaTeknisi),
                style: redup,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.sm),
            if ((d.arsip.alasan ?? '').trim().isNotEmpty)
              Text(
                l10n.crudArsipAlasan(d.arsip.alasan!.trim()),
                style: tema.textTheme.bodySmall,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            if (jejak != null) Text(jejak, style: redup),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              button: true,
              label: '${l10n.crudArsipAksiPulihkan} $nomor',
              excludeSemantics: true,
              onTap: saatPulihkan,
              child: AppButton(
                key: Key('pulihkan-${d.id}'),
                label: l10n.crudArsipAksiPulihkan,
                icon: Icons.restore,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                onPressed: saatPulihkan,
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
            SkeletonBox(height: 12, width: 220),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 100),
          ],
        ),
      ),
    );
  }
}
