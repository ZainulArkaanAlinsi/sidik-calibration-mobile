import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import 'status_tampil.dart';
import 'stempel.dart';

/// Satu butir keterangan di baris ketiga [BarisDaftar]: ikon kecil + kata
/// ("Menunggu 3 hari", "2 peringatan"). Pengganti rangkaian "A · B · C".
@immutable
class MetaBaris {
  const MetaBaris(this.teks, {this.ikon});

  final String teks;
  final IconData? ikon;
}

/// Baris daftar TANPA kartu: permukaan kertas, pemisah garis halus di bawah,
/// tinggi minimum 64 dp, seluruh baris bisa diketuk.
///
/// Susunan: [awal] opsional, lalu judul (16/24 600, paling banyak 2 baris),
/// [keterangan] (14/20 tinta kedua), [meta], dan [tambahan] (mis. `SkalaTempo`
/// atau `SkalaSel`); [status] sebagai stempel di kanan. Di lebar < 360 dp atau
/// huruf > 1,15x ([kompak]) stempel pindah ke baris sendiri di bawah teks,
/// supaya kata status panjang tidak menekan judul.
///
/// Baris bisa dipakai tanpa [onTap] (hanya baca): tanpa panah dan tanpa riak.
/// Pembaca layar menerima satu node berisi judul, keterangan, status, dan meta
/// (atau [semantik] bila diberikan), dengan aksi ketuk di node itu juga.
class BarisDaftar extends StatelessWidget {
  const BarisDaftar({
    super.key,
    required this.judul,
    this.keterangan,
    this.meta = const [],
    this.status,
    this.awal,
    this.tambahan,
    this.onTap,
    this.semantik,
    this.pemisah = true,
  });

  final String judul;

  /// Baris kedua (nama pelanggan, nomor seri).
  final String? keterangan;

  /// Butir keterangan baris ketiga.
  final List<MetaBaris> meta;

  /// Stempel di kanan (atau di bawah teks bila [kompak]).
  final StatusTampil? status;

  /// Penanda di kiri (ikon, avatar).
  final Widget? awal;

  /// Isi tambahan selebar teks, di bawah semuanya.
  final Widget? tambahan;

  final VoidCallback? onTap;

  /// Label pembaca layar pengganti. Bila `null`, dirangkai dari isi baris.
  final String? semantik;

  /// Garis halus di bawah baris.
  final bool pemisah;

  /// Susunan kompak: lebar [lebar] < 360 dp atau skala huruf > 1,15.
  static bool kompak({required double lebar, required double skala}) =>
      lebar < AmbangLab.lebarSempit || skala > AmbangLab.hurufBesar;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final t = Theme.of(context).textTheme;
    final skala = MediaQuery.textScalerOf(context).scale(10) / 10;
    final bisaDiketuk = onTap != null;

    final gayaKeterangan = t.titleSmall?.copyWith(fontWeight: FontWeight.w400);

    final isi = LayoutBuilder(
      builder: (context, batas) {
        final padat = kompak(lebar: batas.maxWidth, skala: skala);
        final stempelDiBawah = padat && status != null;
        final stempelDiKanan = !padat && status != null;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: pemisah
                ? Border(
                    bottom: BorderSide(
                      color: m.kertasTepi,
                      width: AppUkuran.garis,
                    ),
                  )
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: UkuranBaris.minimum),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (awal != null) ...[
                    awal!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          judul,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium,
                        ),
                        if (keterangan != null)
                          Text(
                            keterangan!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: gayaKeterangan,
                          ),
                        if (meta.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.xs,
                              children: [for (final b in meta) _Meta(b)],
                            ),
                          ),
                        if (stempelDiBawah)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Stempel(status!),
                          ),
                        if (tambahan != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: tambahan,
                          ),
                      ],
                    ),
                  ),
                  if (stempelDiKanan) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: batas.maxWidth * UkuranBaris.bagianStempel,
                      ),
                      child: Stempel(status!),
                    ),
                  ],
                  if (bisaDiketuk) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right,
                      size: UkuranIkonLab.navigasi,
                      color: m.tinta2,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    final permukaan = Material(
      color: m.kertas,
      child: InkWell(onTap: onTap, child: isi),
    );

    // Satu node semantik: aksi ketuk melekat di node yang sama dengan labelnya.
    // `excludeSemantics` hanya dipakai bersama `onTap` di node itu sendiri,
    // karena tanpa itu aksi ketuk milik InkWell ikut terbuang.
    if (semantik != null) {
      return Semantics(
        button: bisaDiketuk,
        label: semantik,
        onTap: onTap,
        excludeSemantics: true,
        child: permukaan,
      );
    }
    return MergeSemantics(
      child: Semantics(button: bisaDiketuk, onTap: onTap, child: permukaan),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.butir);

  final MetaBaris butir;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final skala = MediaQuery.textScalerOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (butir.ikon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs / 2),
            child: Icon(
              butir.ikon,
              size: skala.scale(UkuranIkonLab.stempel),
              color: s.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: Text(butir.teks, style: t.bodySmall)),
      ],
    );
  }
}
