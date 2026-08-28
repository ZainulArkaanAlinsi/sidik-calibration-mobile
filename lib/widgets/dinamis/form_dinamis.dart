/// Form yang bentuknya DITENTUKAN skema hasil baca lembar kerja, bukan ditulis
/// per jenis alat.
///
/// Satu berkas ini menggantikan kebutuhan bikin layar baru tiap ada lembar
/// baru: lembar tiga kolom digambar tiga kolom, lembar tujuh kolom digambar
/// tujuh, dan alat yang belum pernah ada di sistem tetap dapat form yang bisa
/// diisi.
///
/// ## Yang dijaga di sini
///
/// - Nilai yang diketik teknisi disimpan per KUNCI, bukan per posisi di layar.
///   Kunci datang dari server dan unik walau labelnya kembar.
/// - Nilai hasil baca yang keyakinannya rendah TETAP ditampilkan beserta
///   angkanya, ditandai jelas. Dikosongkan malah bikin teknisi ngetik ulang
///   dari nol, padahal tebakan yang 60% benar itu titik awal yang jauh lebih
///   cepat buat dikoreksi.
/// - Teks yang TERCETAK di formulir ditampilkan baca-saja. Nama standar yang
///   memang sudah dicetak nggak boleh kelihatan kayak kotak kosong yang lupa
///   diisi.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/skema_dinamis.dart';

/// Dipanggil tiap satu nilai diubah teknisi. [kunci] itu kunci dari skema.
typedef UbahNilaiDinamis = void Function(String kunci, String nilai);

/// Dipanggil waktu teknisi mau lihat asal satu nilai di gambar (poin
/// keterlacakan). `null` = nilainya nggak punya kotak asal.
typedef SorotAsal = void Function(KotakBatas? kotak, int halaman);

class FormDinamis extends StatelessWidget {
  const FormDinamis({
    super.key,
    required this.skema,
    required this.nilai,
    required this.onUbah,
    this.onSorot,
  });

  final SkemaDinamis skema;

  /// Nilai yang sedang berlaku, per kunci. Yang belum disentuh teknisi berisi
  /// hasil baca; yang sudah diketik berisi ketikannya.
  final Map<String, String> nilai;

  final UbahNilaiDinamis onUbah;
  final SorotAsal? onSorot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _KepalaDokumenView(dokumen: skema.dokumen),
        if (skema.peringatan.isNotEmpty)
          _PeringatanView(pesan: skema.peringatan),
        if (skema.adaYangPerluDilihat)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Pil(
              teks: l10n.dinamisPerluDiperiksaJumlah(skema.perluReview),
              warna: Theme.of(context).colorScheme.error,
            ),
          ),
        for (final bagian in skema.bagian)
          BagianDinamisView(
            bagian: bagian,
            nilai: nilai,
            onUbah: onUbah,
            onSorot: onSorot,
          ),
      ],
    );
  }
}

/// Satu bagian (section) — namanya dari kertas, bukan dari daftar tetap.
class BagianDinamisView extends StatelessWidget {
  const BagianDinamisView({
    super.key,
    required this.bagian,
    required this.nilai,
    required this.onUbah,
    this.onSorot,
  });

  final BagianDinamis bagian;
  final Map<String, String> nilai;
  final UbahNilaiDinamis onUbah;
  final SorotAsal? onSorot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bagian.nama != null)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              bagian.nama!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        for (final f in bagian.field)
          FieldDinamisView(
            field: f,
            nilai: nilai[f.kunci] ?? f.nilai ?? '',
            onUbah: onUbah,
            onSorot: onSorot,
          ),
        for (final t in bagian.tabel)
          TabelDinamisView(
            tabel: t,
            nilai: nilai,
            onUbah: onUbah,
            onSorot: onSorot,
          ),
      ],
    );
  }
}

/// Satu isian tunggal.
class FieldDinamisView extends StatelessWidget {
  const FieldDinamisView({
    super.key,
    required this.field,
    required this.nilai,
    required this.onUbah,
    this.onSorot,
  });

  final FieldDinamis field;
  final String nilai;
  final UbahNilaiDinamis onUbah;
  final SorotAsal? onSorot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = [
      field.label ?? l10n.dinamisTanpaLabel,
      if (field.satuan != null) '(${field.satuan})',
    ].join(' ');

    // Tercetak di formulir -> ditampilkan, bukan diminta diisi.
    if (!field.bisaDiisi) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(nilai.isEmpty ? l10n.dinamisBelumTerbaca : nilai),
          trailing: _Pil(
            teks: l10n.dinamisTercetak,
            warna: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        key: ValueKey(field.kunci),
        initialValue: nilai,
        keyboardType: field.tipe == 'number'
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        maxLines: field.tipe == 'multiline' ? 3 : 1,
        onChanged: (v) => onUbah(field.kunci, v),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: _keterangan(l10n, field.keyakinan, field.perluDilihat),
          helperStyle: field.perluDilihat
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
          suffixIcon: field.bbox == null || onSorot == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.image_search),
                  tooltip: l10n.dinamisLihatAsal,
                  onPressed: () => onSorot!(field.bbox, field.halaman),
                ),
        ),
      ),
    );
  }
}

/// Satu tabel — jumlah kolomnya dari kertas, bukan dari daftar tetap.
class TabelDinamisView extends StatelessWidget {
  const TabelDinamisView({
    super.key,
    required this.tabel,
    required this.nilai,
    required this.onUbah,
    this.onSorot,
  });

  final TabelDinamis tabel;
  final Map<String, String> nilai;
  final UbahNilaiDinamis onUbah;
  final SorotAsal? onSorot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Tabel tanpa kolom sama sekali NGGAK digambar.
    //
    // Bukan kerapian: `DataTable` menegaskan `columns.isNotEmpty`, jadi satu
    // tabel kosong yang lolos dari model bikin SELURUH form meledak — bukan
    // cuma tabel itu yang hilang. Jalur generik memang bisa menghasilkan ini
    // (bagian yang kelihatan bertabel tapi nggak satu selnya kebaca), dan
    // lembar yang paling jelek fotonya justru yang paling mungkin bikin
    // begini. Kalau ada isinya, `kolom` selalu keisi dari lebar barisnya.
    if (tabel.kolom.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tabel.nama != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              tabel.nama!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        // Tabel lebar digulung sendiri; halaman nggak boleh ikut geser
        // mendatar.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final k in tabel.kolom)
                DataColumn(label: Text(k.judul ?? l10n.dinamisTanpaJudulKolom)),
            ],
            rows: [
              for (final baris in tabel.baris)
                DataRow(
                  cells: [
                    for (final sel in baris)
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: SelDinamisView(
                            sel: sel,
                            nilai: nilai[sel.kunci] ?? sel.nilai ?? '',
                            onUbah: onUbah,
                            onSorot: onSorot,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class SelDinamisView extends StatelessWidget {
  const SelDinamisView({
    super.key,
    required this.sel,
    required this.nilai,
    required this.onUbah,
    this.onSorot,
  });

  final SelDinamis sel;
  final String nilai;
  final UbahNilaiDinamis onUbah;
  final SorotAsal? onSorot;

  @override
  Widget build(BuildContext context) {
    final warnaRagu = Theme.of(context).colorScheme.error;

    return TextFormField(
      key: ValueKey(sel.kunci),
      initialValue: nilai,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (v) => onUbah(sel.kunci, v),
      onTap: sel.bbox == null || onSorot == null
          ? null
          : () => onSorot!(sel.bbox, sel.halaman),
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        // Sel yang perlu diperiksa dikasih tanda di kotaknya sendiri —
        // ringkasan di atas cuma ngasih tahu ADA yang perlu dilihat, bukan
        // yang mana.
        enabledBorder: sel.perluDilihat
            ? OutlineInputBorder(borderSide: BorderSide(color: warnaRagu))
            : null,
      ),
    );
  }
}

class _KepalaDokumenView extends StatelessWidget {
  const _KepalaDokumenView({required this.dokumen});

  final KepalaDokumen dokumen;

  @override
  Widget build(BuildContext context) {
    final baris = [
      dokumen.judul,
      dokumen.namaAlat,
      [dokumen.kodeDokumen, dokumen.revisi].whereType<String>().join(' · '),
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    if (baris.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baris.first, style: Theme.of(context).textTheme.titleLarge),
          for (final b in baris.skip(1))
            Text(b, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PeringatanView extends StatelessWidget {
  const _PeringatanView({required this.pesan});

  final List<String> pesan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skema.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in pesan)
            Text(p, style: TextStyle(color: skema.onErrorContainer)),
        ],
      ),
    );
  }
}

class _Pil extends StatelessWidget {
  const _Pil({required this.teks, required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: warna),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(teks, style: TextStyle(color: warna, fontSize: 11)),
    );
  }
}

String? _keterangan(AppLocalizations l10n, double? keyakinan, bool perlu) {
  if (!perlu) return null;

  return keyakinan == null
      ? l10n.dinamisPerluDiperiksa
      : l10n.dinamisPerluDiperiksaKeyakinan((keyakinan * 100).round());
}
