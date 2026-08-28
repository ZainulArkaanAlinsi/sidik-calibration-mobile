/// Layar baca lembar kerja generik: foto -> struktur -> form yang bisa diisi.
///
/// Menutup rantai jalur generik di sisi HP. Bedanya dari layar pindai
/// bertemplate: layar itu butuh teknisi memilih template dulu dan menolak
/// lembar yang belum punya profil. Di sini nggak ada yang dipilih — bentuk
/// formnya menyusul dari isi kertas.
///
/// ## Yang dijaga
///
/// - Koreksi teknisi disimpan di provider TERPISAH dari keadaan bacanya,
///   supaya ketikan nggak hilang tiap keadaannya berubah.
/// - Tombol "foto ulang" cuma muncul buat kegagalan yang MEMANG bisa ditolong
///   foto ulang. Menawarkannya waktu penyedianya sibuk bikin teknisi motret
///   berkali-kali buat sesuatu yang mustahil berhasil.
/// - Batal ambil foto bukan error, jadi nggak ada pesan gagal buat kasus itu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/dokumen_generik_provider.dart';
import '../../widgets/dinamis/form_dinamis.dart';

class BacaDokumenScreen extends ConsumerStatefulWidget {
  const BacaDokumenScreen({super.key});

  @override
  ConsumerState<BacaDokumenScreen> createState() => _BacaDokumenScreenState();
}

class _BacaDokumenScreenState extends ConsumerState<BacaDokumenScreen> {
  final _namaAlat = TextEditingController();

  @override
  void dispose() {
    _namaAlat.dispose();
    super.dispose();
  }

  Future<void> _foto() async {
    // Koreksi lama dibuang SEBELUM baca yang baru: nilai dari lembar
    // sebelumnya nggak boleh nempel ke kunci lembar berikutnya.
    ref.read(koreksiDokumenProvider.notifier).bersihkan();

    await ref
        .read(bacaDokumenProvider.notifier)
        .fotoLaluBaca(namaAlat: _namaAlat.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keadaan = ref.watch(bacaDokumenProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dokBacaJudul)),
      body: switch (keadaan) {
        BelumAdaFoto() => _Ajakan(namaAlat: _namaAlat, onFoto: _foto),
        SedangMembaca() => _Sedang(pesan: l10n.dokBacaSedang),
        BacaDokumenGagal(:final pesan, :final pantasDiulang) => _Gagal(
          pesan: pesan,
          onUlang: pantasDiulang ? _foto : null,
          onMulaiLagi: () =>
              ref.read(bacaDokumenProvider.notifier).ulangDariAwal(),
        ),
        DokumenTerbaca(:final skema) => FormDinamis(
          skema: skema,
          nilai: ref.watch(koreksiDokumenProvider),
          onUbah: (kunci, nilai) =>
              ref.read(koreksiDokumenProvider.notifier).ubah(kunci, nilai),
        ),
      },
    );
  }
}

class _Ajakan extends StatelessWidget {
  const _Ajakan({required this.namaAlat, required this.onFoto});

  final TextEditingController namaAlat;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.dokBacaAjakan, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        TextField(
          controller: namaAlat,
          decoration: InputDecoration(
            labelText: l10n.dokBacaNamaAlatLabel,
            helperText: l10n.dokBacaNamaAlatBantuan,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onFoto,
          icon: const Icon(Icons.photo_camera),
          label: Text(l10n.dokBacaTombolFoto),
        ),
      ],
    );
  }
}

class _Sedang extends StatelessWidget {
  const _Sedang({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(pesan),
        ],
      ),
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({
    required this.pesan,
    required this.onUlang,
    required this.onMulaiLagi,
  });

  final String pesan;

  /// `null` = kegagalan ini nggak bisa ditolong foto ulang.
  final VoidCallback? onUlang;
  final VoidCallback onMulaiLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(pesan, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (onUlang != null)
            FilledButton.icon(
              onPressed: onUlang,
              icon: const Icon(Icons.photo_camera),
              label: Text(l10n.dokBacaUlangFoto),
            ),
          TextButton(
            onPressed: onMulaiLagi,
            child: Text(l10n.dokBacaMulaiLagi),
          ),
        ],
      ),
    );
  }
}
