import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'pesan_galat_crud.dart';

/// Dialog konfirmasi TEGAS untuk aksi yang menghapus atau memutus sesuatu
/// (hapus order, hapus kategori).
///
/// Aksinya dijalankan DI DALAM dialog: bila server menolak, dialog tetap
/// terbuka dan menampilkan kalimat galatnya — orang tidak kehilangan konteks
/// karena satu `422`. Dialog menutup dengan `true` hanya bila aksinya sukses.
/// Tidak bisa ditutup dengan mengetuk di luar kotak, dan penjaga ketukan ganda
/// ada di pintu fungsi (dua ketukan beruntun bisa tiba sebelum tombol tergambar
/// nonaktif).
Future<bool> tampilkanDialogKonfirmasiCrud(
  BuildContext context, {
  required String judul,
  required String isi,
  required String labelAksi,
  required Future<void> Function() aksi,
  bool destruktif = true,
  String? ditolak422,
  void Function(Object galat)? saatGalat,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogKonfirmasi(
      judul: judul,
      isi: isi,
      labelAksi: labelAksi,
      aksi: aksi,
      destruktif: destruktif,
      ditolak422: ditolak422,
      saatGalat: saatGalat,
    ),
  );
  return hasil ?? false;
}

class _DialogKonfirmasi extends StatefulWidget {
  const _DialogKonfirmasi({
    required this.judul,
    required this.isi,
    required this.labelAksi,
    required this.aksi,
    required this.destruktif,
    required this.ditolak422,
    required this.saatGalat,
  });

  final String judul;
  final String isi;
  final String labelAksi;
  final Future<void> Function() aksi;
  final bool destruktif;
  final String? ditolak422;
  final void Function(Object galat)? saatGalat;

  @override
  State<_DialogKonfirmasi> createState() => _DialogKonfirmasiState();
}

class _DialogKonfirmasiState extends State<_DialogKonfirmasi> {
  String? _galat;
  bool _mengirim = false;

  Future<void> _jalankan() async {
    if (_mengirim) return;
    setState(() {
      _mengirim = true;
      _galat = null;
    });
    try {
      await widget.aksi();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      widget.saatGalat?.call(e);
      setState(() {
        _mengirim = false;
        _galat = pesanGalatCrud(
          AppLocalizations.of(context),
          e,
          ditolak422: widget.ditolak422,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

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
              if (_galat != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _galat!,
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
          child: Text(l10n.crudBatalDialog),
        ),
        TextButton(
          key: const Key('aksi-dialog'),
          onPressed: _mengirim ? null : _jalankan,
          style: widget.destruktif
              ? TextButton.styleFrom(foregroundColor: tema.colorScheme.error)
              : null,
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
