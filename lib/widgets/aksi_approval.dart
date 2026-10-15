import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../models/calibration_detail.dart' show CalibrationDetail;
import '../models/calibration_history_item.dart';
import '../models/validasi.dart';
import '../providers/history_provider.dart';
import '../providers/perhitungan_provider.dart';
import '../screens/admin/widgets/dialog_setujui.dart';
import '../screens/admin/widgets/panel_temuan.dart';
import '../screens/certificate/sertifikat_sukses_sheet.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/kode_galat.dart';
import 'app_button.dart';
import 'galat_peran.dart';

/// Tombol SETUJUI satu sesi. (Tolak dicabut 15 Okt 2026, K-50-01: Master Data
/// mengoreksi lembarnya sendiri lewat Edit lembar, jejaknya di Bandingkan.)
///
/// ## Kenapa berkas sendiri, dan kenapa BUKAN di layar Riwayat
///
/// Dulu widget ini hidup di dalam `history_screen.dart` dan dipasang di tiap
/// kartu riwayat. Keputusan pemilik proyek 16 Sep 2026 mencabutnya dari sana:
/// **Riwayat itu daftar bacaan** — "apa saja yang pernah dikerjakan" — dan
/// menyetujui dari daftar berarti memutuskan tanpa melihat angka
/// perhitungannya. Yang memutuskan layar Antrean Approval.
///
/// `_busy` lokal dipegang di sini, bukan di kartunya: tombolnya harus mati
/// begitu ditekan, daripada admin tidak sabar menekan dua kali dan approve-nya
/// dobel diproses.
class AksiApproval extends ConsumerStatefulWidget {
  const AksiApproval({super.key, required this.item});

  final CalibrationHistoryItem item;

  @override
  ConsumerState<AksiApproval> createState() => _AksiApprovalState();
}

class _AksiApprovalState extends ConsumerState<AksiApproval> {
  bool _busy = false;

  /// Order Number sudah disimpan dari kartu ini — item daftarnya masih
  /// memegang nilai lama (kosong) sampai antreannya dimuat ulang.
  String? _nomorOrderDisimpan;

  /// Setujui = dialog Order Number + No. Sertifikat (K-49-14, K-50-04), lalu
  /// kirim. [isian] terisi waktu mengulang sesudah konfirmasi peringatan
  /// (dialog tidak ditanyakan lagi); [awal] + galat waktu server menolak nomor
  /// (dialog dibuka lagi dengan isian yang sama dan pesan di kotaknya).
  ///
  /// [abaikanPeringatan] cuma `true` kalau admin barusan lihat daftar
  /// temuannya di [_konfirmasiPeringatan] dan tetap mutusin lanjut.
  Future<void> _setujui({
    bool abaikanPeringatan = false,
    IsianSetujui? isian,
    IsianSetujui? awal,
    String? galatSertifikat,
    String? galatOrder,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    var data = isian;
    if (data == null) {
      // Sertifikat yang ditarik tidak minta nomor baru; itu hanya ada di
      // detail sesi, jadi dibaca dulu (sekali, lalu di-cache provider).
      CalibrationDetail? detail;
      try {
        detail = await ref.read(
          calibrationDetailProvider(widget.item.id).future,
        );
      } catch (_) {
        // Gagal dimuat: tetap minta nomornya, server yang memutuskan.
      }
      if (!mounted) return;

      final tersimpan =
          (_nomorOrderDisimpan ??
                  detail?.administrasi.nomorOrder ??
                  widget.item.nomorOrder ??
                  '')
              .trim();
      data = await mintaDataSetujui(
        context,
        nomorOrder: awal?.nomorOrder ?? tersimpan,
        nomorSertifikat: awal?.nomorSertifikat,
        tanpaNomorSertifikat: detail?.sertifikatDitarik ?? false,
        galatSertifikat: galatSertifikat,
        galatOrder: galatOrder,
      );
      if (data == null || !mounted) return;

      // Order Number tidak ikut di body approve: disimpan lewat PATCH /admin
      // dulu bila beda dari yang sudah tersimpan.
      if (data.nomorOrder != tersimpan) {
        setState(() => _busy = true);
        try {
          await ref
              .read(aksiAdminProvider(widget.item.id))
              .simpanKolomAdmin(nomorOrder: data.nomorOrder);
          _nomorOrderDisimpan = data.nomorOrder;
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('$e')));
          return;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        if (!mounted) return;
      }
    }
    final kiriman = data;

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
          .approve(
            widget.item.id,
            abaikanPeringatan: abaikanPeringatan,
            nomorSertifikat: kiriman.nomorSertifikat,
          );

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
          await _setujui(abaikanPeringatan: true, isian: kiriman);
        }

        return;
      }

      final kode = kodeDariBadan(e.body);

      // Server menolak nomor (Order Number / No. Sertifikat kosong, tidak
      // valid, atau sudah dipakai): dialog dibuka lagi dengan isian yang sama
      // dan pesan yang jelas di kotaknya. Status sesi tidak berubah.
      if (kodeIsianSetujui(kode)) {
        setState(() => _busy = false);
        final sert = e.body['sertifikat'];
        final pemilik = sert is Map ? sert['nomor'] : null;
        final pesan = pesanGalatPeran(
          l10n,
          kode,
          pemilikNomor: pemilik is String && pemilik.isNotEmpty
              ? pemilik
              : null,
        );
        final orderSalah = kode == KodeGalat.nomorOrderWajib;
        await _setujui(
          abaikanPeringatan: abaikanPeringatan,
          awal: kiriman,
          galatOrder: orderSalah ? pesan : null,
          galatSertifikat: orderSalah ? null : pesan,
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pesanGalatPeran(l10n, kode) ?? l10n.historyApproveFailed(e.message),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppButton(
      label: l10n.historyApprove,
      isLoading: _busy,
      onPressed: _busy ? null : _setujui,
    );
  }
}
