import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/ukuran_komponen.dart';

/// Aksi utama layar: tombol kobalt 56 dp, sudut 16, selebar induk. SATU per
/// layar; aksi lain memakai tombol sekunder 48 dp.
///
/// Tinggi, sudut, dan warna datang dari `filledButtonTheme` di `SidikTheme`
/// (56 dp di HP dan tablet, 44 di desktop Windows), bukan ditulis di sini.
/// Label panjang membungkus ke baris berikutnya dan tombol ikut tumbuh, jadi
/// huruf 1,3x tidak memotong.
///
/// Aksi yang mati menjelaskan alasannya: isi [alasanMati] dan kalimat itu
/// tampil tepat di atas tombol (hanya saat [onPressed] `null`). [sibuk]
/// mematikan tombol, memutar pemutar kecil menggantikan ikon, dan pembaca layar
/// menerima "label, sedang diproses".
class TombolUtama extends StatelessWidget {
  const TombolUtama({
    super.key,
    required this.label,
    required this.onPressed,
    this.ikon,
    this.sibuk = false,
    this.alasanMati,
    this.keterangan = 'sedang diproses',
  });

  final String label;

  /// `null` = mati.
  final VoidCallback? onPressed;
  final IconData? ikon;

  /// Menampilkan pemutar dan menolak ketukan.
  final bool sibuk;

  /// Kalimat pendek di atas tombol saat mati ("Isi 2 sel wajib dulu").
  final String? alasanMati;

  /// Kata tambahan untuk pembaca layar saat [sibuk].
  final String keterangan;

  bool get _aktif => onPressed != null && !sibuk;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final teks = Text(label, textAlign: TextAlign.center);
    final Widget? penanda = sibuk
        ? SizedBox(
            width: UkuranIkonLab.pemutar,
            height: UkuranIkonLab.pemutar,
            child: CircularProgressIndicator(
              strokeWidth: AppUkuran.garisTebal,
              color: s.onSurfaceVariant,
            ),
          )
        : (ikon == null ? null : Icon(ikon));

    // Label tombol mati tetap terbaca (tinta kedua penuh, 7:1 di latar mati):
    // tema bawaan memudarkannya sampai ±3:1, padahal kalimat alasan dan nama
    // aksi yang ditunda harus tetap bisa dibaca di bengkel.
    //
    // Bantalan atas-bawah supaya label yang membungkus (huruf 1,3x) tidak
    // menempel ke tepi tombol; tinggi 56 dp tetap dijaga tema (minimum).
    final gaya = FilledButton.styleFrom(
      disabledForegroundColor: s.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
    final tombol = penanda == null
        ? FilledButton(
            onPressed: _aktif ? onPressed : null,
            style: gaya,
            child: teks,
          )
        : FilledButton.icon(
            onPressed: _aktif ? onPressed : null,
            style: gaya,
            icon: penanda,
            label: teks,
          );

    final tampilAlasan = !_aktif && !sibuk && alasanMati != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tampilAlasan)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(alasanMati!, style: t.bodySmall),
          ),
        sibuk
            ? Semantics(
                button: true,
                enabled: false,
                label: '$label, $keterangan',
                excludeSemantics: true,
                child: tombol,
              )
            : tombol,
      ],
    );
  }
}
