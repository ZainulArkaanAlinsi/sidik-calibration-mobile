import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../models/izin.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/izin_provider.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../admin/perhitungan_screen.dart';
import '../calibration/calibration_input_screen.dart';
import '../calibration/instrument_picker_screen.dart' show profilLembarKerjaUntuk;
import '../calibration/lembar_kerja_screen.dart';
import '../history/calibration_detail_screen.dart';
import '../history/certificate_screen.dart';
import '../history/kirim_email_screen.dart';

/// Alur satu sesi kalibrasi, dari isian teknisi sampai sertifikat kekirim.
///
/// **Layarnya nggak bikin apa-apa yang baru** — semua tahapannya udah punya
/// layar sendiri dan udah jalan. Yang belum ada itu benang merahnya: buat tahu
/// satu sesi lagi nyangkut di mana, orang mesti buka Riwayat, cocokin status,
/// lalu nyari sendiri menu mana yang mesti dibuka berikutnya. Di panel yang
/// sepuluh menunya kelihatan sekaligus, itu justru bikin bingung.
///
/// Jadi di sini urutannya yang dijadiin barang: pilih sesi → kelihatan
/// posisinya → tombolnya cuma satu, yang emang langkah berikutnya.
class AlurKerjaScreen extends ConsumerStatefulWidget {
  const AlurKerjaScreen({super.key});

  @override
  ConsumerState<AlurKerjaScreen> createState() => _AlurKerjaScreenState();
}

class _AlurKerjaScreenState extends ConsumerState<AlurKerjaScreen> {
  int? _sesiDipilih;
  String _cari = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historyProvider);

    return switch (async) {
      AsyncData(:final value) => _Isi(
          sesi: value,
          dipilih: _sesiDipilih,
          cari: _cari,
          onCari: (v) => setState(() => _cari = v),
          onPilih: (id) => setState(() => _sesiDipilih = id),
        ),
      AsyncError() => _Gagal(
          onCobaLagi: () => ref.invalidate(historyProvider),
        ),
      _ => const _Skeleton(),
    };
  }
}

class _Isi extends StatelessWidget {
  const _Isi({
    required this.sesi,
    required this.dipilih,
    required this.cari,
    required this.onCari,
    required this.onPilih,
  });

  final List<CalibrationHistoryItem> sesi;
  final int? dipilih;
  final String cari;
  final ValueChanged<String> onCari;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kunci = cari.trim().toLowerCase();

    final tersaring = kunci.isEmpty
        ? sesi
        : sesi
            .where(
              (s) =>
                  s.namaAlat.toLowerCase().contains(kunci) ||
                  s.namaTeknisi.toLowerCase().contains(kunci),
            )
            .toList();

    // Sesi yang dipilih bisa ilang dari daftar begitu kata kuncinya berubah —
    // jatuh balik ke keadaan "belum milih", bukan nampilin panel kosong yang
    // nggak nunjuk ke apa-apa.
    final aktif = tersaring.where((s) => s.id == dipilih).firstOrNull;

    return Row(
      children: [
        SizedBox(
          width: 340,
          child: _DaftarSesi(
            sesi: tersaring,
            dipilih: aktif?.id,
            cari: cari,
            onCari: onCari,
            onPilih: onPilih,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: aktif == null
              ? _BelumMilih(pesan: l10n.alurPilihSesi)
              : _PanelTahapan(sesi: aktif),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- daftar

class _DaftarSesi extends StatelessWidget {
  const _DaftarSesi({
    required this.sesi,
    required this.dipilih,
    required this.cari,
    required this.onCari,
    required this.onPilih,
  });

  final List<CalibrationHistoryItem> sesi;
  final int? dipilih;
  final String cari;
  final ValueChanged<String> onCari;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            onChanged: onCari,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.alurCari,
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Expanded(
          child: sesi.isEmpty
              ? Center(
                  child: Text(
                    l10n.alurKosong,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: sesi.length,
                  itemBuilder: (_, i) => _BarisSesi(
                    sesi: sesi[i],
                    aktif: sesi[i].id == dipilih,
                    onTap: () => onPilih(sesi[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _BarisSesi extends StatelessWidget {
  const _BarisSesi({
    required this.sesi,
    required this.aktif,
    required this.onTap,
  });

  final CalibrationHistoryItem sesi;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tahap = _tahapDari(sesi);

    return Material(
      color: aktif
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sesi.namaAlat,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // Teknisi + kapan barisnya terakhir bergerak. Di papan alur
                // kerja dua sesi bisa nangkring di tahap yang sama seharian;
                // jamnya yang mbedain mana yang baru masuk.
                switch (sesi.waktuTerakhir) {
                  final DateTime w => '${sesi.namaTeknisi} · '
                      '${waktuRelatif(w, Localizations.localeOf(context).languageCode, hariIni: AppLocalizations.of(context).waktuHariIni, kemarin: AppLocalizations.of(context).waktuKemarin)}',
                  _ => sesi.namaTeknisi,
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _LencanaTahap(sesi: sesi, tahap: tahap),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- tahapan

/// Empat langkah yang dilewatin tiap sesi. Urutannya tetap; yang berubah cuma
/// posisi sesinya.
enum _Tahap { lembarKerja, perhitungan, sertifikat, kirim }

/// Sesi lagi di langkah mana, diturunkan dari status + ada-nya sertifikat.
///
/// `perluRevisi` sengaja balik ke [_Tahap.lembarKerja]: secara alur dia emang
/// mundur ke teknisi lagi, bukan langkah kelima yang berdiri sendiri. Yang
/// bedain cuma catatan admin yang ikut ditampilin.
_Tahap _tahapDari(CalibrationHistoryItem s) => switch (s.status) {
      CalibrationStatus.draft => _Tahap.lembarKerja,
      CalibrationStatus.perluRevisi => _Tahap.lembarKerja,
      CalibrationStatus.menungguApproval => _Tahap.perhitungan,
      CalibrationStatus.disetujui =>
        s.certificateId == null ? _Tahap.sertifikat : _Tahap.kirim,
    };

class _LencanaTahap extends StatelessWidget {
  const _LencanaTahap({required this.sesi, required this.tahap});

  final CalibrationHistoryItem sesi;
  final _Tahap tahap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final (label, nada, ikon) = switch (sesi.status) {
      CalibrationStatus.draft => (
          l10n.historyStatusDraft,
          BadgeTone.neutral,
          Icons.edit_note,
        ),
      CalibrationStatus.perluRevisi => (
          l10n.historyStatusPerluRevisi,
          BadgeTone.danger,
          Icons.undo,
        ),
      CalibrationStatus.menungguApproval => (
          l10n.historyStatusMenungguApproval,
          BadgeTone.warning,
          Icons.hourglass_empty,
        ),
      CalibrationStatus.disetujui => (
          sesi.nomorSertifikat ?? l10n.alurStatusDisetujui,
          BadgeTone.success,
          Icons.workspace_premium_outlined,
        ),
    };

    return StatusBadge(label: label, tone: nada, icon: ikon);
  }
}

class _PanelTahapan extends ConsumerWidget {
  const _PanelTahapan({required this.sesi});

  final CalibrationHistoryItem sesi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tahap = _tahapDari(sesi);
    final peran = ref.watch(authProvider).value?.role;

    final langkah = <(_Tahap, String)>[
      (_Tahap.lembarKerja, l10n.alurTahapLembarKerja),
      (_Tahap.perhitungan, l10n.alurTahapPerhitungan),
      (_Tahap.sertifikat, l10n.alurTahapSertifikat),
      (_Tahap.kirim, l10n.alurTahapKirim),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          sesi.namaAlat,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sesi.namaTeknisi,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        if (sesi.status == CalibrationStatus.perluRevisi &&
            (sesi.catatanRevisi?.isNotEmpty ?? false)) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              l10n.alurCatatanRevisi(sesi.catatanRevisi!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        for (var i = 0; i < langkah.length; i++)
          _Langkah(
            nomor: i + 1,
            label: langkah[i].$2,
            keadaan: langkah[i].$1.index < tahap.index
                ? _Keadaan.selesai
                : langkah[i].$1 == tahap
                    ? _Keadaan.sekarang
                    : _Keadaan.nanti,
            terakhir: i == langkah.length - 1,
          ),

        const SizedBox(height: AppSpacing.lg),
        _TombolLangkah(sesi: sesi, tahap: tahap, peran: peran),

        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CalibrationDetailScreen(calibrationId: sesi.id),
              ),
            ),
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(l10n.alurDetailSesi),
          ),
        ),
      ],
    );
  }
}

enum _Keadaan { selesai, sekarang, nanti }

class _Langkah extends StatelessWidget {
  const _Langkah({
    required this.nomor,
    required this.label,
    required this.keadaan,
    required this.terakhir,
  });

  final int nomor;
  final String label;
  final _Keadaan keadaan;
  final bool terakhir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final warna = switch (keadaan) {
      _Keadaan.selesai => theme.colorScheme.primary,
      _Keadaan.sekarang => theme.colorScheme.primary,
      _Keadaan.nanti => theme.colorScheme.outlineVariant,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: keadaan == _Keadaan.nanti
                      ? Colors.transparent
                      : theme.colorScheme.primary,
                  border: Border.all(color: warna, width: 2),
                  shape: BoxShape.circle,
                ),
                child: keadaan == _Keadaan.selesai
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : Text(
                        '$nomor',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: keadaan == _Keadaan.sekarang
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              if (!terakhir)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: keadaan == _Keadaan.selesai
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: terakhir ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: keadaan == _Keadaan.sekarang
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: keadaan == _Keadaan.nanti
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  if (keadaan != _Keadaan.nanti)
                    Text(
                      keadaan == _Keadaan.sekarang
                          ? l10n.alurLangkahSekarang
                          : l10n.alurLangkahSelesai,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu tombol: langkah berikutnya, bukan daftar semua yang mungkin.
///
/// Tombol yang nggak boleh dipencet role ini nggak ditampilin — teknisi nggak
/// dikasih "buka lembar perhitungan" cuma buat ditolak `403` waktu diklik.
class _TombolLangkah extends ConsumerWidget {
  const _TombolLangkah({
    required this.sesi,
    required this.tahap,
    required this.peran,
  });

  final CalibrationHistoryItem sesi;
  final _Tahap tahap;
  final UserRole? peran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final bolehSetujui = ref.bolehkah(
      NamaIzin.kalibrasiSetujui,
      cadangan: peran.adminSaja,
    );
    final bolehKirim = ref.bolehkah(
      NamaIzin.sertifikatKirim,
      cadangan: peran.adminSaja,
    );
    final bolehInput = ref.bolehkah(
      NamaIzin.kalibrasiBuat,
      cadangan: peran.bisaMenulis,
    );

    void buka(Widget layar) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => layar),
        );

    final (label, ikon, aksi) = switch (tahap) {
      _Tahap.lembarKerja => (
          l10n.alurBukaLembarKerja,
          Icons.edit_note,
          bolehInput
              // Profil WAJIB ikut dioper. Tanpa ini `LembarKerjaScreen` jatuh ke
              // default `ph_meter`, jadi melanjutkan draft / mbenerin lembar
              // Chlorine atau Turbidimeter yang dikembalikan admin bakal
              // ngambil formulir pH: 3 titik 4/7/10,01 padahal alatnya 2 titik
              // 1,74/1,83 mg/L, satuan & kode dokumennya juga ikut salah.
              //
              // Efeknya nyampe ke KAMERA, bukan cuma tampilan: tombol foto tabel
              // ngirim `nominal` & `satuan` dari titik yang kebentuk di layar
              // sebagai petunjuk ke AI. Formulir pH di atas lembar chlorine
              // bikin AI dikasih tahu "harap 3 kolom di 4/7/10,01" buat foto
              // yang isinya 2 kolom 1,74/1,83 — angkanya mendarat di sel yang
              // salah, dan hasilnya kebaca sebagai "kameranya meleset".
              //
              // Alat yang nggak punya lembar khusus tetap `ph_meter`, sama
              // kayak default lama — nggak ada perilaku yang berubah di situ.
              ? () => buka(LembarKerjaScreen(
                    sesiId: sesi.id,
                    profil: profilLembarKerjaUntuk(sesi.namaAlat) ?? 'ph_meter',
                  ))
              : null,
        ),
      _Tahap.perhitungan => (
          l10n.alurBukaPerhitungan,
          Icons.calculate_outlined,
          bolehSetujui
              ? () => buka(PerhitunganScreen(calibrationId: sesi.id))
              : null,
        ),
      _Tahap.sertifikat => (
          l10n.alurLihatSertifikat,
          Icons.workspace_premium_outlined,
          () => buka(CertificateScreen(calibrationId: sesi.id)),
        ),
      _Tahap.kirim => (
          l10n.alurKirimPelanggan,
          Icons.mail_outline,
          bolehKirim && sesi.certificateId != null
              ? () => buka(
                    KirimEmailScreen(
                      certificateId: sesi.certificateId!,
                      nomorSertifikat: sesi.nomorSertifikat ?? '—',
                    ),
                  )
              : null,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          // Ukurannya ditentuin sendiri: tema masang minimumSize lebar tak
          // terbatas ke semua tombol app, dan itu bener buat HP tapi bikin
          // tombol desktop melar sepanjang panel.
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            onPressed: aksi,
            icon: Icon(ikon, size: 18),
            label: Text(label),
          ),
        ),
        // Sesi udah disetujui tapi sertifikatnya belum jadi: bukan error, cuma
        // job antrean backend yang belum kelar. Dibilangin apa adanya biar
        // nggak dikira nyangkut.
        if (tahap == _Tahap.sertifikat) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.alurSertifikatDigenerate,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ potongan

class _BelumMilih extends StatelessWidget {
  const _BelumMilih({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            pesan,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CalibrationInputScreen(),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.alurSesiBaru),
          ),
        ],
      ),
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.historyLoadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onCobaLagi,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.historyRetry),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) =>
          const SkeletonBox(height: 72, width: double.infinity),
    );
  }
}
