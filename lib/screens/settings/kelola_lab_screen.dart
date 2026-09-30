import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/readable_width.dart';
import '../admin/import_excel_screen.dart';
import 'customer_list_screen.dart';
import 'metode_list_screen.dart';
import 'organization_screen.dart';
import 'ruangan_list_screen.dart';
import 'rumus_list_screen.dart';
import 'standard_list_screen.dart';
import 'tanda_tangan_screen.dart';
import 'technician_list_screen.dart';

/// "Kelola lab" — satu pintu untuk sembilan layar pengaturan admin
/// (artboard `Kelola_Lab`).
///
/// Sebelum ini, di HP sembilan layar itu tersebar di tiga tempat: sebagian di
/// menu samping, sebagian di halaman carousel Profil ("Menu Admin" &
/// "Pengaturan lab") yang cuma ketemu kalau orangnya tahu harus MENGGESER, dan
/// judul/keterangannya terpotong di petak dua kolom. Rumus, Ruangan, Metode,
/// dan Tanda tangan bahkan tidak ada di menu samping sama sekali.
///
/// Di sini semuanya satu daftar bergrup, judul utuh, keterangan boleh dua
/// baris. Layar tujuannya tidak disentuh — halaman ini cuma pintu.
class KelolaLabScreen extends StatelessWidget {
  const KelolaLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final grup = <(String, List<_Pintu>)>[
      (
        l10n.kelolaGrupDataMaster,
        [
          _Pintu(Icons.people_outline, l10n.profCustomers, l10n.profCustomersSub,
              () => const CustomerListScreen()),
          _Pintu(Icons.science_outlined, l10n.profStandards, l10n.profStandardsSub,
              () => const StandardListScreen()),
          _Pintu(Icons.badge_outlined, l10n.teknisiTitle, l10n.kelolaPenggunaSub,
              () => const TechnicianListScreen()),
        ],
      ),
      (
        l10n.kelolaGrupMetode,
        [
          _Pintu(Icons.menu_book_outlined, l10n.profMetode, l10n.profMetodeSub,
              () => const MetodeListScreen()),
          _Pintu(Icons.functions, l10n.profRumus, l10n.profRumusSub,
              () => const RumusListScreen()),
          _Pintu(Icons.meeting_room_outlined, l10n.profRuangan, l10n.profRuanganSub,
              () => const RuanganListScreen()),
        ],
      ),
      (
        l10n.kelolaGrupDokumen,
        [
          _Pintu(Icons.draw_outlined, l10n.profTandaTangan, l10n.profTandaTanganSub,
              () => const TandaTanganScreen()),
          _Pintu(Icons.apartment_outlined, l10n.profOrgData, l10n.profOrgDataSub,
              () => const OrganizationScreen()),
          _Pintu(Icons.upload_file_outlined, l10n.importTitle, l10n.kelolaImportSub,
              () => const ImportExcelScreen()),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kelolaJudul)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final (judul, pintu) in grup) ...[
              _JudulGrup(judul),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < pintu.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _BarisPintu(pintu: pintu[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pintu {
  const _Pintu(this.ikon, this.judul, this.keterangan, this.layar);

  final IconData ikon;
  final String judul;
  final String keterangan;
  final Widget Function() layar;
}

class _BarisPintu extends StatelessWidget {
  const _BarisPintu({required this.pintu});

  final _Pintu pintu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => pintu.layar()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: m.logamTimbul(radius: 9),
              child: Icon(pintu.ikon, size: 20, color: m.etsa),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pintu.judul, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    pintu.keterangan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Judul grup: label TERUKIR (huruf besar, spasi lebar) — satu-satunya tempat
/// di layar kertas ini yang boleh kapital, karena dia pelat nama laci, bukan
/// isi yang dibaca.
class _JudulGrup extends StatelessWidget {
  const _JudulGrup(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
      child: Text(teks.toUpperCase(), style: m.gayaEtsa(ukuran: 11.5)),
    );
  }
}
