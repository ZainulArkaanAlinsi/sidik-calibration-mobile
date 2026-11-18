import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../services/jenis_lembar.dart';

/// Hasil lembar ringkas [PilihJenisRingkasSheet]. Menutup lembar tanpa
/// memilih = `null`.
sealed class HasilPilihJenisRingkas {
  const HasilPilihJenisRingkas();
}

/// Teknisi mengetuk satu jenis.
class JenisDipilih extends HasilPilihJenisRingkas {
  const JenisDipilih(this.formulir);

  final FormulirDikenal formulir;
}

/// Teknisi memilih memotret ulang (foto tidak terbaca / salah lembar).
class MintaFotoUlang extends HasilPilihJenisRingkas {
  const MintaFotoUlang();
}

/// Pilihan jenis lembar yang RINGKAS untuk alur foto beranda: kandidat dari
/// foto, SATU ketukan memilih (tanpa tombol "Pakai"), "Foto ulang", dan
/// "Jenis lain" yang membuka semua jenis di tempat yang sama.
///
/// Menggantikan lembar pilihan lama (`PilihJenisLembarSheet`) di alur ini:
/// tidak ada pilihan-awal, tidak ada pemilih kategori -> alat. Dipakai juga
/// untuk "Ganti jenis" di lembar kerja dan untuk pesan jujur saat jenis tidak
/// dikenali ([kandidat] kosong, hanya pesan + "Foto ulang" + "Jenis lain").
Future<HasilPilihJenisRingkas?> tampilkanPilihJenisRingkas(
  BuildContext context, {
  required String judul,
  required String pesan,
  required List<FormulirDikenal> kandidat,
  required List<FormulirDikenal> semua,
  bool tawarkanFotoUlang = true,
}) => showModalBottomSheet<HasilPilihJenisRingkas>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PilihJenisRingkasSheet(
    judul: judul,
    pesan: pesan,
    kandidat: kandidat,
    semua: semua,
    tawarkanFotoUlang: tawarkanFotoUlang,
  ),
);

class PilihJenisRingkasSheet extends StatefulWidget {
  const PilihJenisRingkasSheet({
    super.key,
    required this.judul,
    required this.pesan,
    required this.kandidat,
    required this.semua,
    this.tawarkanFotoUlang = true,
  });

  final String judul;
  final String pesan;

  /// Hasil foto, urut skor. Kosong = hanya pesan.
  final List<FormulirDikenal> kandidat;

  /// Semua jenis yang dikenal server (daftar "Jenis lain").
  final List<FormulirDikenal> semua;

  final bool tawarkanFotoUlang;

  static const kunciJudul = ValueKey('jr-judul');
  static const kunciPesan = ValueKey('jr-pesan');
  static const kunciFotoUlang = ValueKey('jr-foto-ulang');
  static const kunciJenisLain = ValueKey('jr-jenis-lain');

  static ValueKey<String> kunciBaris(String templateId) =>
      ValueKey('jr-baris-$templateId');

  @override
  State<PilihJenisRingkasSheet> createState() => _PilihJenisRingkasSheetState();
}

class _PilihJenisRingkasSheetState extends State<PilihJenisRingkasSheet> {
  bool _semua = false;

  Widget _baris(FormulirDikenal d) => ListTile(
    key: PilihJenisRingkasSheet.kunciBaris(d.templateId),
    contentPadding: EdgeInsets.zero,
    title: Text(namaPendekJudul(d.judul)),
    subtitle: Text(d.kodeDokumen),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.pop(context, JenisDipilih(d)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    // Daftar "Jenis lain" tidak mengulang kandidat yang sudah tampil (kunci
    // baris tidak boleh kembar dalam satu kolom).
    final idKandidat = {for (final k in widget.kandidat) k.templateId};
    final lain = [
      for (final d in widget.semua)
        if (!idKandidat.contains(d.templateId)) d,
    ]..sort((a, b) => a.judul.compareTo(b.judul));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.judul,
                key: PilihJenisRingkasSheet.kunciJudul,
                style: tema.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(widget.pesan, key: PilihJenisRingkasSheet.kunciPesan),
              if (widget.kandidat.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final d in widget.kandidat) _baris(d),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (widget.tawarkanFotoUlang)
                    OutlinedButton.icon(
                      key: PilihJenisRingkasSheet.kunciFotoUlang,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.lkFotoUlang),
                      onPressed: () =>
                          Navigator.pop(context, const MintaFotoUlang()),
                    ),
                  if (!_semua && lain.isNotEmpty)
                    OutlinedButton.icon(
                      key: PilihJenisRingkasSheet.kunciJenisLain,
                      icon: const Icon(Icons.list_alt_outlined),
                      label: Text(l10n.pindaiJenisLain),
                      onPressed: () => setState(() => _semua = true),
                    ),
                ],
              ),
              if (_semua) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.jlDaftarManual, style: tema.textTheme.titleSmall),
                for (final d in lain) _baris(d),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
