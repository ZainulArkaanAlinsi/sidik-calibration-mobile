import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_ukuran.dart';
import '../../../l10n/app_localizations.dart';
import '../cek_bacaan_kamera.dart';
import '../lembar_kerja_state.dart' show LembarKerjaState, kuningPerluDicek;
import 'tanda_lompat.dart';

/// Gaya tombol gerbang: tinggi 48 dp, lebar seukuran isi (tema memaksa tombol
/// selebar ruang — salah di dalam `Wrap`).
const _gayaTombolCek = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, AppUkuran.sasaranSentuh)),
);

/// Border sel menurut [status]; `null` = pakai border bawaan sel.
///
/// Perlu dicek: kuning tebal. Sudah dicek: border biasa (tanda "sudah" ada di
/// ikon, bukan di warna). Warna tidak pernah satu-satunya penanda — lihat
/// [TandaCekSel].
InputBorder? borderCek(StatusCekSel? status) => status == StatusCekSel.perluCek
    ? const OutlineInputBorder(
        borderSide: BorderSide(
          color: kuningPerluDicek,
          width: AppUkuran.garisTebal,
        ),
      )
    : null;

/// Pembungkus sel hasil kamera: mendengarkan [cek] dan menggambar [bangun]
/// sesuai status terkininya, plus lencana ikon + label `Semantics`.
///
/// [cek] `null` = sel biasa (bukan hasil kamera): [bangun] dipanggil dengan
/// status `null` tanpa pendengar apa pun.
class LapisCekSel extends StatelessWidget {
  const LapisCekSel({super.key, required this.cek, required this.bangun});

  final PemantauCek? cek;
  final Widget Function(BuildContext context, StatusCekSel? status) bangun;

  @override
  Widget build(BuildContext context) {
    final c = cek;
    if (c == null) return bangun(context, null);

    return TandaLompat(
      kode: c.sasaranLompat,
      child: ListenableBuilder(
        listenable: c.dengarkan,
        builder: (context, _) {
          final status = c.status;

          return TandaCekSel(status: status, child: bangun(context, status));
        },
      ),
    );
  }
}

/// Lencana di sudut sel: ikon (bukan cuma warna) + label untuk pembaca layar.
class TandaCekSel extends StatelessWidget {
  const TandaCekSel({super.key, required this.status, required this.child});

  final StatusCekSel? status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null || s == StatusCekSel.tanpaTanda) return child;

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final perlu = s == StatusCekSel.perluCek;

    return Semantics(
      label: perlu ? l10n.cekTandaPerlu : l10n.cekTandaSudah,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -AppSpacing.xs,
            right: -AppSpacing.xs,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    perlu
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: AppUkuran.ikonSebaris,
                    color: perlu ? kuningPerluDicek : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Di bawah kolom isian (header / kondisi ruang) yang angkanya dibaca dari
/// foto: ikon + kata "Perlu dicek" dan tombol 48 dp untuk mengonfirmasi SATU
/// kolom itu.
class BarisCekIsian extends StatelessWidget {
  const BarisCekIsian({
    super.key,
    required this.cek,
    required this.onKonfirmasi,
  });

  final PemantauCek cek;
  final VoidCallback onKonfirmasi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: cek.dengarkan,
      builder: (context, _) {
        final status = cek.status;
        if (status == StatusCekSel.tanpaTanda) return const SizedBox.shrink();

        final perlu = status == StatusCekSel.perluCek;

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                perlu
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: AppUkuran.ikonSebaris,
                color: perlu ? kuningPerluDicek : theme.colorScheme.primary,
              ),
              Text(
                perlu ? l10n.cekTandaPerlu : l10n.cekTandaSudah,
                style: theme.textTheme.labelLarge,
              ),
              if (perlu)
                OutlinedButton(
                  key: ValueKey('cek-isian-${cek.kunci}'),
                  style: _gayaTombolCek,
                  onPressed: onKonfirmasi,
                  child: Text(l10n.cekSudahSaya),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bilah gerbang di atas tombol Kirim: berapa sel hasil kamera yang belum
/// dicek, dan satu tombol 48 dp yang membuka lembar pemeriksa
/// ([bukaPemeriksaCek]).
///
/// Sengaja ringkas (hitungan + satu tombol): bilah ini nempel di bawah dan
/// bersaing tinggi dengan lembar kerja. Panel yang memuat nilai sel, tiga
/// tombol, dan alasan membuat bilah bawah meluap 114 px di HP 320 dp x huruf
/// 1,3 (ketahuan oleh test render), jadi isi pemeriksaannya pindah ke lembar
/// bawah yang bisa digulir.
class PanelGerbangCek extends StatelessWidget {
  const PanelGerbangCek({
    super.key,
    required this.isian,
    required this.onLompat,
  });

  final LembarKerjaState isian;

  /// Gulir lembar ke sel [SelCek].
  final Future<void> Function(SelCek sel) onLompat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: isian.revisiCek,
      builder: (context, _) {
        final semua = isian.daftarSelCek();
        if (semua.isEmpty) return const SizedBox.shrink();

        final jumlah = semua
            .where((s) => s.status == StatusCekSel.perluCek)
            .length;

        if (jumlah == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              key: const ValueKey('panel-cek-selesai'),
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppUkuran.ikonSebaris,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.cekPanelSelesai(semua.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            key: const ValueKey('panel-cek-tahan'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: kuningPerluDicek.withValues(alpha: 0.14),
              border: Border.all(
                color: kuningPerluDicek,
                width: AppUkuran.garis,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: AppUkuran.ikonSebaris,
                      color: kuningPerluDicek,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.cekPanelTahan(jumlah),
                        key: const ValueKey('panel-cek-jumlah'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  key: const ValueKey('cek-buka-pemeriksa'),
                  style: _gayaTombolCek,
                  onPressed: () => bukaPemeriksaCek(
                    context,
                    isian: isian,
                    onLompat: onLompat,
                  ),
                  child: Text(l10n.cekBukaPemeriksa),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Judul sel di lembar pemeriksa. Sel tabel/matriks/isian memakai data lembar
/// apa adanya; sel grid disusun dari bagiannya lewat l10n (id + en).
String judulSelCek(AppLocalizations l10n, SelCek sel) {
  final peran = sel.peranGrid;
  if (peran == null) return sel.judul;

  final baris = switch (peran) {
    PeranSelGrid.termokopel => l10n.cekGridTermokopel(sel.urutanBaris ?? 0),
    PeranSelGrid.indikator => l10n.cekGridIndikator,
    PeranSelGrid.suhuRuang => l10n.cekGridSuhuRuang,
    PeranSelGrid.nomorTermokopel => l10n.cekGridNomorTermokopel(
      sel.urutanBaris ?? 0,
    ),
  };
  final setPoint = sel.judul.isEmpty
      ? l10n.cekGridSetPoint(sel.setPoint ?? 0)
      : l10n.cekGridSetPointTitik(sel.judul);

  return '$setPoint · $baris';
}

/// Buka lembar pemeriksa: sel hasil kamera yang belum dicek, satu per satu.
Future<void> bukaPemeriksaCek(
  BuildContext context, {
  required LembarKerjaState isian,
  required Future<void> Function(SelCek sel) onLompat,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => _IsiPemeriksaCek(
    isian: isian,
    onLompat: (sel) async {
      // Lembarnya ditutup dulu supaya selnya kelihatan waktu digulir ke sana.
      Navigator.of(sheet).pop();
      await onLompat(sel);
    },
    onTutup: () => Navigator.of(sheet).pop(),
  ),
);

/// Isi lembar pemeriksa: nilai sel yang sedang diperiksa, tautan lompat, dan
/// konfirmasi untuk SATU sel itu.
///
/// Tidak ada tombol yang mengonfirmasi lebih dari satu sel: "Sudah saya cek"
/// berlaku untuk sel yang sedang ditampilkan, lalu lembar pindah ke sel
/// berikutnya (konfirmasi berurutan, satu ketukan per sel).
class _IsiPemeriksaCek extends StatefulWidget {
  const _IsiPemeriksaCek({
    required this.isian,
    required this.onLompat,
    required this.onTutup,
  });

  final LembarKerjaState isian;
  final Future<void> Function(SelCek sel) onLompat;
  final VoidCallback onTutup;

  @override
  State<_IsiPemeriksaCek> createState() => _IsiPemeriksaCekState();
}

class _IsiPemeriksaCekState extends State<_IsiPemeriksaCek> {
  /// Sel terakhir yang dilewati atau dikonfirmasi — "berikutnya" dihitung dari
  /// sini.
  String? _setelah;

  void _konfirmasi(SelCek sel) {
    if (!widget.isian.konfirmasiSelCek(sel.kunci)) return;

    setState(() => _setelah = sel.kunci);
  }

  void _lewati(SelCek sel) => setState(() => _setelah = sel.kunci);

  @override
  Widget build(BuildContext context) {
    final isian = widget.isian;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: isian.revisiCek,
      builder: (context, _) {
        final semua = isian.daftarSelCek();
        final jumlah = semua
            .where((s) => s.status == StatusCekSel.perluCek)
            .length;
        final sel = isian.selCekBerikutnya(setelah: _setelah);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.cekSheetJudul, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (jumlah == 0 || sel == null) ...[
                  Row(
                    key: const ValueKey('pemeriksa-cek-selesai'),
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: AppUkuran.ikonSebaris,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.cekPanelSelesai(semua.length),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    key: const ValueKey('cek-tutup-pemeriksa'),
                    style: _gayaTombolCek,
                    onPressed: widget.onTutup,
                    child: Text(l10n.cekTutup),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: AppUkuran.ikonSebaris,
                        color: kuningPerluDicek,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.cekPanelTahan(jumlah),
                          key: const ValueKey('pemeriksa-cek-jumlah'),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    sel.nomor == null
                        ? l10n.cekPanelSel(
                            judulSelCek(l10n, sel),
                            sel.teks.trim(),
                          )
                        : l10n.cekPanelSelNomor(
                            judulSelCek(l10n, sel),
                            sel.nomor!,
                            sel.teks.trim(),
                          ),
                    key: const ValueKey('panel-cek-sel'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      FilledButton(
                        key: const ValueKey('cek-konfirmasi-sel'),
                        style: _gayaTombolCek,
                        onPressed: () => _konfirmasi(sel),
                        child: Text(l10n.cekSudahSayaLanjut),
                      ),
                      TextButton.icon(
                        key: const ValueKey('cek-lompat-sel'),
                        style: _gayaTombolCek,
                        onPressed: () => widget.onLompat(sel),
                        icon: const Icon(
                          Icons.my_location_outlined,
                          size: AppUkuran.ikonSebaris,
                        ),
                        label: Text(l10n.cekLompat),
                      ),
                      if (jumlah > 1)
                        TextButton(
                          key: const ValueKey('cek-lewati-sel'),
                          style: _gayaTombolCek,
                          onPressed: () => _lewati(sel),
                          child: Text(l10n.cekLewati),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.cekPanelAlasan,
                    key: const ValueKey('panel-cek-alasan'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
