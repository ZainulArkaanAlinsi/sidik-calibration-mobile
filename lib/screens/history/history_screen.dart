import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../certificate/sertifikat_sukses_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../models/validasi.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/history_provider.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../widgets/app_button.dart';
import '../../widgets/master_detail_pane.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/notification_bell.dart';
import '../admin/widgets/panel_temuan.dart';
import 'calibration_detail_screen.dart';

/// Riwayat kalibrasi — sama pola 4-state-nya kayak Dashboard
/// (`loading` skeleton · `empty` · `normal` daftar sesi · `error` + coba
/// lagi), biar teknisi/admin nggak bingung ketemu dua behavior beda buat
/// masalah yang sama (jaringan lemot, sesi habis, dst).
///
/// Admin dapat tambahan: tombol setujui/tolak langsung di kartu sesi yang
/// `menunggu_approval` — nggak ada layar approval terpisah, biar admin
/// nggak perlu loncat-loncat antara "lihat riwayat" dan "approve sesuatu".
/// Di jendela lebar layar ini jadi **panel ganda**: daftar sesi tetap
/// kelihatan di kiri, detailnya kebuka di kanan. Buat admin yang memeriksa
/// sesi satu per satu, itu ngilangin bolak-balik push–back tiap ganti sesi.
/// Di HP perilakunya nggak berubah sama sekali: tap kartu → push layar detail.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with WidgetsBindingObserver {
  /// Sesi yang lagi kebuka di panel kanan. Null = belum ada yang dipilih.
  /// Cuma dipakai waktu panel ganda aktif; di mode satu panel detailnya
  /// di-push, bukan disimpen di sini.
  int? _terpilih;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Balik ke jendela/app ini → tarik ulang daftarnya.
  ///
  /// Daftar riwayat itu satu-satunya layar yang nampilin keputusan orang lain
  /// (admin nyetujui, teknisi ngirim ulang), jadi dia paling gampang basi. Yang
  /// mestinya ngabarin itu broadcast realtime, TAPI `realtimeSyncProvider`
  /// jatuh ke [MockRealtimeService] begitu kunci Reverb kosong — dan itu
  /// keadaan normal di dev. Akibatnya: sesi ditolak lewat HP, jendela macOS
  /// tetap nulis "Menunggu approval" sampai app-nya dimatiin. Dua perangkat
  /// nunjuk database yang sama tapi cerita beda, dan yang kelihatan salah
  /// justru layarnya, bukan sinkronnya.
  ///
  /// Nggak nunggu selesai & nggak nampilin loading: ini penyegaran latar, dan
  /// daftar lama tetap kepakai sampai yang baru dateng.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    unawaited(ref.read(historyProvider.notifier).muatUlang());
  }

  /// Dipanggil dari kartu. [panelGanda] dateng dari tata letak yang lagi
  /// aktif — bukan dari `Platform`, karena jendela desktop yang disempitin
  /// pantas dapet perilaku HP.
  void _pilih(CalibrationHistoryItem item, {required bool panelGanda}) {
    if (panelGanda) {
      setState(() => _terpilih = item.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalibrationDetailScreen(calibrationId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riwayat = ref.watch(historyProvider);
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    // Urutan cek sama kayak dashboard: data dulu, baru error, baru loading —
    // biar retry Riverpod yang jalan di belakang layar nggak nyangkut di
    // skeleton selamanya (lihat komentar di dashboard_screen.dart).
    final data = riwayat.value;

    // Dibikin fungsi, bukan variabel, karena daftarnya perlu tau lagi mode
    // apa — dan itu baru ketauan di dalam [MasterDetailPane].
    Widget isi(bool panelGanda) {
      if (data != null) {
        return data.isEmpty
            ? const _Kosong()
            : _Isi(
                items: data,
                isAdmin: isAdmin,
                // Sorotan cuma masuk akal kalau detailnya emang lagi kebuka di
                // sebelahnya. Di satu panel, kartu "terpilih" nggak ada artinya.
                terpilih: panelGanda ? _terpilih : null,
                onPilih: (item) => _pilih(item, panelGanda: panelGanda),
              );
      }
      if (riwayat.hasError) {
        return _Gagal(
          pesan: riwayat.error is TokenHilangException
              ? l10n.historySessionExpired
              : l10n.historyLoadFailed,
          onCobaLagi: () => ref.read(historyProvider.notifier).muatUlang(),
        );
      }
      return const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHistory),
        // Pintasan Arsip di sini sengaja dibuang: spesifikasi poin 7 minta
        // bagian "Folder" dihapus dari Riwayat, karena penelusuran folder
        // pindah SELURUHNYA ke Folder Manager di navbar bawah. Dua pintu ke
        // hal yang sama cuma bikin orang ragu mana yang bener.
        // `RefreshIndicator` di bawah cuma kepanggil sama gestur TARIK, dan
        // di desktop gestur itu nggak ada — jadi tanpa tombol ini jendela
        // macOS nggak punya cara nyegerin daftar sama sekali selain dimatiin.
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.historySegarkan,
            onPressed: () => ref.read(historyProvider.notifier).muatUlang(),
          ),
          const NotificationBell(),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: MasterDetailPane(
        master: (context, panelGanda) => RefreshIndicator(
          onRefresh: () => ref.read(historyProvider.notifier).muatUlang(),
          child: ReadableWidth(child: isi(panelGanda)),
        ),
        detail: _terpilih == null
            ? null
            : CalibrationDetailScreen(calibrationId: _terpilih!),
        kosong: PanePlaceholder(
          icon: Icons.fact_check_outlined,
          judul: l10n.detailPaneEmptyTitle,
          pesan: l10n.detailPaneEmptyBody,
        ),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({
    required this.items,
    required this.isAdmin,
    required this.terpilih,
    required this.onPilih,
  });

  final List<CalibrationHistoryItem> items;
  final bool isAdmin;

  /// Id sesi yang lagi kebuka di panel kanan. Null = nggak ada yang disorot.
  final int? terpilih;

  final void Function(CalibrationHistoryItem item) onPilih;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return _HistoryCard(
          item: item,
          isAdmin: isAdmin,
          disorot: item.id == terpilih,
          onTap: () => onPilih(item),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.isAdmin,
    required this.disorot,
    required this.onTap,
  });

  final CalibrationHistoryItem item;
  final bool isAdmin;

  /// Sesi ini yang lagi kebuka di panel kanan.
  final bool disorot;

  final VoidCallback onTap;

  StatusBadge _badge(AppLocalizations l10n) {
    if (item.status == CalibrationStatus.disetujui) {
      return switch (item.keputusan) {
        Keputusan.pass => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
        Keputusan.fail => StatusBadge(
          label: l10n.historyStatusFail,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        ),
        null => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
      };
    }

    return switch (item.status) {
      CalibrationStatus.draft => StatusBadge(
        label: l10n.historyStatusDraft,
        tone: BadgeTone.neutral,
        icon: Icons.edit_note,
      ),
      CalibrationStatus.menungguApproval => StatusBadge(
        label: l10n.historyStatusMenungguApproval,
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      CalibrationStatus.perluRevisi => StatusBadge(
        label: l10n.historyStatusPerluRevisi,
        tone: BadgeTone.warning,
        icon: Icons.edit_outlined,
      ),
      CalibrationStatus.disetujui => throw StateError('unreachable'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final tanggal = DateFormat('d MMM yyyy', locale).format(
      item.tanggalKalibrasi,
    );

    return Card(
      // Kartu yang lagi kebuka di panel kanan dikasih garis tepi aksen, bukan
      // warna latar beda: latar beda bakal berantem sama badge status yang
      // udah pakai warna buat nyampein PASS/FAIL/menunggu.
      shape: disorot
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikon jenis alat — bikin kartu lebih gampang dipindai
                  // (mata langsung ke jenis alatnya), gaya kartu referensi.
                  _IkonAlat(nama: item.namaAlat),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.namaAlat,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.namaTeknisi} · $tanggal',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // Kapan barisnya TERAKHIR bergerak — beda dari tanggal
                        // kalibrasi di atas, dan ini yang mbedain beberapa sesi
                        // yang tanggal kalibrasinya sama persis.
                        if (item.waktuTerakhir != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            waktuRelatif(
                              item.waktuTerakhir!,
                              locale,
                              hariIni: l10n.waktuHariIni,
                              kemarin: l10n.waktuKemarin,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (item.nomorSertifikat != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.historyCertNumber(item.nomorSertifikat!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _badge(l10n),
                ],
              ),
              if (item.status == CalibrationStatus.perluRevisi &&
                  item.catatanRevisi != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.historyCatatanRevisi(item.catatanRevisi!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              if (isAdmin && item.status == CalibrationStatus.menungguApproval) ...[
                const SizedBox(height: AppSpacing.sm),
                _ApprovalActions(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ikon jenis alat dalam kotak membulat lembut. Ikonnya dicocokin lewat
/// keyword nama (sumbernya teks bebas), dengan fallback ikon "ukur" generik.
class _IkonAlat extends StatelessWidget {
  const _IkonAlat({required this.nama});

  final String nama;

  IconData get _ikon {
    final n = nama.toLowerCase();
    return switch (n) {
      _ when n.contains('ph meter') => Icons.science_outlined,
      _ when n.contains('turbidi') => Icons.blur_on_outlined,
      _ when n.contains('conductivity') => Icons.bolt_outlined,
      _ when n.contains('thermo') || n.contains('termo') =>
        Icons.device_thermostat_outlined,
      _ when n.contains('timbang') => Icons.scale_outlined,
      _ when n.contains('oven') || n.contains('furnace') =>
        Icons.local_fire_department_outlined,
      _ when n.contains('pipet') || n.contains('buret') => Icons.science_outlined,
      _ when n.contains('caliper') || n.contains('micrometer') =>
        Icons.straighten_outlined,
      _ => Icons.straighten_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_ikon, size: 21, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Tombol setujui/tolak — komponen sendiri (bukan langsung di `_HistoryCard`)
/// biar bisa nyimpen state `_busy` lokal: dua tombol ini harus nonaktif
/// bareng begitu salah satu dipencet, daripada admin nggak sabar mencet dua
/// kali dan approve-nya dobel keproses.
class _ApprovalActions extends ConsumerStatefulWidget {
  const _ApprovalActions({required this.item});

  final CalibrationHistoryItem item;

  @override
  ConsumerState<_ApprovalActions> createState() => _ApprovalActionsState();
}

class _ApprovalActionsState extends ConsumerState<_ApprovalActions> {
  bool _busy = false;

  /// Dipegang State, BUKAN dibikin ulang tiap `_tolak()`.
  ///
  /// Dulu dibikin lokal di dalam `_tolak()` dan nggak pernah di-dispose sama
  /// sekali — tiap penolakan nyisain satu controller hidup selama app jalan,
  /// dan admin nekan tombol ini puluhan kali sehari.
  ///
  /// Mem-dispose-nya di ujung `_tolak()` BUKAN jalan keluarnya: `showDialog`
  /// kelar begitu route-nya di-pop, sementara `TextField`-nya masih kepasang
  /// selama animasi nutup — controller yang udah dibuang kepakai lagi di situ
  /// dan Flutter langsung ngelempar "A TextEditingController was used after
  /// being disposed". Ditaruh di State: sekali bikin, dibuang waktu layarnya
  /// ilang, dan isinya dikosongin tiap dialog dibuka.
  final _catatanTolak = TextEditingController();

  @override
  void dispose() {
    _catatanTolak.dispose();
    super.dispose();
  }

  /// Setujui sesi ini.
  ///
  /// [abaikanPeringatan] cuma `true` kalau admin barusan lihat daftar
  /// temuannya di [_konfirmasiPeringatan] dan tetap mutusin lanjut.
  Future<void> _setujui({bool abaikanPeringatan = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    try {
      await ref
          .read(historyProvider.notifier)
          .approve(widget.item.id, abaikanPeringatan: abaikanPeringatan);

      if (!mounted) return;

      // Begitu disetujui, sertifikatnya langsung dikeluarin di sini —
      // unduh/QR/tautan/kirim ada di satu lembar, nggak usah dicari lagi ke
      // menu lain. Sheet-nya cuma dibuka kalau nomornya emang udah balik:
      // pembuatan PDF-nya job antrean backend, dan kadang belum kelar persis
      // waktu approve balik. Kalau belum, Alur Kerja yang nunjukin statusnya.
      final terbaru = ref
          .read(historyProvider)
          .value
          ?.where((s) => s.id == widget.item.id)
          .firstOrNull;

      // Syaratnya CUMA id. `approve` balikinnya `certificate_id` doang —
      // nomornya nggak ikut, jadi nunggu nomor di sini bikin popup-nya nggak
      // pernah muncul sama sekali. Sheet-nya yang narik nomor + token sendiri.
      final certId = terbaru?.certificateId;

      if (certId != null) {
        await tampilkanSertifikatSukses(
          context,
          certificateId: certId,
          nomor: terbaru?.nomorSertifikat,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      // Backend nolak sekali dengan 422 + `butuh_konfirmasi` waktu ada
      // PERINGATAN (bukan error): dia minta admin lihat temuannya dulu.
      //
      // Dulu di sini semua kegagalan diperlakukan sama, jadi yang muncul cuma
      // snackbar berisi teks exception mentah. Akibatnya, dari layar ini admin
      // nggak bisa tau apa peringatannya — apalagi mutusin. Sesi Turbidimeter
      // `KAL/2026/08/0031` lolos dengan `kelembaban_awal = 2 %RH` (52 kepencet
      // jadi 2) dan sertifikatnya kecetak `%RH: 27% ± 53,2%` — ketidakpastian
      // dua kali nilainya sendiri, di dokumen terakreditasi.
      //
      // Validatornya sendiri udah bener dan udah teriak dua kali. Yang bolong
      // jalannya ke mata admin.
      final validasi = _peringatanDari(e);

      if (validasi != null) {
        setState(() => _busy = false);

        if (await _konfirmasiPeringatan(validasi) && mounted) {
          await _setujui(abaikanPeringatan: true);
        }

        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyApproveFailed(e.message))),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyApproveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Temuan di balik penolakan 422, atau null kalau gagalnya karena hal lain
  /// (jaringan, sesi habis, sesi udah disetujui orang lain).
  HasilValidasi? _peringatanDari(ApiException e) {
    if (e.status != 422 || !e.butuhKonfirmasi) return null;

    final validasi = e.body['validasi'];
    if (validasi is! Map<String, dynamic>) return null;

    return HasilValidasi.fromJson(validasi);
  }

  /// Daftar temuannya ditampilin apa adanya, lalu admin mutusin.
  ///
  /// Tombol lanjutnya sengaja BUKAN "OK": yang diputuskan di sini itu
  /// nerbitin sertifikat terakreditasi di atas data yang sistemnya sendiri
  /// bilang janggal, jadi tulisannya mesti nyebut itu.
  Future<bool> _konfirmasiPeringatan(HasilValidasi validasi) async {
    final l10n = AppLocalizations.of(context);

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.historyPeringatanJudul),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.historyPeringatanBody),
              const SizedBox(height: AppSpacing.md),
              PanelTemuan(validasi: validasi),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.historyPeringatanBatal),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.historyPeringatanLanjut),
          ),
        ],
      ),
    );

    return lanjut ?? false;
  }

  Future<void> _tolak() async {
    final l10n = AppLocalizations.of(context);
    final controller = _catatanTolak..clear();

    final catatan = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.historyRejectDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.historyRejectDialogHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.historyRejectDialogCancel),
          ),
          TextButton(
            onPressed: () {
              final teks = controller.text.trim();
              if (teks.isEmpty) return;
              Navigator.of(dialogContext).pop(teks);
            },
            child: Text(l10n.historyRejectDialogSubmit),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (catatan == null) return; // dibatalin
    if (catatan.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.historyRejectDialogEmpty)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    try {
      await ref
          .read(historyProvider.notifier)
          .reject(widget.item.id, catatan);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyRejectFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.historyReject,
            variant: AppButtonVariant.secondary,
            isLoading: _busy,
            onPressed: _busy ? null : _tolak,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton(
            label: l10n.historyApprove,
            isLoading: _busy,
            onPressed: _busy ? null : _setujui,
          ),
        ),
      ],
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.history_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.historyEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.historyEmptyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).historyRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 160),
              const SizedBox(height: AppSpacing.xs),
              const SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
