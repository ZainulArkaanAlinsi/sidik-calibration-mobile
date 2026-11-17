import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import 'tombol_utama.dart';

/// Tiga ragam keadaan daftar yang tidak menampilkan butir.
enum RagamKeadaan {
  /// Belum ada isi. Teks mengajak bertindak ("Belum ada draf. Mulai lembar
  /// baru dari tombol di atas.").
  kosong,

  /// Gagal memuat. Menyebut apa yang terjadi dan langkah berikutnya, tanpa
  /// meminta maaf.
  galat,

  /// Tanpa sambungan dan tidak ada data tersimpan untuk ditampilkan.
  offline,
}

/// Keadaan daftar kosong, galat, atau offline: SATU komponen, tiga ragam.
///
/// Judul satu kalimat, penjelasan satu kalimat, dan paling banyak SATU
/// tindakan ("Coba lagi", "Mulai kalibrasi"). Rata kiri, tanpa ilustrasi dan
/// tanpa ikon dekoratif: hanya [RagamKeadaan.galat] dan [RagamKeadaan.offline]
/// membawa ikon kecil sebaris dengan judul, sebagai penanda jenis (kata
/// tetap membawa arti). Tindakan berupa tombol sekunder 48 dp; bila keadaan ini
/// satu-satunya yang bisa dilakukan di layar ([aksiUtama]) ia menjadi tombol
/// utama 56 dp.
///
/// Banner offline di atas daftar yang masih punya isi adalah [BannerOffline].
class KeadaanKosongGalatOffline extends StatelessWidget {
  const KeadaanKosongGalatOffline({
    super.key,
    required this.ragam,
    required this.judul,
    required this.penjelasan,
    this.labelAksi,
    this.onAksi,
    this.aksiUtama = false,
  }) : assert(
         (labelAksi == null) == (onAksi == null),
         'labelAksi dan onAksi harus diisi bersama',
       );

  final RagamKeadaan ragam;
  final String judul;
  final String penjelasan;

  /// Label tindakan; `null` = tanpa tindakan.
  final String? labelAksi;
  final VoidCallback? onAksi;

  /// Tindakan sebagai tombol utama 56 dp.
  final bool aksiUtama;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final m = SidikMaterial.of(context);
    final ikon = switch (ragam) {
      RagamKeadaan.kosong => null,
      RagamKeadaan.galat => Icons.error_outline,
      RagamKeadaan.offline => Icons.cloud_off_outlined,
    };
    final warnaIkon = ragam == RagamKeadaan.galat
        ? m.gagal
        : s.onSurfaceVariant;
    final skala = MediaQuery.textScalerOf(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            // Galat dibacakan segera ketika muncul menggantikan daftar.
            liveRegion: ragam != RagamKeadaan.kosong,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ikon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs / 2),
                    child: Icon(
                      ikon,
                      size: skala.scale(UkuranIkonLab.sebaris),
                      color: warnaIkon,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(child: Text(judul, style: t.titleMedium)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            penjelasan,
            style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
          if (labelAksi != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (aksiUtama)
              TombolUtama(label: labelAksi!, onPressed: onAksi)
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: onAksi,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, UkuranLab.aksi),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: Text(labelAksi!, textAlign: TextAlign.center),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Banner di atas daftar saat perangkat offline: draf tetap tersimpan, kirim
/// ditahan. Ikon + kata pada latar tipis nada "awas", selebar induk, tanpa
/// sudut. Dibacakan pembaca layar begitu muncul.
class BannerOffline extends StatelessWidget {
  const BannerOffline({super.key, required this.teks});

  /// Satu atau dua kalimat ("Tanpa sambungan. Draf tetap tersimpan; kirim
  /// ditahan sampai tersambung").
  final String teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final t = Theme.of(context).textTheme;
    final skala = MediaQuery.textScalerOf(context);
    return Semantics(
      liveRegion: true,
      label: teks,
      excludeSemantics: true,
      child: ColoredBox(
        color: m.awasTipis,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs / 2),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: skala.scale(UkuranIkonLab.sebaris),
                  color: m.awas,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(teks, style: t.bodyMedium?.copyWith(color: m.awas)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
