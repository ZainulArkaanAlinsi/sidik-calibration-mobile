import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/history_provider.dart';
import '../../widgets/notification_bell.dart';
import '../auth/widgets/neu.dart';
import 'perhitungan_screen.dart';
import '../../widgets/sidik_loader.dart';

/// Antrean approval admin (spesifikasi poin 12A, rencana §2.1).
///
/// **Teknisi banyak, admin satu pintu**: semua kiriman dari semua akun teknisi
/// masuk ke sini, bukan cuma punya admin sendiri. Bedanya dari layar Riwayat
/// itu di query — Riwayat nggak nyaring status, ini `status=menunggu_approval`.
///
/// Tap satu baris → lembar PERHITUNGAN, tempat admin beneran mutusin.
///
/// **Kulitnya soft-UI (`auth/widgets/neu.dart`), sama kayak layar Login.**
/// Sebelumnya layar ini pakai `Card`/`ListTile`/`FilterChip` Material polos
/// sementara sisa app-nya neumorphism — jadi panel admin kerasa "beda aplikasi"
/// dan paling nggak digarap, padahal ini justru layar yang dipelototin admin
/// tiap hari. Yang diubah cuma tampilan: penyaring, urutan, dan navigasinya
/// persis seperti sebelumnya.
class AntreanApprovalScreen extends ConsumerWidget {
  const AntreanApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = NeuColors.of(context);
    final antrean = ref.watch(antreanApprovalProvider);

    return Scaffold(
      // Latar layar & isi kartu sengaja sewarna — di soft-UI kedalaman datang
      // dari bayangan, bukan beda warna. Lihat catatan di `NeuColors.base`.
      backgroundColor: c.base,
      appBar: AppBar(
        backgroundColor: c.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          l10n.antreanTitle,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.md)],
      ),
      body: RefreshIndicator(
        color: c.accent,
        backgroundColor: c.base,
        onRefresh: () =>
            ref.read(antreanApprovalProvider.notifier).muatUlang(),
        child: switch (antrean) {
          AsyncData(:final value) =>
            value.isEmpty ? const _Kosong() : _Daftar(items: value),
          AsyncError() => _Gagal(
            onCobaLagi: () =>
                ref.read(antreanApprovalProvider.notifier).muatUlang(),
          ),
          _ => const Center(child: SidikLoader(size: 88)),
        },
      ),
    );
  }
}

/// Antrean dikelompokkan per PT.
///
/// Admin mikirnya per perusahaan — "beresin punya Maju Jaya dulu, sekalian
/// sertifikatnya sekali kirim" — bukan per teknisi atau per tanggal. Daftar
/// datar yang nyampur semua PT maksa dia nyisir tiap baris nyari yang
/// sekumpulan, dan itu yang bikin antrean kerasa ribet.
///
/// Penyaringnya cuma nongol kalau ada LEBIH DARI SATU PT: satu chip buat satu
/// pilihan itu kontrol yang nggak ngontrol apa-apa, cuma makan tempat.
class _Daftar extends StatefulWidget {
  const _Daftar({required this.items});

  final List<CalibrationHistoryItem> items;

  @override
  State<_Daftar> createState() => _DaftarState();
}

class _DaftarState extends State<_Daftar> {
  /// Null = semua PT.
  String? _pt;

  static const _tanpaNama = '—';

  String _namaPt(CalibrationHistoryItem i) => i.namaPelanggan ?? _tanpaNama;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Urut sesuai jumlah antrean, terbanyak duluan — PT yang paling numpuk
    // biasanya yang paling ditunggu.
    final jumlah = <String, int>{};
    for (final i in widget.items) {
      jumlah[_namaPt(i)] = (jumlah[_namaPt(i)] ?? 0) + 1;
    }
    final urutPt = jumlah.keys.toList()
      ..sort((a, b) {
        final selisih = jumlah[b]!.compareTo(jumlah[a]!);
        return selisih != 0 ? selisih : a.compareTo(b);
      });

    // PT yang lagi dipilih bisa ilang dari daftar (kiriman terakhirnya barusan
    // diproses). Jatuh balik ke "semua" daripada nampilin layar kosong yang
    // kelihatan kayak antreannya habis.
    final dipilih = urutPt.contains(_pt) ? _pt : null;

    final tampil = dipilih == null
        ? widget.items
        : widget.items.where((i) => _namaPt(i) == dipilih).toList();

    return Column(
      children: [
        if (urutPt.length > 1)
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                _Chip(
                  label: l10n.antreanSemuaPt(widget.items.length),
                  aktif: dipilih == null,
                  onTap: () => setState(() => _pt = null),
                ),
                for (final pt in urutPt)
                  _Chip(
                    label: pt,
                    jumlah: jumlah[pt],
                    aktif: dipilih == pt,
                    // Ditekan lagi = balik ke semua. Tanpa itu, sekali
                    // nyaring admin kepaksa cari chip "Semua" buat keluar.
                    onTap: () =>
                        setState(() => _pt = dipilih == pt ? null : pt),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            itemCount: tampil.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _Kartu(item: tampil[i]),
          ),
        ),
      ],
    );
  }
}

/// Penyaring PT. Yang aktif diisi warna aksen, bukan sekadar ditenggelamkan:
/// di layar penuh permukaan sewarna, bayangan doang kurang kebaca sekilas —
/// dan ini kontrol yang dipakai sambil buru-buru.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.aktif,
    required this.onTap,
    this.jumlah,
  });

  final String label;
  final int? jumlah;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: NeuRaised(
          radius: 18,
          distance: aktif ? 3 : 5,
          blur: aktif ? 8 : 12,
          color: aktif ? c.accent : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
                  color: aktif ? c.onAccent : c.textMuted,
                ),
              ),
              if (jumlah != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: aktif
                        ? c.onAccent.withValues(alpha: 0.22)
                        : c.darkShadow.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$jumlah',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: aktif ? c.onAccent : c.text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu kiriman yang nunggu diputus.
///
/// Susunannya sengaja: **nama alat** paling menonjol (itu yang dicari admin),
/// **nama PT** di bawahnya pakai warna aksen karena dia kunci pengelompokan,
/// lalu teknisi & tanggal diredam. Chevron-nya dipertahankan — satu-satunya
/// petunjuk bahwa baris ini bisa ditekan.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.item});

  final CalibrationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PerhitunganScreen(calibrationId: item.id),
        ),
      ),
      child: NeuRaised(
        radius: 20,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            NeuRaised(
              circle: true,
              distance: 3,
              blur: 7,
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              child: Icon(
                Icons.hourglass_top_outlined,
                size: 20,
                color: c.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaAlat,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  if (item.namaPelanggan != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.namaPelanggan!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${l10n.antreanOleh(item.namaTeknisi)} · '
                    '${DateFormat('d MMM yyyy', locale).format(item.tanggalKalibrasi)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Antrean habis. Sengaja dibikin terasa seperti **pencapaian**, bukan layar
/// kosong yang bikin ragu apakah datanya gagal dimuat.
class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: NeuRaised(
            circle: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Icon(Icons.inbox_outlined, size: 44, color: c.textMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.antreanKosong,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.antreanKosongBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textMuted),
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final c = NeuColors.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: NeuRaised(
            circle: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Icon(Icons.cloud_off_outlined, size: 44, color: c.danger),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.antreanGagal,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        NeuButton(
          label: l10n.perhitPeriksa,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
