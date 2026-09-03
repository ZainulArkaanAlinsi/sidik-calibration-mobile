import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

/// Nada warna badge. Nggak nyebut warna langsung ("hijau"), tapi maknanya —
/// biar kalau paletnya diganti, artinya tetap sama.
enum BadgeTone { success, danger, warning, info, neutral }

/// Badge status — dipakai buat hasil kalibrasi (PASS/FAIL), status alat
/// (aktif/overdue), status sesi (draft/menunggu approval/dst), dan status
/// Order (baru/diproses/selesai/dibatalkan).
///
/// Selalu bawa **ikon + teks**, bukan cuma warna: teknisi yang buta warna
/// tetap harus bisa bedain PASS dan FAIL. Ini bukan hiasan — hasil kalibrasi
/// itu data yang dipertanggungjawabkan.
///
/// ## Kenapa labelnya diselesaikan di [build], bukan di konstruktor
///
/// [StatusBadge.fromApi] dipanggil dari tempat yang **belum tentu punya**
/// `BuildContext` — dan memang begitu bentuknya sejak awal: dia `factory` yang
/// memulangkan widget jadi. Jadi bahasanya dulu tidak bisa ikut, dan ketiga
/// belas labelnya dieja keras di sini.
///
/// Yang bikin itu bukan sekadar "belum dilokalkan": LIMA di antaranya **sudah
/// punya kunci l10n** dan dipakai layar lain —
/// `historyStatusPass/Fail/Draft/MenungguApproval/PerluRevisi` di
/// `history_screen`, `certificate_screen`, `calibration_detail_screen`, dan
/// `alur_kerja_screen`. Jadi status yang SAMA tampil "Pending approval" di
/// daftar riwayat dan "Menunggu approval" di daftar alat, di aplikasi yang
/// sama, buat pengguna yang sama.
///
/// Bentuk sekarang memisahkan dua hal yang memang beda umurnya:
///
///  - [artiApi] — nada & ikon. **Tidak menyentuh bahasa**, jadi tetap bisa
///    diuji di luar widget tree, dan tetap benar walau locale-nya berganti di
///    tengah jalan.
///  - [labelApi] — kata-katanya, diselesaikan dari `AppLocalizations` yang
///    sedang berlaku.
///
/// Konstruktornya tetap `const` dan pemanggilnya tidak berubah satu pun.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required String label,
    required BadgeTone tone,
    IconData? icon,
  }) : _label = label,
       _tone = tone,
       _icon = icon,
       _kodeApi = null;

  /// Bikin badge langsung dari nilai yang dikirim API.
  ///
  /// Nilai enum-nya ngikutin `docs/kontrak-api.md` — kalau backend ganti, yang
  /// diubah cuma [artiApi] dan [labelApi].
  const StatusBadge.fromApi(String value, {super.key})
    : _kodeApi = value,
      _label = null,
      _tone = null,
      _icon = null;

  final String? _label;
  final BadgeTone? _tone;
  final IconData? _icon;

  /// Kode mentah dari API. Null kalau badge-nya dibikin dengan label eksplisit.
  final String? _kodeApi;

  /// Nada & ikon satu kode status — **tanpa menyentuh bahasa sama sekali**.
  ///
  /// Dipisah dari labelnya dengan sengaja: yang ini bagian yang dipertaruhkan
  /// buat teknisi yang buta warna, dan dia harus bisa dibuktikan test tanpa
  /// perlu membangun widget tree atau memilih locale.
  static ({BadgeTone nada, IconData? ikon}) artiApi(String value) =>
      switch (value) {
        'PASS' => (nada: BadgeTone.success, ikon: Icons.check_circle_outline),
        'FAIL' => (nada: BadgeTone.danger, ikon: Icons.cancel_outlined),
        'aktif' => (nada: BadgeTone.success, ikon: Icons.check_circle_outline),
        'overdue' => (nada: BadgeTone.warning, ikon: Icons.schedule),
        'nonaktif' => (
          nada: BadgeTone.neutral,
          ikon: Icons.remove_circle_outline,
        ),
        'draft' => (nada: BadgeTone.neutral, ikon: Icons.edit_note),
        'menunggu_approval' => (
          nada: BadgeTone.info,
          ikon: Icons.hourglass_empty,
        ),
        'disetujui' => (nada: BadgeTone.success, ikon: Icons.verified_outlined),
        'perlu_revisi' => (nada: BadgeTone.warning, ikon: Icons.edit_outlined),
        // Status Order (`Order::STATUS_*` di backend).
        'baru' => (nada: BadgeTone.info, ikon: Icons.fiber_new_outlined),
        'diproses' => (nada: BadgeTone.warning, ikon: Icons.autorenew),
        'selesai' => (nada: BadgeTone.success, ikon: Icons.task_alt),
        // Ikonnya sengaja BUKAN `cancel_outlined` yang dipakai FAIL. Order yang
        // dibatalkan itu pekerjaan yang tidak jadi; FAIL itu alat yang tidak
        // lolos. Dua hal yang tidak boleh terbaca sama sekilas.
        'dibatalkan' => (
          nada: BadgeTone.danger,
          ikon: Icons.do_not_disturb_on_outlined,
        ),
        // Status yang belum dikenal tetap ditampilkan apa adanya, bukan bikin
        // app crash — kalau backend nambah status baru, kelihatan di UI.
        _ => (nada: BadgeTone.neutral, ikon: null),
      };

  /// Kata-kata satu kode status, dalam bahasa yang sedang berlaku.
  ///
  /// Lima yang pertama memakai kunci `historyStatus*` yang **sudah ada** —
  /// bukan bikin kunci baru yang isinya sama. Namanya memang tidak lagi cocok
  /// (dia sudah lama dipakai di luar layar Riwayat), tapi menggantinya berarti
  /// menyentuh 17 pemanggil di empat layar yang sudah benar, demi nama kunci
  /// yang tidak pernah dilihat pengguna. Dua terjemahan untuk satu status
  /// justru bencana yang mau dihindari berkas ini.
  static String labelApi(String value, AppLocalizations l10n) =>
      switch (value) {
        'PASS' => l10n.historyStatusPass,
        'FAIL' => l10n.historyStatusFail,
        'draft' => l10n.historyStatusDraft,
        'menunggu_approval' => l10n.historyStatusMenungguApproval,
        'perlu_revisi' => l10n.historyStatusPerluRevisi,
        'aktif' => l10n.statusAktif,
        'overdue' => l10n.statusOverdue,
        'nonaktif' => l10n.statusNonaktif,
        'disetujui' => l10n.statusDisetujui,
        'baru' => l10n.statusBaru,
        'diproses' => l10n.statusDiproses,
        'selesai' => l10n.statusSelesai,
        'dibatalkan' => l10n.statusDibatalkan,
        // Sama seperti [artiApi]: status baru dari backend tampil apa adanya.
        // Menerjemahkannya mustahil, menyembunyikannya lebih buruk.
        _ => value,
      };

  BadgeTone get tone => _tone ?? artiApi(_kodeApi!).nada;

  IconData? get icon => _icon ?? artiApi(_kodeApi!).ikon;

  /// Label yang benar-benar tercetak. Butuh [l10n] karena badge dari
  /// [StatusBadge.fromApi] baru tahu kata-katanya waktu bahasanya diketahui.
  String labelUntuk(AppLocalizations l10n) =>
      _label ?? labelApi(_kodeApi!, l10n);

  Color _color(BuildContext context, ColorScheme scheme) => switch (tone) {
    BadgeTone.success => AppColors.statusSukses(context),
    BadgeTone.danger => AppColors.statusBahaya(context),
    BadgeTone.warning => AppColors.statusPeringatan(context),
    BadgeTone.info => AppColors.statusInfo(context),
    BadgeTone.neutral => scheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(context, theme.colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            labelUntuk(AppLocalizations.of(context)),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 0.65,
            ),
          ),
        ],
      ),
    );
  }
}
