import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../models/calibration_history_item.dart';
import '../models/validasi.dart';
import '../providers/history_provider.dart';
import '../screens/admin/widgets/panel_temuan.dart';
import '../screens/certificate/sertifikat_sukses_sheet.dart';
import '../services/auth_service.dart' show ApiException;
import 'app_button.dart';

/// Tombol SETUJUI / TOLAK satu sesi.
///
/// ## Kenapa berkas sendiri, dan kenapa BUKAN di layar Riwayat
///
/// Dulu widget ini hidup di dalam `history_screen.dart` dan dipasang di tiap
/// kartu riwayat. Keputusan pemilik proyek 16 Sep 2026 mencabutnya dari sana:
/// **Riwayat itu daftar bacaan** — "apa saja yang pernah dikerjakan" — dan
/// menyetujui dari daftar berarti memutuskan tanpa melihat angka
/// perhitungannya. Yang memutuskan layar Antrean Approval.
///
/// `_busy` lokal dipegang di sini, bukan di kartunya: dua tombol ini harus
/// mati bareng begitu salah satu ditekan, daripada admin tidak sabar menekan
/// dua kali dan approve-nya dobel diproses.
class AksiApproval extends ConsumerStatefulWidget {
  const AksiApproval({super.key, required this.item});

  final CalibrationHistoryItem item;

  @override
  ConsumerState<AksiApproval> createState() => _AksiApprovalState();
}

class _AksiApprovalState extends ConsumerState<AksiApproval> {
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
      // Daftar riwayat DIPASTIKAN termuat dulu. `HistoryController.approve()`
      // berhenti diam-diam kalau `state.value == null`, dan di layar Antrean
      // daftar itu memang belum pernah ditarik — tombolnya jadi tidak
      // melakukan apa-apa, tanpa pesan apa pun. Ketahuan waktu test approval
      // dipindah ke Antrean, 16 Sep 2026.
      await ref.read(historyProvider.future);

      await ref
          .read(historyProvider.notifier)
          .approve(widget.item.id, abaikanPeringatan: abaikanPeringatan);

      // Antreannya ikut disegarkan: sesi yang barusan diputuskan tidak boleh
      // tetap duduk di daftar "menunggu saya periksa".
      ref.invalidate(antreanApprovalProvider);

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
      // Dulu semua kegagalan diperlakukan sama, jadi yang muncul cuma snackbar
      // berisi teks exception mentah — dari layar itu admin nggak bisa tau apa
      // peringatannya, apalagi mutusin. Sesi Turbidimeter `KAL/2026/08/0031`
      // lolos dengan `kelembaban_awal = 2 %RH` (52 kepencet jadi 2) dan
      // sertifikatnya kecetak `%RH: 27% ± 53,2%` — ketidakpastian dua kali
      // nilainya sendiri, di dokumen terakreditasi.
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
      // Lihat alasannya di `_setujui`.
      await ref.read(historyProvider.future);

      await ref.read(historyProvider.notifier).reject(widget.item.id, catatan);
      ref.invalidate(antreanApprovalProvider);
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
