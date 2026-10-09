import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/worksheet_template.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sumber_foto_provider.dart';
import '../../../providers/worksheet_scan_provider.dart';
import '../../../services/jalankan_pindai.dart' show GagalPindai;
import '../../../services/jalankan_pindai_asli.dart';
import '../../../services/worksheet_scan_service.dart' show PindaiDitolak;
import '../lembar_kerja_state.dart';
import '../pindai_review_screen.dart';

/// Tombol "Pindai formulir kertas" — satu foto formulir SIDIK-FM-CAL ASLI lab
/// (tanpa marker, tanpa QR) mengisi lembar kerja ini.
///
/// ## Kapan tampil
///
/// HANYA kalau server punya geometri formulir asli alat ini
/// (`?kertas=asli` 200) DAN formulirnya `siap_pindai` atau mode uji server
/// nyala. Selain itu tidak digambar sama sekali — bukan tombol mati: hampir
/// semua alat belum punya formulir asli terpetakan, dan tombol mati di 40
/// lembar cuma mengajari teknisi bahwa tombol itu tidak berarti apa-apa.
///
/// Ini BUKAN tombol "PINDAI LEMBAR KERJA" yang dicabut 26 Agt 2026: yang itu
/// cuma bisa membaca kertas bermarker buatan sistem. Yang ini membaca formulir
/// yang memang dipegang teknisi (PANDUAN-OCR-LEMBAR-KERJA.md §3).
///
/// ## Tidak ada yang otomatis tersimpan
///
/// Foto → [JalankanPindaiAsli] → `POST /worksheet-scans` → layar review. Yang
/// masuk lembar kerja cuma yang teknisi konfirmasi di layar review, lewat
/// [LembarKerjaState.terapkanKonfirmasiPindai] — yang juga tidak menimpa
/// kolom yang sudah berisi.
class TombolPindaiFormulirAsli extends ConsumerStatefulWidget {
  const TombolPindaiFormulirAsli({
    super.key,
    required this.profil,
    required this.isian,
    required this.onBerubah,
    this.equipmentId,
    this.sesiId,
  });

  /// Kode ALAT (`ph_meter`), bukan nomor formulir.
  final String profil;
  final int? equipmentId;
  final int? sesiId;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  ConsumerState<TombolPindaiFormulirAsli> createState() =>
      _TombolPindaiFormulirAsliState();
}

class _TombolPindaiFormulirAsliState
    extends ConsumerState<TombolPindaiFormulirAsli> {
  bool _sibuk = false;

  /// Label kolom lembar kerja dari BENTUK lembarnya — layar review tidak
  /// mengenal satu pun nama kolom.
  String? _labelKode(String kode) {
    for (final b in widget.isian.bentuk.bagian) {
      for (final f in [...b.field, ...b.fieldDiLuarKertas]) {
        if (f.kode == kode) return f.label;
      }
    }

    return null;
  }

  Future<void> _pindai(WorksheetTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sibuk = true);

    try {
      // Resolusi dipertahankan — alasannya sama dengan `ambilDanBacaTabel`.
      final foto = await ref
          .read(sumberFotoProvider)
          .ambil(maxWidth: 4200, imageQuality: 100);

      if (foto == null || !mounted) return;

      final bita = await foto.readAsBytes();

      // Berkas dari pemilih foto = lembar kerja pelanggan di cache. Bitanya
      // sudah di memori; berkasnya dibuang sekarang, bukan menumpuk.
      try {
        await foto.delete();
      } catch (_) {
        // Gagal hapus bukan alasan membatalkan pembacaan.
      }

      final citra = img.decodeImage(bita);

      if (citra == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkPindaiGagalFoto)));
        return;
      }

      final pabrik = ref.read(pabrikPembacaPindaiProvider);
      final halaman = pabrik.halaman();
      final pembaca = pabrik.sel();

      final HasilSusunPindaiAsli susunan;
      try {
        susunan = await JalankanPindaiAsli(halaman: halaman, pembaca: pembaca)
            .susun(
              citra,
              template: template,
              calibrationSessionId: widget.sesiId,
              equipmentId: widget.equipmentId,
            );
      } finally {
        await halaman.tutup();
        await pembaca.tutup();
      }

      final token = await ref.read(tokenStorageProvider).read();
      if (token == null || !mounted) return;

      final hasil = await ref
          .read(worksheetScanServiceProvider)
          .kirim(token, susunan.body, citraWarp: jpgDari(susunan.citraWarp));

      if (!mounted) return;

      final konfirmasi = await PindaiReviewScreen.bukaFormulirAsli(
        navigator,
        hasil,
        labelKode: _labelKode,
      );

      // Mundur tanpa konfirmasi = tidak ada satu nilai pun yang dipakai.
      if (konfirmasi == null || !mounted) return;

      final hasilTerap = widget.isian.terapkanKonfirmasiPindai(konfirmasi);
      widget.onBerubah();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            l10n.lkPindaiAsliTerpakai(hasilTerap.terisi, hasilTerap.dilewati),
          ),
        ),
      );
    } on PindaiAsliGagal catch (e) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(pesanPindaiAsliGagal(l10n, e, template)),
        ),
      );
    } on PindaiDitolak catch (e) {
      // Kalimat server ditampilkan apa adanya — sudah ditulis buat teknisi.
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            e.bugAplikasi ? l10n.lkPindaiBugAplikasi(e.pesan) : e.pesan,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkPindaiGagalFoto)));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Saklar kamera yang sama dengan `FOTO TABEL INI` — dimatikan lewat
    // `--dart-define=PINDAI_LEMBAR=false`, tombol ini ikut hilang.
    if (!ref.watch(pindaiLembarAktifProvider)) return const SizedBox.shrink();

    final template = ref
        .watch(
          worksheetTemplateAsliProvider((
            kode: widget.profil,
            equipmentId: widget.equipmentId,
          )),
        )
        .value;

    if (template == null || !template.bolehDipindaiAsli) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sibuk ? null : () => _pindai(template),
              icon: _sibuk
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined, size: 18),
              label: Text(l10n.lkPindaiFormulirAsli),
            ),
          ),
          // Mode uji membatasi vonis ke kuning walau `siap_pindai` sudah
          // nyala (server, B2 keputusan 7) — catatannya ikut selama sakelarnya
          // nyala.
          if (template.modeUji) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.lkPindaiFormulirAsliModeUji,
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

/// Sebab berhenti → kalimat buat teknisi. Tiap sebab punya tindakan yang beda:
/// foto ulang menolong untuk jangkar & mutu, TIDAK menolong untuk formulir
/// lain, revisi beda, atau geometri yang belum lengkap.
String pesanPindaiAsliGagal(
  AppLocalizations l10n,
  PindaiAsliGagal e,
  WorksheetTemplate template,
) => switch (e.sebab) {
  GagalPindaiAsli.belumSiap => l10n.lkPindaiAsliBelumSiap,
  GagalPindaiAsli.geometriBelumLengkap => l10n.lkPindaiAsliGeometriKurang(
    e.jumlah ?? 0,
  ),
  GagalPindaiAsli.kodeTidakTerbaca => l10n.lkPindaiAsliKodeTidakTerbaca(
    template.kodeDokumen,
  ),
  GagalPindaiAsli.formulirLain => l10n.lkPindaiAsliFormulirLain(
    e.terbaca ?? '—',
    template.kodeDokumen,
  ),
  GagalPindaiAsli.revisiBeda => l10n.lkPindaiAsliRevisiBeda(
    e.terbaca ?? '—',
    template.revisi ?? '—',
  ),
  GagalPindaiAsli.jangkarKurang => l10n.lkPindaiAsliJangkarKurang(
    e.jumlah ?? 0,
  ),
  GagalPindaiAsli.jangkarTidakMenyebar => l10n.lkPindaiAsliJangkarTidakMenyebar,
  GagalPindaiAsli.mutu => switch (e.mutu) {
    GagalPindai.mutuBuram => l10n.lkPindaiBuram,
    GagalPindai.mutuGelap => l10n.lkPindaiGelap,
    GagalPindai.mutuSilau => l10n.lkPindaiSilau,
    GagalPindai.mutuPantulan => l10n.lkPindaiPantulan,
    GagalPindai.mutuKejauhan => l10n.lkPindaiKejauhan,
    _ => l10n.lkPindaiTerlaluMiring,
  },
};
