import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/kirim_email.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/kirim_email_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';

/// Nomor WA dinormalin ke bentuk internasional tanpa tanda baca — `wa.me`
/// cuma nerima digit. `08...` (cara nulis lokal) jadi `628...`.
///
/// Di tingkat library, bukan privat di dalam State: aturan normalisasinya
/// gampang salah dan pantas diuji sendiri, tanpa perlu merender layar.
String? normalkanNomorWa(String mentah) {
  var n = mentah.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n.startsWith('+')) n = n.substring(1);
  if (n.startsWith('0')) n = '62${n.substring(1)}';

  // Nomor Indonesia terpendek ~10 digit; di bawah itu pasti salah ketik.
  return n.length < 9 ? null : n;
}

/// Kirim sertifikat ke email pelanggan + riwayat percobaannya — **admin doang**.
class KirimEmailScreen extends ConsumerWidget {
  const KirimEmailScreen({
    super.key,
    required this.certificateId,
    required this.nomorSertifikat,
  });

  final int certificateId;
  final String nomorSertifikat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = ref.bolehkah(
      NamaIzin.sertifikatKirim,
      cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emailTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                nomorSertifikat,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: admin
          ? _Isi(certificateId: certificateId)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.emailHanyaAdmin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Isi extends ConsumerStatefulWidget {
  const _Isi({required this.certificateId});

  final int certificateId;

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  final _ke = TextEditingController();
  final _cc = TextEditingController();

  bool _mengirim = false;
  String? _errorKe;
  String? _errorCc;

  /// PDF duluan — dokumen resminya, dan itu yang dipakai sebelum pilihan ini ada.
  FormatKirim _format = FormatKirim.pdf;

  /// Saluran: email (default) atau WhatsApp.
  ///
  /// Dipisah dari [_format] karena dua pertanyaan yang beda: "lewat apa" dan
  /// "isinya apa". Digabung jadi satu daftar, WhatsApp kelihatan sejajar sama
  /// PDF/Excel — padahal lewat WA yang kekirim tetap salah satu dari ketiganya.
  bool _lewatWa = false;

  @override
  void dispose() {
    _ke.dispose();
    _cc.dispose();
    super.dispose();
  }

  /// "a@b.com, c@d.com" → daftar alamat, kosong dibuang.
  List<String> _pisah(String teks) => teks
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Divalidasi longgar — cukup mastiin ada `@` dan titik sesudahnya. Validasi
  /// email yang ketat sering nolak alamat yang sah, dan yang berwenang nolak
  /// beneran tetap server.
  static final _polaEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _periksa(List<String> alamat, {required bool wajib}) {
    final l10n = AppLocalizations.of(context);

    if (alamat.isEmpty) {
      return wajib ? l10n.emailKeKosong : null;
    }
    if (alamat.length > KirimEmailPermintaan.maksAlamat) {
      return l10n.emailKebanyakan(KirimEmailPermintaan.maksAlamat);
    }
    for (final a in alamat) {
      if (!_polaEmail.hasMatch(a)) return l10n.emailAlamatSalah(a);
    }
    return null;
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ke = _pisah(_ke.text);
    final cc = _pisah(_cc.text);

    setState(() {
      _errorKe = _periksa(ke, wajib: true);
      _errorCc = _periksa(cc, wajib: false);
    });
    if (_errorKe != null || _errorCc != null) return;

    setState(() => _mengirim = true);
    try {
      await kirimSertifikatLewatEmail(
        ref,
        certificateId: widget.certificateId,
        isi: KirimEmailPermintaan(ke: ke, cc: cc, format: _format),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.emailTerkirim)));
      _ke.clear();
      _cc.clear();
    } catch (e) {
      if (!mounted) return;
      // Pesan server apa adanya. Buat `502`, yang penting kebaca admin itu
      // "gagal TAPI tercatat" — bukan sekadar "gagal".
      final teks = e.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(
        SnackBar(content: Text(teks.isEmpty ? l10n.emailGagalMuat : teks)),
      );
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  /// Kirim lewat WhatsApp.
  ///
  /// Dua langkah, dan urutannya penting:
  ///
  /// 1. **Catat dulu ke server**, dapat teks pesannya. Pesannya disusun
  ///    backend — isinya tautan unduh yang nempel ke `qr_token` dan skema URL
  ///    yang cuma backend yang tahu.
  /// 2. **Baru buka WhatsApp.** Kalau kebalik, admin ngirim pesan lalu
  ///    pencatatannya gagal — dan riwayat bilang "belum pernah dikirim"
  ///    padahal pelanggan udah nerima.
  ///
  /// Yang ngirim tetap aplikasi WhatsApp di HP admin, bukan server. Jadi
  /// "terkirim" di sini artinya "WhatsApp-nya kebuka dengan pesan yang benar"
  /// — bukan jaminan pelanggan udah baca.
  /// Ganti saluran, sekalian setel format ke default saluran itu.
  ///
  /// Lewat WA yang kekirim SELALU tautan — WhatsApp nggak bisa dititipin
  /// lampiran tanpa Business API. Jadi kalau formatnya ketinggalan di `pdf`,
  /// admin mesti ganti ke `tautan` dulu tiap kali, dan kalau lupa, keterangan
  /// di layar nyebut "tautan unduh PDF" sementara yang dia pilih PDF —
  /// dua hal yang kelihatan bertentangan buat orang yang cuma mau ngirim.
  ///
  /// Email defaultnya `pdf`: bagian pengadaan pelanggan minta berkas buat
  /// diarsip, bukan tautan.
  ///
  /// Cuma dipasang waktu SALURANNYA ganti. Sesudah itu formatnya bebas
  /// diubah dan pilihan admin nggak ditimpa — ini default, bukan kunci.
  void _gantiSaluran(Set<bool> pilihan) {
    final wa = pilihan.first;
    setState(() {
      _lewatWa = wa;
      _format = wa ? FormatKirim.tautan : FormatKirim.pdf;
      // Kolom tujuan beda bentuk (nomor vs alamat), jadi error lama
      // nggak relevan lagi begitu salurannya ganti.
      _errorKe = null;
      _errorCc = null;
    });
  }

  Future<void> _kirimWa() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final mentah = _pisah(_ke.text);
    final nomor = mentah.map(normalkanNomorWa).nonNulls.toList();

    setState(() {
      _errorKe = mentah.isEmpty
          ? l10n.waKeKosong
          : (nomor.length != mentah.length ? l10n.waNomorSalah : null);
      _errorCc = null;
    });
    if (_errorKe != null) return;

    setState(() => _mengirim = true);
    try {
      final hasil = await catatKirimWhatsapp(
        ref,
        certificateId: widget.certificateId,
        ke: nomor,
        format: _format,
      );

      if (!mounted) return;

      // Satu nomor = satu jendela WhatsApp. Nomor pertama yang dibukain;
      // sisanya udah tercatat, admin tinggal terusin pesannya dari WhatsApp
      // — jauh lebih cepat daripada app ini buka-tutup WhatsApp berkali-kali.
      final url = Uri.parse(
        'https://wa.me/${nomor.first}?text=${Uri.encodeComponent(hasil.pesan)}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.waTakBisaDibuka)));
      }

      if (mounted) {
        _ke.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.waTercatat)));
      }
    } catch (e) {
      if (!mounted) return;
      final teks = e.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(
        SnackBar(content: Text(teks.isEmpty ? l10n.emailGagalMuat : teks)),
      );
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final riwayat = ref.watch(riwayatEmailProvider(widget.certificateId));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          controller: _ke,
          enabled: !_mengirim,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: _lewatWa ? l10n.waKeLabel : l10n.emailKeLabel,
            hintText: _lewatWa ? l10n.waKeHint : l10n.emailKeHint,
            errorText: _errorKe,
            border: const OutlineInputBorder(),
          ),
        ),
        if (!_lewatWa) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _cc,
            enabled: !_mengirim,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.emailCcLabel,
              errorText: _errorCc,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.emailPisahKoma(KirimEmailPermintaan.maksAlamat),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.kirimLewatJudul, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(l10n.kirimLewatEmail),
              icon: const Icon(Icons.mail_outline),
            ),
            ButtonSegment(
              value: true,
              label: Text(l10n.kirimLewatWa),
              icon: const Icon(Icons.chat_outlined),
            ),
          ],
          selected: {_lewatWa},
          onSelectionChanged: _mengirim ? null : _gantiSaluran,
        ),
        const SizedBox(height: AppSpacing.md),

        Text(l10n.emailFormatJudul, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        // Segmented, bukan dropdown: cuma tiga pilihan dan konsekuensinya beda
        // jauh — yang mana yang kepilih harus kelihatan tanpa dibuka dulu.
        SegmentedButton<FormatKirim>(
          segments: [
            ButtonSegment(
              value: FormatKirim.pdf,
              label: Text(l10n.emailFormatPdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            ButtonSegment(
              value: FormatKirim.xlsx,
              label: Text(l10n.emailFormatExcel),
              icon: const Icon(Icons.table_chart_outlined),
            ),
            ButtonSegment(
              value: FormatKirim.tautan,
              label: Text(l10n.emailFormatTautan),
              icon: const Icon(Icons.link),
            ),
          ],
          selected: {_format},
          onSelectionChanged: _mengirim
              ? null
              : (pilihan) => setState(() => _format = pilihan.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Konsekuensinya ditulis, bukan cuma namanya. "Tautan" kedengeran
        // ringan sampai admin sadar pelanggan nggak nerima berkas apa pun.
        Text(
          switch ((_lewatWa, _format)) {
            // Lewat WA yang dikirim selalu TAUTAN, apa pun formatnya —
            // WhatsApp nggak bisa dititipin lampiran tanpa Business API.
            // Yang beda cuma tautannya nunjuk ke apa.
            (true, FormatKirim.pdf) => l10n.waKetPdf,
            (true, FormatKirim.xlsx) => l10n.waKetExcel,
            (true, _) => l10n.waKetTautan,
            (false, FormatKirim.pdf) => l10n.emailFormatPdfKet,
            (false, FormatKirim.xlsx) => l10n.emailFormatExcelKet,
            (false, _) => l10n.emailFormatTautanKet,
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        AppButton(
          label: _lewatWa ? l10n.waKirim : l10n.emailKirim,
          icon: _lewatWa ? Icons.chat_outlined : Icons.send_outlined,
          isLoading: _mengirim,
          onPressed: _mengirim ? null : (_lewatWa ? _kirimWa : _kirim),
        ),

        // Kirimnya SINKRON — nunggu server email beneran nerima, bukan cuma
        // masuk antrean. Bisa makan waktu, jadi alasannya ditulis biar admin
        // nggak ngira app-nya nge-hang lalu mencet dua kali.
        if (_mengirim) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.emailMengirim,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(l10n.emailRiwayatJudul, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),

        switch (riwayat) {
          AsyncData(:final value) => value.isEmpty
              ? Text(
                  l10n.emailRiwayatKosong,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final p in value) _BarisRiwayat(percobaan: p),
                  ],
                ),
          AsyncError() => _GagalRiwayat(
            onCobaLagi: () => ref.invalidate(
              riwayatEmailProvider(widget.certificateId),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

/// Satu percobaan kirim. **Yang gagal ikut ditampilin** — itu justru yang
/// dicari waktu pelanggan ngaku nggak nerima sertifikatnya.
class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.percobaan});

  final PercobaanEmail percobaan;

  static String _labelFormat(AppLocalizations l10n, FormatKirim format) =>
      switch (format) {
        FormatKirim.pdf => l10n.emailFormatPdf,
        FormatKirim.xlsx => l10n.emailFormatExcel,
        FormatKirim.tautan => l10n.emailFormatTautan,
        FormatKirim.whatsapp => l10n.kirimLewatWa,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final waktu = DateFormat('d MMM yyyy · HH:mm', locale)
        .format(percobaan.waktu);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    percobaan.ke.join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: percobaan.berhasil
                      ? l10n.emailRiwayatBerhasil
                      : l10n.emailRiwayatGagal,
                  tone: percobaan.berhasil
                      ? BadgeTone.success
                      : BadgeTone.danger,
                  icon: percobaan.berhasil
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
              ],
            ),
            if (percobaan.cc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Cc: ${percobaan.cc.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            // Formatnya ikut, sebaris sama waktu & pengirim. Dua baris
            // "Terkirim" bisa berarti hal beda: yang satu pelanggan pegang
            // dokumennya, yang satu cuma dapat tautan.
            Text(
              percobaan.oleh == null
                  ? '$waktu · ${_labelFormat(l10n, percobaan.format)}'
                  : '$waktu · ${l10n.emailRiwayatOleh(percobaan.oleh!)}'
                        ' · ${_labelFormat(l10n, percobaan.format)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Alasan gagalnya ditampilin apa adanya — "mailbox penuh" beda
            // penanganan dari "alamat nggak ada", dan admin yang mutusin.
            if (!percobaan.berhasil && percobaan.error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                percobaan.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GagalRiwayat extends StatelessWidget {
  const _GagalRiwayat({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Text(l10n.emailGagalMuat, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.emailRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
