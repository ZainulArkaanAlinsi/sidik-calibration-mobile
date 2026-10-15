/// Studio Data Acuan (CR-48) — gerbang izin, aturan peran, dan keadaan layar
/// (memuat · kosong · galat · tanpa izin) yang dipakai S1/S2/S3/S7.
///
/// **Aturan siapa melihat apa milik SERVER.** Yang ada di sini cuma cerminnya,
/// supaya layar tidak menawarkan tombol yang pasti dijawab 404. Kalau server
/// mengubah aturannya, cermin ini yang wajib ikut — bukan sebaliknya.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/sidik_material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/data_acuan.dart';
import '../../../models/izin.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../../providers/izin_provider.dart';
import '../../../services/auth_service.dart' show AuthException;
import '../../../widgets/sidik/sidik_status.dart';
import '../../../widgets/skeleton.dart';

/// Cadangan izin `data-acuan.lihat` selama server belum menyebutnya: TIDAK.
///
/// Menu lain memakai aturan peran LAMA sebagai cadangan (`hakAdmin`), karena
/// sebelum matriks izin ada, aturan itu yang berlaku. Data acuan tidak punya
/// aturan lama — fiturnya lahir bersama izinnya. Dan `MatriksIzin::bolehUntuk`
/// (repo API) sengaja TIDAK memasukkan izin yang rutenya tidak terdaftar,
/// jadi server yang belum punya rute `/data-acuan/*` tidak pernah menyebut
/// `data-acuan.lihat`. Cadangan `true` di sini berarti menawarkan pintu ke
/// rute yang di server itu dijawab 404.
const cadanganIzinDataAcuan = false;

/// Gerbang menu (drawer HP/tablet & seksi panel desktop).
bool bolehBukaDataAcuan(WidgetRef ref) =>
    ref.bolehkah(NamaIzin.dataAcuanLihat, cadangan: cadanganIzinDataAcuan);

/// Peran menurut server (`/me/permissions`) bila sudah ada, kalau belum peran
/// yang tersimpan saat login.
UserRole? peranDataAcuan(WidgetRef ref) =>
    ref.watch(izinProvider).value?.role ?? ref.watch(authProvider).value?.role;

/// Cermin `DataAcuanController::bolehLihatSemua()` (repo API): semua peran
/// KECUALI teknisi. Teknisi cuma melihat versi `aktif`; banding & riwayat sel
/// dijawab 404 untuknya.
bool bolehLihatSemuaVersiAcuan(UserRole? peran) =>
    peran != null && peran != UserRole.teknisi;

/// Pesan galat yang layak tampil. Pesan server (`AuthException`) apa adanya;
/// selain itu kalimat umum — jangan pernah membocorkan teks exception mentah.
String pesanGalatAcuan(Object galat, AppLocalizations l10n) => switch (galat) {
  AuthException(:final message) when message.isNotEmpty => message,
  TokenHilangException() => '$galat',
  _ => l10n.acuanGagalMuat,
};

/// Label status versi (`aktif`, `draf`, …). Status yang belum dikenal
/// aplikasi ini ditampilkan kode mentahnya, bukan ditebak.
String labelStatusVersiAcuan(String kode, AppLocalizations l10n) =>
    switch (StatusVersiAcuan.dariKode(kode)) {
      StatusVersiAcuan.draf => l10n.acuanStatusDraf,
      StatusVersiAcuan.diajukan => l10n.acuanStatusDiajukan,
      StatusVersiAcuan.terjadwal => l10n.acuanStatusTerjadwal,
      StatusVersiAcuan.aktif => l10n.acuanStatusAktif,
      StatusVersiAcuan.pensiun => l10n.acuanStatusPensiun,
      StatusVersiAcuan.ditolak => l10n.acuanStatusDitolak,
      StatusVersiAcuan.ditarik => l10n.acuanStatusDitarik,
      StatusVersiAcuan.dibuang => l10n.acuanStatusDibuang,
      StatusVersiAcuan.tidakDikenal => kode,
    };

/// Lencana status versi — nada ikut arti tetap `NadaStatus`.
class LencanaVersiAcuan extends StatelessWidget {
  const LencanaVersiAcuan(this.kodeStatus, {super.key});

  final String kodeStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = labelStatusVersiAcuan(kodeStatus, l10n);

    final (nada, ikon) = switch (StatusVersiAcuan.dariKode(kodeStatus)) {
      StatusVersiAcuan.aktif => (NadaStatus.lulus, Icons.check_circle_outline),
      StatusVersiAcuan.terjadwal => (NadaStatus.tunggu, Icons.schedule),
      StatusVersiAcuan.diajukan => (NadaStatus.tunggu, Icons.hourglass_empty),
      StatusVersiAcuan.ditolak => (NadaStatus.gagal, Icons.block),
      StatusVersiAcuan.draf => (NadaStatus.draf, Icons.edit_outlined),
      StatusVersiAcuan.pensiun => (NadaStatus.draf, Icons.archive_outlined),
      StatusVersiAcuan.ditarik => (NadaStatus.draf, Icons.undo),
      StatusVersiAcuan.dibuang => (NadaStatus.draf, Icons.delete_outline),
      StatusVersiAcuan.tidakDikenal => (NadaStatus.draf, Icons.help_outline),
    };

    return SidikLencana(StatusSidik(label, nada, ikon));
  }
}

/// Tanggal kalender (`berlaku_mulai`) — tanpa jam: kolomnya `date` di server.
String tanggalAcuan(DateTime tanggal, String locale) =>
    DateFormat('d MMM yyyy', locale).format(tanggal);

/// `ba1fa153…f585` — bentuk pendek di kontrak §15. Teks lengkapnya tetap
/// ditampilkan lewat tooltip/teks terpilih di tempat pemanggil.
String shaPendekAcuan(String sha) => sha.length <= 12
    ? sha
    : '${sha.substring(0, 8)}…${sha.substring(sha.length - 4)}';

/// "sejak 1 Jan 2024, tanpa batas akhir" / "1 Jan 2024 s.d. 31 Des 2025".
String teksBerlakuAcuan(
  DateTime? mulai,
  DateTime? sampai,
  AppLocalizations l10n,
  String locale,
) {
  if (mulai == null) return l10n.acuanBerlakuBelum;
  final dari = tanggalAcuan(mulai, locale);
  return sampai == null
      ? l10n.acuanBerlakuTerbuka(dari)
      : l10n.acuanBerlakuRentang(dari, tanggalAcuan(sampai, locale));
}

/// Gerbang layar: rute yang dibuka langsung (bukan dari menu) tanpa izin
/// `data-acuan.lihat` jatuh ke [ButuhIzinAcuan].
///
/// Izin yang belum sampai → kerangka (bukan "butuh izin" yang berkedip).
/// Izin yang GAGAL diambil → layar tetap dibuka dan server yang memutuskan;
/// menulis "butuh izin" hanya karena jaringan putus itu klaim palsu.
class GerbangDataAcuan extends ConsumerWidget {
  const GerbangDataAcuan({super.key, required this.judul, required this.child});

  final String judul;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izin = ref.watch(izinProvider);

    if (!izin.hasValue) {
      if (izin.hasError) return child;
      return Scaffold(
        appBar: AppBar(title: Text(judul)),
        body: const KerangkaDaftarAcuan(),
      );
    }

    final boleh = izin.requireValue.bolehkah(
      NamaIzin.dataAcuanLihat,
      cadangan: cadanganIzinDataAcuan,
    );
    if (boleh) return child;

    return Scaffold(
      appBar: AppBar(title: Text(judul)),
      body: const ButuhIzinAcuan(),
    );
  }
}

/// "Butuh izin data-acuan.lihat" (rancangan `Keadaan` · Tanpa izin).
class ButuhIzinAcuan extends StatelessWidget {
  const ButuhIzinAcuan({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KeadaanAcuan(
      ikon: Icons.lock_outline,
      judul: l10n.acuanButuhIzinJudul,
      keterangan: l10n.acuanButuhIzinKet,
    );
  }
}

/// Satu keadaan layar (kosong / tanpa izin / tidak tersedia): ikon, judul,
/// keterangan, dan opsional satu aksi. Selalu bisa digulir — teks yang
/// diperbesar 130% di HP 360dp tidak boleh terpotong, dan `RefreshIndicator`
/// butuh anak yang bisa ditarik.
class KeadaanAcuan extends StatelessWidget {
  const KeadaanAcuan({
    super.key,
    required this.ikon,
    required this.judul,
    this.keterangan,
    this.tambahan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String? keterangan;

  /// Baris kedua yang lebih kecil (mis. petunjuk khusus super admin).
  final String? tambahan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(ikon, size: 44, color: m.tinta2),
        const SizedBox(height: AppSpacing.md),
        Text(
          judul,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: m.tinta),
        ),
        if (keterangan != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            keterangan!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta2),
          ),
        ],
        if (tambahan != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            tambahan!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
          ),
        ],
        if (aksi != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(child: aksi),
        ],
      ],
    );
  }
}

/// Galat + Coba lagi.
class GalatAcuan extends StatelessWidget {
  const GalatAcuan({super.key, required this.galat, required this.onCobaLagi});

  final Object galat;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KeadaanAcuan(
      ikon: Icons.error_outline,
      judul: pesanGalatAcuan(galat, l10n),
      aksi: FilledButton.icon(
        onPressed: onCobaLagi,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.acuanCobaLagi),
      ),
    );
  }
}

/// Kerangka daftar (S1, garis waktu, banding, riwayat).
class KerangkaDaftarAcuan extends StatelessWidget {
  const KerangkaDaftarAcuan({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.md),
    children: List.generate(
      4,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: SkeletonBox(height: 72),
      ),
    ),
  );
}

/// Kerangka grid (S2): bilah tab + kepala + baris.
class KerangkaGridAcuan extends StatelessWidget {
  const KerangkaGridAcuan({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      const Row(
        children: [
          Expanded(child: SkeletonBox(height: 32)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: SkeletonBox(height: 32)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: SkeletonBox(height: 32)),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      for (var i = 0; i < 8; i++)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.xs),
          child: SkeletonBox(height: 40),
        ),
    ],
  );
}
