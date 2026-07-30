import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/certificate_provider.dart';
import '../../widgets/certificate_qr.dart';
import '../history/kirim_email_screen.dart';

/// Yang muncul begitu sertifikat terbit: nomornya, plus semua cara ngeluarin
/// dan ngebagiin dari satu tempat.
///
/// **Kenapa satu lembar, bukan disebar ke beberapa layar:** begitu sertifikat
/// jadi, yang dikerjain admin selalu itu-itu juga — unduh, kirim ke pelanggan,
/// atau kasih tautan verifikasi. Kalau tiap aksinya mesti dicari sendiri di
/// menu yang beda, pekerjaan yang sebenarnya satu tarikan napas jadi kelihatan
/// kayak enam pekerjaan.
/// [nomor] boleh null: sesudah approve, yang balik dari backend cuma
/// `certificate_id` — nomornya belum ikut. Kalau kosong, sheet-nya narik
/// sendiri dari detail sertifikat daripada maksa pemanggil nunggu.
Future<void> tampilkanSertifikatSukses(
  BuildContext context, {
  required int certificateId,
  String? nomor,
  String? qrToken,
  String? verifikasiUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SheetSukses(
      certificateId: certificateId,
      nomor: nomor,
      qrToken: qrToken,
      verifikasiUrl: verifikasiUrl,
    ),
  );
}

class _SheetSukses extends ConsumerWidget {
  const _SheetSukses({
    required this.certificateId,
    required this.nomor,
    this.qrToken,
    this.verifikasiUrl,
  });

  final int certificateId;
  final String? nomor;
  final String? qrToken;
  final String? verifikasiUrl;

  /// Tautan yang dibagiin ke pelanggan.
  ///
  /// Diutamain yang dikirim backend. Kalau cuma ada token, disusun dari alamat
  /// API — tapi itu **cadangan**, bukan yang benar: domain verifikasi milik
  /// backend, dan mobile nggak boleh ikut salah kalau domainnya ganti.
  String? get _tautan {
    final u = verifikasiUrl?.trim();
    if (u != null && u.isNotEmpty) return u;

    final t = qrToken?.trim();
    if (t == null || t.isEmpty) return null;

    return '${AppConfig.apiBaseUrl}/verify/$t';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final layanan = ref.read(certificateServiceProvider);

    // Yang manggil sheet ini seringnya cuma pegang id. Layar approval malah
    // cuma dapat `certificate_id` — `approve` nggak ngirim balik nomor MAUPUN
    // `qr_token`. Jadi detailnya ditarik di sini daripada maksa tiap pemanggil
    // ikut ngurusin: tanpa ini nomornya kosong dan tombol Salin Tautan &
    // WhatsApp mati, padahal sertifikatnya jelas-jelas udah terbit.
    final butuhDetail =
        nomor == null || (qrToken == null && verifikasiUrl == null);
    final detail = butuhDetail
        ? ref.watch(certificateDetailProvider(certificateId)).value
        : null;

    final nomorTampil = nomor ?? detail?.nomor;
    final tautan =
        _tautan ??
        (detail?.qrToken == null
            ? null
            : '${AppConfig.apiBaseUrl}/verify/${detail!.qrToken}');
    final token = qrToken ?? detail?.qrToken;

    return AlertDialog(
      icon: Icon(
        Icons.workspace_premium_rounded,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      title: Text(l10n.certSuksesJudul, textAlign: TextAlign.center),
      // Digulir, bukan dipas-pasin: enam aksi + nomor itu tinggi tetap, dan di
      // jendela pendek (atau HP dengan teks diperbesar) dialog-nya pasti lewat
      // batas layar. Tanpa ini yang kejadian bukan cuma jelek — baris paling
      // bawah, "Bagikan lewat WhatsApp", kepotong dan nggak bisa dipencet.
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.certSuksesNomor.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                // Titik-titik selama detailnya jalan, bukan '—': strip kebaca
                // sebagai "sertifikat ini nggak punya nomor", padahal cuma belum
                // nyampe.
                nomorTampil ?? '…',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),

              _Aksi(
                ikon: Icons.picture_as_pdf_outlined,
                label: l10n.certAksiPdf,
                onTap: () =>
                    _buka(context, layanan.urlPdf(certificateId), 'PDF'),
              ),
              _Aksi(
                ikon: Icons.table_chart_outlined,
                label: l10n.certAksiExcel,
                onTap: () =>
                    _buka(context, layanan.urlExcel(certificateId), 'Excel'),
              ),
              _Aksi(
                ikon: Icons.qr_code_2,
                label: l10n.certAksiQr,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ModalQr(
                    nomor: nomorTampil ?? '$certificateId',
                    token: token,
                    url: tautan,
                  ),
                ),
              ),
              _Aksi(
                ikon: Icons.link,
                label: l10n.certAksiSalinTautan,
                // Dimatiin, bukan disembunyiin: kalau tombolnya raib orang ngira
                // app-nya rusak. Yang perlu dia tahu itu backend-nya yang belum
                // nerbitin token — dan itu dibilangin lewat tooltip.
                aktif: tautan != null,
                tooltipMati: l10n.certBelumAdaTautan,
                onTap: () => _salin(context, tautan!),
              ),
              _Aksi(
                ikon: Icons.mail_outline,
                label: l10n.certAksiEmail,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => KirimEmailScreen(
                        certificateId: certificateId,
                        nomorSertifikat: nomorTampil ?? '—',
                      ),
                    ),
                  );
                },
              ),
              _Aksi(
                ikon: Icons.chat_outlined,
                label: l10n.certAksiWhatsapp,
                aktif: tautan != null,
                tooltipMati: l10n.certBelumAdaTautan,
                onTap: () =>
                    _bukaWhatsapp(context, l10n, nomorTampil ?? '—', tautan!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.certAksiTutup),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- aksi

Future<void> _buka(BuildContext context, String url, String tujuan) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);

  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.certGagalBuka(tujuan))));
  }
}

Future<void> _salin(BuildContext context, String tautan) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  await Clipboard.setData(ClipboardData(text: tautan));
  messenger.showSnackBar(SnackBar(content: Text(l10n.certTautanDisalin)));
}

/// Buka WhatsApp dengan pesannya udah keisi.
///
/// Pakai `wa.me` (bukan skema `whatsapp://`) supaya di desktop yang nggak punya
/// WhatsApp tetap mendarat ke WhatsApp Web, bukan mentok.
Future<void> _bukaWhatsapp(
  BuildContext context,
  AppLocalizations l10n,
  String nomor,
  String tautan,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final pesan = l10n.certPesanBagikan(nomor, tautan);
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(pesan)}');

  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);

  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.certGagalBuka('WhatsApp'))),
    );
  }
}

class _Aksi extends StatelessWidget {
  const _Aksi({
    required this.ikon,
    required this.label,
    required this.onTap,
    this.aktif = true,
    this.tooltipMati,
  });

  final IconData ikon;
  final String label;
  final VoidCallback onTap;
  final bool aktif;
  final String? tooltipMati;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baris = ListTile(
      enabled: aktif,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ikon,
        size: 20,
        color: aktif ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: aktif ? onTap : null,
    );

    if (aktif || tooltipMati == null) return baris;
    return Tooltip(message: tooltipMati!, child: baris);
  }
}

// ---------------------------------------------------------------- modal QR

class _ModalQr extends StatefulWidget {
  const _ModalQr({required this.nomor, this.token, this.url});

  final String nomor;
  final String? token;
  final String? url;

  @override
  State<_ModalQr> createState() => _ModalQrState();
}

class _ModalQrState extends State<_ModalQr> {
  /// Dipakai buat nyalin QR yang KELIHATAN jadi PNG. Digambar ulang dari data
  /// bakal gampang meleset dari yang dilihat orang di layar.
  final _kunciQr = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tautan = widget.url;

    return AlertDialog(
      title: Text(l10n.certQrModalJudul),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: _kunciQr,
              child: ColoredBox(
                // Putih dipaksa, nggak ikut tema: QR gelap-di-atas-terang itu
                // yang kebaca pemindai. Di tema gelap, QR putih-di-atas-hitam
                // sering gagal discan.
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CertificateQr(token: widget.token, url: tautan),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.certQrScanUntukVerifikasi,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (tautan != null) ...[
              const SizedBox(height: AppSpacing.xs),
              SelectableText(tautan, style: theme.textTheme.labelSmall),
            ],
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            _Aksi(
              ikon: Icons.download_outlined,
              label: l10n.certQrSimpanPng,
              onTap: _simpanPng,
            ),
            _Aksi(
              ikon: Icons.link,
              label: l10n.certAksiSalinTautan,
              aktif: tautan != null,
              tooltipMati: l10n.certBelumAdaTautan,
              onTap: () => _salin(context, tautan!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.certAksiTutup),
        ),
      ],
    );
  }

  Future<void> _simpanPng() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final batas =
        _kunciQr.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (batas == null) return;

    // 3x biar QR-nya tetap tajam waktu dicetak atau diperbesar penerima.
    final gambar = await batas.toImage(pixelRatio: 3);
    final byte = await gambar.toByteData(format: ui.ImageByteFormat.png);
    if (byte == null) return;

    final folder = await getApplicationDocumentsDirectory();
    final berkas = File('${folder.path}/QR-${widget.nomor}.png');
    await berkas.writeAsBytes(byte.buffer.asUint8List());

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.certPngDisimpan(berkas.path))),
    );
  }
}
