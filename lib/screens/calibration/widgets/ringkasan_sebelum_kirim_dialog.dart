import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/dekorasi_isian_wajib.dart';
import '../lembar_kerja_state.dart' show kuningPerluDicek;
import '../ringkasan_sebelum_kirim.dart';

/// Jawaban teknisi di dialog ringkasan.
class HasilRingkasanKirim {
  const HasilRingkasanKirim._({this.kirim = false, this.lompat});

  /// "Tetap kirim".
  static const kirimSaja = HasilRingkasanKirim._(kirim: true);

  /// "Kembali" (atau dialog ditutup tanpa memilih).
  static const kembali = HasilRingkasanKirim._();

  /// Item diketuk: tutup dialog dan lompat ke [lompat].
  const HasilRingkasanKirim.lompatKe(String sasaran) : this._(lompat: sasaran);

  final bool kirim;
  final String? lompat;
}

/// Tampilkan dialog. `null` = ditutup tanpa memilih (dianggap kembali).
Future<HasilRingkasanKirim?> tampilkanRingkasanSebelumKirim(
  BuildContext context,
  RingkasanSebelumKirim ringkasan,
) => showDialog<HasilRingkasanKirim>(
  context: context,
  builder: (_) => DialogRingkasanSebelumKirim(ringkasan: ringkasan),
);

/// "Ringkasan sebelum kirim".
///
///  - Butir WAJIB (gerbang kirim yang sudah ada): palet `wajibKosong`; tombol
///    kirim NONAKTIF dan alasannya tertulis di atas daftar. Butir yang punya
///    tempat tujuan bisa diketuk untuk melompat.
///  - Butir PERINGATAN: amber ([kuningPerluDicek]); teknisi boleh "Tetap kirim".
///
/// Warna tidak pernah satu-satunya penanda: tiap butir membawa ikon dan judul
/// kelompok.
class DialogRingkasanSebelumKirim extends StatefulWidget {
  const DialogRingkasanSebelumKirim({super.key, required this.ringkasan});

  final RingkasanSebelumKirim ringkasan;

  @override
  State<DialogRingkasanSebelumKirim> createState() =>
      _DialogRingkasanSebelumKirimState();
}

class _DialogRingkasanSebelumKirimState
    extends State<DialogRingkasanSebelumKirim> {
  /// Dialog hanya boleh menjawab SEKALI: dua ketukan beruntun pada "Tetap
  /// kirim" tidak boleh melahirkan dua `pop` (yang kedua menutup layar di
  /// bawahnya) maupun dua pengiriman.
  bool _sudahMenjawab = false;

  void _jawab(HasilRingkasanKirim hasil) {
    if (_sudahMenjawab) return;
    _sudahMenjawab = true;
    Navigator.of(context).pop(hasil);
  }

  String _teks(AppLocalizations l10n, ButirRingkasan b) => switch (b.jenis) {
    JenisButirRingkasan.alatBelumDipilih => l10n.lkBelumPilihAlat,
    JenisButirRingkasan.suhuBelumLengkap => l10n.lkSuhuWajib(b.label),
    JenisButirRingkasan.standarBelumDicentang => l10n.lkStandarBelumDicentang(
      b.label,
    ),
    JenisButirRingkasan.setPointKosong => l10n.lkSetPointKosong(b.label),
    JenisButirRingkasan.jamTidakTerbaca => l10n.lkJamTidakTerbaca(b.label),
    JenisButirRingkasan.identitasKosong => l10n.rskIdentitasKosong(b.label),
    JenisButirRingkasan.ocrPerluDicek => l10n.rskOcrPerluDicek(
      b.jumlah,
      b.label,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = widget.ringkasan;
    final wajib = r.wajib;
    final peringatan = r.peringatan;

    return AlertDialog(
      key: const ValueKey('dialog-ringkasan-sebelum-kirim'),
      // Isinya setinggi jumlah butir x ukuran huruf HP-nya; tanpa ini tombol
      // kirim bisa terdorong keluar layar tepat di detik teknisi mau mengirim.
      scrollable: true,
      title: Text(l10n.rskJudul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.menahan
                ? l10n.rskTahanPesan(wajib.length)
                : l10n.rskPeringatanPesan,
            key: const ValueKey('ringkasan-pesan-status'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: r.menahan ? FontWeight.w600 : null,
            ),
          ),
          if (wajib.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _JudulKelompok(
              teks: l10n.rskBagianWajib,
              ikon: Icons.error_outline,
            ),
            for (var i = 0; i < wajib.length; i++)
              _KartuButir(
                key: ValueKey('ringkasan-wajib-${wajib[i].jenis.name}-$i'),
                teks: _teks(l10n, wajib[i]),
                tahan: true,
                bisaLompat: wajib[i].lompat != null,
                onTap: wajib[i].lompat == null
                    ? null
                    : () => _jawab(
                        HasilRingkasanKirim.lompatKe(wajib[i].lompat!),
                      ),
              ),
          ],
          if (peringatan.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _JudulKelompok(
              teks: l10n.rskBagianPeringatan,
              ikon: Icons.warning_amber_rounded,
            ),
            for (var i = 0; i < peringatan.length; i++)
              _KartuButir(
                key: ValueKey(
                  'ringkasan-peringatan-${peringatan[i].jenis.name}-$i',
                ),
                teks: _teks(l10n, peringatan[i]),
                tahan: false,
                bisaLompat: peringatan[i].lompat != null,
                onTap: peringatan[i].lompat == null
                    ? null
                    : () => _jawab(
                        HasilRingkasanKirim.lompatKe(peringatan[i].lompat!),
                      ),
              ),
          ],
          if (r.titikTotal > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.rskTitikTerisi(r.titikTerisi, r.titikTotal),
              key: const ValueKey('ringkasan-hitungan-titik'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('ringkasan-kembali'),
          onPressed: () => _jawab(HasilRingkasanKirim.kembali),
          child: Text(l10n.rskKembali),
        ),
        FilledButton(
          key: const ValueKey('ringkasan-kirim'),
          // Gerbang yang menahan: tombol MATI, dan alasannya tertulis di atas.
          onPressed: r.menahan
              ? null
              : () => _jawab(HasilRingkasanKirim.kirimSaja),
          child: Text(r.menahan ? l10n.rskKirim : l10n.rskTetapKirim),
        ),
      ],
    );
  }
}

class _JudulKelompok extends StatelessWidget {
  const _JudulKelompok({required this.teks, required this.ikon});

  final String teks;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            teks,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuButir extends StatelessWidget {
  const _KartuButir({
    super.key,
    required this.teks,
    required this.tahan,
    required this.bisaLompat,
    required this.onTap,
  });

  final String teks;
  final bool tahan;
  final bool bisaLompat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Palet yang SUDAH live: wajib-kosong untuk gerbang, kuning "perlu dicek"
    // untuk peringatan. Tidak ada warna baru.
    final wajib = PaletIsian.untuk(theme.brightness, StatusIsian.wajibKosong)!;
    final latar = tahan
        ? wajib.latar
        : kuningPerluDicek.withValues(alpha: 0.14);
    final tepi = tahan ? wajib.tepi : kuningPerluDicek;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: latar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(color: tepi, width: tahan ? 2 : 1),
        ),
        child: Semantics(
          button: bisaLompat,
          hint: bisaLompat ? l10n.rskLompatKet : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    tahan ? Icons.error_outline : Icons.warning_amber_rounded,
                    size: 20,
                    color: tepi,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(teks, style: theme.textTheme.bodySmall)),
                  if (bisaLompat) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
