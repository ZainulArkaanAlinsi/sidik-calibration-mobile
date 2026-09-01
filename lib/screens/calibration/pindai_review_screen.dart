import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/worksheet_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worksheet_scan_provider.dart';
import '../../widgets/app_button.dart';

/// Layar review hasil pindai lembar kerja.
///
/// **Hasil pindai itu USULAN, bukan data.** Yang lahir dari layar ini cuma
/// angka yang teknisi setujui; nyimpen hasil kalibrasi tetap lewat
/// `POST`/`PUT /api/calibrations` seperti biasa.
///
/// Tiga aturan yang nggak boleh dilanggar, dan ketiganya ada alasannya di
/// lapangan:
///
///  1. **Hampir semua sel bakal KUNING, dan itu bener.** Tulisan tangan nggak
///     pernah dinaikin ke hijau — model OCR tetap percaya diri waktu salah baca
///     coretan tangan. Jadi nggak ada tombol "terima semua" yang ngelewatin
///     pemeriksaan.
///  2. **Sel kuning & merah harus bisa diadu sama potongan citranya di layar
///     yang sama.** Kalau teknisi mesti buka kertasnya lagi, dia bakal milih
///     ngetik dari awal — dan fitur ini jadi nggak ada gunanya.
///  3. **Yang dikirim balik SEMUA sel**, termasuk yang bacanya udah bener.
///     Ini satu-satunya sumber data akurasi sistem: sel yang dilewat berarti
///     nggak ada bukti bacanya bener, dan sel hijau yang salah nggak akan
///     pernah ketahuan.
class PindaiReviewScreen extends ConsumerStatefulWidget {
  const PindaiReviewScreen({super.key, required this.hasil});

  final HasilPindai hasil;

  @override
  ConsumerState<PindaiReviewScreen> createState() => _PindaiReviewScreenState();
}

class _PindaiReviewScreenState extends ConsumerState<PindaiReviewScreen> {
  /// Nilai final per kunci sel. Diisi dari hasil baca server, lalu ditimpa
  /// teknisi lewat kotak isian.
  ///
  /// Sel MERAH sengaja mulai KOSONG walau server sempat baca angkanya: vonis
  /// merah artinya bacaannya nggak bisa dipercaya, dan nampilin angkanya
  /// duluan bikin teknisi cuma nyetujuin apa yang udah ada.
  late final Map<String, TextEditingController> _isian = {
    for (final s in widget.hasil.semuaSel)
      s.kunci: TextEditingController(
        text: switch (s.vonis) {
          VonisSel.merah || VonisSel.kosong => '',
          _ => s.nilai == null ? '' : _teks(s.nilai!),
        },
      ),
  };

  bool _mengirim = false;

  /// `4.01` bukan `4.0100000001` — ditulis apa adanya, tanpa dibulatkan ke
  /// desimal alat: yang mutusin bentuk akhirnya server waktu sesinya dihitung.
  static String _teks(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : '$n';

  @override
  void dispose() {
    for (final c in _isian.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _mengirim = true);

    // SEMUA sel dikirim, bukan cuma yang diubah — lihat docblock kelas.
    final koreksi = [
      for (final s in widget.hasil.semuaSel)
        KoreksiSel(kunci: s.kunci, nilaiFinal: _angka(_isian[s.kunci]?.text)),
    ];

    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token != null) {
        await ref
            .read(worksheetScanServiceProvider)
            .kirimKoreksi(token, widget.hasil.scanId, koreksi);
      }
    } catch (e) {
      // Gagal nyetor koreksi NGGAK boleh nahan angkanya masuk formulir: itu
      // catatan akurasi buat sistem, sementara yang ditunggu teknisi hasil
      // kerjanya sendiri. Dikabarin, terus jalan terus.
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.pindaiKoreksiGagal('$e'))),
        );
      }
    }

    if (!mounted) return;
    setState(() => _mengirim = false);

    // Yang dibalikin ke layar lembar kerja bukan peta berkunci sel, tapi
    // alamat kotaknya: identitas tabel + titik ukur + Repeat + kolom. Kunci sel
    // itu bahasa server, dan nerjemahinnya di layar tujuan berarti mecah string
    // lalu nebak `baris_ke` itu titik yang mana.
    //
    // `tabelId` ikut, bukan `tahap` doang: di lembar berpasangan empat tabel
    // bisa sama-sama `sesudah_adjustment`, dan tahap sendirian nggak cukup
    // buat nunjuk yang mana. Lihat [SelDipakaiPindai].
    navigator.pop(<SelDipakaiPindai>[
      for (final t in widget.hasil.tabel)
        for (final b in t.baris)
          for (final s in b.sel)
            if (_angka(_isian[s.kunci]?.text) case final double n)
              (
                tabelId: t.tabelId,
                tahap: t.tahap,
                titikUkur: b.titikUkur,
                repeatNo: s.repeatNo,
                fieldId: s.fieldId,
                nilai: n,
                // Vonis hijau doang yang lewat tanpa tanda. Selebihnya
                // ditandai di formulir — teknisi udah lihat sekali di sini,
                // dan tanda itu yang bikin dia lihat sekali lagi sebelum
                // lembarnya dikirim.
                perluDicek: s.vonis != VonisSel.hijau,
              ),
    ]);
  }

  /// Teks kotak isian → angka. Koma diterima: formulir kertasnya pakai koma,
  /// dan teknisi ngetik ngikut kertas.
  static double? _angka(String? teks) =>
      teks == null ? null : double.tryParse(teks.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = widget.hasil.ringkasan;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pindaiReviewJudul)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Ringkasan vonis + kalimat kenapa kuningnya banyak. Tanpa kalimat
          // itu, teknisi ngira sistemnya rusak — padahal "hampir semua kuning"
          // memang keluaran yang benar buat tulisan tangan.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pindaiRingkasan(r.totalSel, r.kuning, r.merah, r.kosong),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.pindaiCatatanKuning,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          for (final t in widget.hasil.tabel) ...[
            Text(
              t.judul,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final b in t.baris) ...[
              Text(
                b.satuan == null ? b.label : '${b.label} ${b.satuan}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final s in b.sel)
                _SelReview(
                  sel: s,
                  scanId: widget.hasil.scanId,
                  controller: _isian[s.kunci]!,
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],

          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.pindaiPakaiAngka,
            isLoading: _mengirim,
            // `boleh_auto_isi` DIPAKAI APA ADANYA dari server — nggak dihitung
            // ulang dari jumlah sel merah di sini. Aturannya mesti sama di
            // semua versi APK, dan yang megang aturannya server.
            onPressed: _mengirim || !widget.hasil.bolehAutoIsi ? null : _simpan,
          ),
          if (!widget.hasil.bolehAutoIsi) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.pindaiDitahanServer,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu sel: kotak isian + vonisnya + potongan citra aslinya.
class _SelReview extends ConsumerStatefulWidget {
  const _SelReview({
    required this.sel,
    required this.scanId,
    required this.controller,
  });

  final SelPindai sel;
  final int scanId;
  final TextEditingController controller;

  @override
  ConsumerState<_SelReview> createState() => _SelReviewState();
}

class _SelReviewState extends ConsumerState<_SelReview> {
  Uint8List? _crop;
  bool _memuat = false;

  /// Potongan citra dimuat buat sel KUNING & MERAH, dan cuma sekali.
  ///
  /// Byte-nya dipegang di memori selama layar hidup — **nggak ditulis ke
  /// penyimpanan bersama, galeri, atau folder yang ikut ter-backup ke cloud**.
  /// Isinya lembar kerja pelanggan.
  Future<void> _muatCrop() async {
    if (_crop != null || _memuat) return;
    setState(() => _memuat = true);

    try {
      final token = await ref.read(tokenStorageProvider).read();
      final bytes = token == null
          ? null
          : await ref
                .read(worksheetScanServiceProvider)
                .cropSel(token, widget.scanId, widget.sel.kunci);
      if (mounted) setState(() => _crop = bytes);
    } catch (_) {
      // Citra audit boleh gagal naik dari HP, jadi wajar juga nggak ada di
      // server. Nggak ada yang perlu diteriakin — kotak isiannya tetap jalan.
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.sel.vonis == VonisSel.kuning ||
        widget.sel.vonis == VonisSel.merah) {
      _muatCrop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final s = widget.sel;

    final warna = switch (s.vonis) {
      VonisSel.hijau => AppColors.statusSukses(context),
      VonisSel.kuning => AppColors.statusPeringatan(context),
      VonisSel.merah => AppColors.statusBahaya(context),
      VonisSel.kosong => theme.colorScheme.outline,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pita warna vonis. Warnanya BUKAN satu-satunya penanda — nomor
          // Repeat & alasannya ikut tertulis, karena status yang cuma dibedain
          // warna nggak kebaca sama yang buta warna.
          Container(width: 4, height: 44, color: warna),
          const SizedBox(width: AppSpacing.sm),

          // Potongan citra aslinya, di sebelah kotak isian — ini yang bikin
          // layar ini layak dipakai.
          if (_crop != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Image.memory(
                _crop!,
                width: 72,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: widget.controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.pindaiRepeat(s.repeatNo),
                    border: const OutlineInputBorder(),
                    // Teks mentah hasil baca ditampilin apa adanya di bawah
                    // kotak, termasuk yang ngawur — teknisi berhak lihat yang
                    // mesin baca, bukan cuma hasil bersihnya.
                    helperText: s.teksMentah == null || s.teksMentah!.isEmpty
                        ? null
                        : l10n.pindaiTerbaca(s.teksMentah!),
                  ),
                ),
                for (final a in s.alasan)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${_kalimatAlasan(l10n, a)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: warna),
                    ),
                  ),
                // Catatan perubahan yang dilakukan server (`O→0`, pemisah
                // ribuan dibuang, …). Teknisi berhak tahu angka yang dia lihat
                // udah ditebak-tebak sampai mana.
                if (s.normalisasi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.pindaiNormalisasi(s.normalisasi.join(', ')),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kode alasan dari server → kalimat buat teknisi.
///
/// Kode mentahnya nggak pernah ditampilin: teknisi lagi berdiri di depan alat
/// pelanggan, dan `bukan_kelipatan_resolusi` bukan kalimat yang bisa dia
/// tindaklanjuti. Kode yang belum dikenal dilewat apa adanya — itu lebih baik
/// daripada nyembunyiin alasan yang backend-nya baru nambahin.
String _kalimatAlasan(AppLocalizations l10n, String kode) => switch (kode) {
  'teks_meluber_dari_sel' => l10n.pindaiAlasanMeluber,
  'di_luar_rentang' => l10n.pindaiAlasanLuarRentang,
  'magnitudo_meleset' => l10n.pindaiAlasanMagnitudo,
  'ada_koreksi_karakter' => l10n.pindaiAlasanKoreksiKarakter,
  'desimal_kebanyakan' => l10n.pindaiAlasanDesimalBanyak,
  'bukan_kelipatan_resolusi' => l10n.pindaiAlasanBukanKelipatan,
  'jauh_dari_repeat_lain' => l10n.pindaiAlasanJauhDariRepeat,
  'sebar_repeat_tidak_diuji' => l10n.pindaiAlasanSebarTakDiuji,
  'terlalu_banyak_substitusi' => l10n.pindaiAlasanBanyakSubstitusi,
  'karakter_di_luar_whitelist' => l10n.pindaiAlasanKarakterAsing,
  'bentuk_angka_tidak_wajar' => l10n.pindaiAlasanBentukTakWajar,
  'digit_kebanyakan' => l10n.pindaiAlasanDigitBanyak,
  'pemisah_desimal_tidak_wajar' => l10n.pindaiAlasanPemisahTakWajar,
  'desimal_ambigu' => l10n.pindaiAlasanDesimalAmbigu,
  'minus_di_tengah' => l10n.pindaiAlasanMinusTengah,
  'minus_tidak_diizinkan' => l10n.pindaiAlasanMinusTakBoleh,
  _ => kode,
};
