import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/auth_service.dart' show ApiException;
import 'kolom_berlabel.dart';
import 'pesan_galat_sa.dart';

/// Dialog satu isian + aksi ke server (alasan nonaktifkan/cabut, sandi baru).
///
/// Aksinya dijalankan DI DALAM dialog: bila server menolak, dialog tetap
/// terbuka dengan isian yang sudah diketik dan pesan di kolomnya — orang yang
/// baru menulis alasan 200 karakter tidak kehilangannya karena satu `422`.
/// Dialog menutup dengan `true` hanya bila aksinya sukses.
///
/// Dipakai untuk TIGA hal yang memutus atau memulihkan akses, jadi pola yang
/// sama: penjelasan akibat → isian → tombol yang menyebut aksinya (bukan
/// "OK") → penjaga ketukan ganda.
Future<bool> tampilkanDialogIsian(
  BuildContext context, {
  required String judul,
  required String isi,
  required String labelKolom,
  required String labelAksi,
  required Future<void> Function(String nilai) aksi,
  String? catatan,
  String? helper,
  bool wajib = true,
  bool sandi = false,
  bool potong = true,
  int panjangMinimal = 0,
  int panjangMaksimal = 500,
  String? pesanPendek,
  String? pesanPanjang,
  String kunciGalatServer = 'alasan',
  bool destruktif = false,
  bool untukAnggota = false,
  void Function(Object galat)? saatGalat,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    // Aksi yang memutus akses tidak boleh tertutup karena ketukan meleset
    // di luar kotak.
    barrierDismissible: false,
    builder: (_) => _DialogIsian(
      judul: judul,
      isi: isi,
      labelKolom: labelKolom,
      labelAksi: labelAksi,
      aksi: aksi,
      catatan: catatan,
      helper: helper,
      wajib: wajib,
      sandi: sandi,
      potong: potong,
      panjangMinimal: panjangMinimal,
      panjangMaksimal: panjangMaksimal,
      pesanPendek: pesanPendek,
      pesanPanjang: pesanPanjang,
      kunciGalatServer: kunciGalatServer,
      destruktif: destruktif,
      untukAnggota: untukAnggota,
      saatGalat: saatGalat,
    ),
  );
  return hasil ?? false;
}

class _DialogIsian extends StatefulWidget {
  const _DialogIsian({
    required this.judul,
    required this.isi,
    required this.labelKolom,
    required this.labelAksi,
    required this.aksi,
    required this.catatan,
    required this.helper,
    required this.wajib,
    required this.sandi,
    required this.potong,
    required this.panjangMinimal,
    required this.panjangMaksimal,
    required this.pesanPendek,
    required this.pesanPanjang,
    required this.kunciGalatServer,
    required this.destruktif,
    required this.untukAnggota,
    required this.saatGalat,
  });

  final String judul;
  final String isi;
  final String labelKolom;
  final String labelAksi;
  final Future<void> Function(String nilai) aksi;
  final String? catatan;
  final String? helper;
  final bool wajib;
  final bool sandi;
  final bool potong;
  final int panjangMinimal;
  final int panjangMaksimal;
  final String? pesanPendek;
  final String? pesanPanjang;
  final String kunciGalatServer;
  final bool destruktif;
  final bool untukAnggota;
  final void Function(Object galat)? saatGalat;

  @override
  State<_DialogIsian> createState() => _DialogIsianState();
}

class _DialogIsianState extends State<_DialogIsian> {
  final _kontrol = TextEditingController();
  String? _galatKolom;
  String? _galatUmum;
  bool _mengirim = false;

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  String get _nilai => widget.potong ? _kontrol.text.trim() : _kontrol.text;

  /// Penjaga di PINTU fungsi, bukan hanya `onPressed: null`: dua ketukan
  /// beruntun bisa tiba sebelum frame yang menonaktifkan tombol tergambar.
  Future<void> _jalankan() async {
    if (_mengirim) return;

    final nilai = _nilai;
    final kosong = nilai.isEmpty;
    String? salah;
    if (kosong && widget.wajib) {
      salah = widget.pesanPendek;
    } else if (!kosong && nilai.length < widget.panjangMinimal) {
      salah = widget.pesanPendek;
    } else if (nilai.length > widget.panjangMaksimal) {
      salah = widget.pesanPanjang;
    }
    if (salah != null) {
      setState(() {
        _galatKolom = salah;
        _galatUmum = null;
      });
      return;
    }

    setState(() {
      _mengirim = true;
      _galatKolom = null;
      _galatUmum = null;
    });

    try {
      await widget.aksi(nilai);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      widget.saatGalat?.call(e);
      final l10n = AppLocalizations.of(context);
      final dikolom = e is ApiException && e.status == 422
          ? pesanKolomServer(e, widget.kunciGalatServer)
          : null;
      setState(() {
        _mengirim = false;
        _galatKolom = dikolom;
        _galatUmum = dikolom == null
            ? pesanGalatSa(l10n, e, untukAnggota: widget.untukAnggota)
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final warnaAksi = widget.destruktif ? tema.colorScheme.error : null;

    return AlertDialog(
      title: Text(widget.judul, maxLines: 4, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isi, style: tema.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              if (widget.sandi)
                KolomBerlabel(
                  label: widget.labelKolom,
                  controller: _kontrol,
                  isPassword: true,
                  enabled: !_mengirim,
                  errorText: _galatKolom,
                  helperText: widget.helper,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _jalankan(),
                )
              else
                Semantics(
                  label: widget.labelKolom,
                  child: TextField(
                    key: const Key('isian-dialog'),
                    controller: _kontrol,
                    enabled: !_mengirim,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    inputFormatters: [
                      // Batas keras supaya tempelan panjang tidak lolos; pesan
                      // "terlalu panjang" tetap ada untuk jalur validasi.
                      LengthLimitingTextInputFormatter(
                        widget.panjangMaksimal + 50,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: widget.labelKolom,
                      errorText: _galatKolom,
                      helperText: widget.helper,
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              if (widget.catatan != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.catatan!,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_galatUmum != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _galatUmum!,
                    key: const Key('galat-dialog'),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _mengirim ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.saBatal),
        ),
        TextButton(
          key: const Key('aksi-dialog'),
          onPressed: _mengirim ? null : _jalankan,
          style: warnaAksi == null
              ? null
              : TextButton.styleFrom(foregroundColor: warnaAksi),
          child: _mengirim
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.labelAksi),
        ),
      ],
    );
  }
}
