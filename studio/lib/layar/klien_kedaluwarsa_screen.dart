import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../inti/lingkungan_studio.dart';
import '../inti/sesi_studio.dart';
import '../l10n/studio_l10n.dart';
import '../tema/tema_studio.dart';
import '../tema/warna_studio.dart';

/// ST-90 "Versi Studio usang (426)" — server menolak versi Studio ini
/// (`426 klien_kedaluwarsa`, FR-STU-003).
///
/// Tidak ada pembaru di dalam Studio (FR-STU-017: distribusi Q-49-09, sampai
/// dijawab pemasangan manual), jadi layar ini cuma bisa jujur: versinya
/// terlalu lama, pasang yang baru. "Coba lagi" melupakan tanda ini; request
/// berikutnya menandainya lagi bila server masih menolak.
class KlienKedaluwarsaScreen extends ConsumerWidget {
  const KlienKedaluwarsaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final alamat = ref.watch(alamatServerStudioProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UkuranStudio.j6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_alt, size: 40, color: w.teks2),
                  const SizedBox(height: UkuranStudio.j4),
                  Text(
                    l10n.kedaluwarsaJudul,
                    textAlign: TextAlign.center,
                    style: teks.titleMedium,
                  ),
                  const SizedBox(height: UkuranStudio.j2),
                  Text(
                    l10n.kedaluwarsaKet,
                    textAlign: TextAlign.center,
                    style: teks.bodyMedium?.copyWith(color: w.teks2),
                  ),
                  const SizedBox(height: UkuranStudio.j4),
                  Text(
                    l10n.kedaluwarsaVersi(versiStudio, hostServer(alamat)),
                    textAlign: TextAlign.center,
                    style: TipografiStudio.angka(ukuran: 12, warna: w.teks2),
                  ),
                  const SizedBox(height: UkuranStudio.j6),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(klienKedaluwarsaProvider.notifier).lupakan(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.cobaLagi),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
