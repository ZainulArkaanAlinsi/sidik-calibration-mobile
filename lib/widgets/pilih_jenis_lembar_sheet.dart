import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../services/jenis_lembar.dart';

/// Lembar pilihan "jenis lembar" untuk teknisi.
///
/// Dipakai setelah foto dibaca (kode formulir `SIDIK-FM-CAL-05xx`, judul, dan
/// revisi sebagai PETUNJUK berlapis, lihat `identifikasiLembar`). Aturannya:
///  - Tombol "Pilih jenis lembar manual" ([kunciPilihManual]) SELALU tampil:
///    saat kode terdeteksi, ambigu, tidak dikenal, maupun tidak terbaca.
///  - Pilihan AWAL mengikuti `praPilihTemplateId` milik pengenal: kode bersih
///    yang cocok tepat satu jenis, atau bukti berlapis yang kuat, unik, dan
///    saling sepakat. Teknisi bebas mengganti. Kode yang cocok dengan beberapa
///    jenis (0504, 0507, 0513, 0514 ...), dua kandidat yang berdekatan, kode
///    dan judul yang bertentangan, bacaan samar yang lemah, dan judul saja
///    menampilkan kandidatnya TANPA pilihan awal.
///  - Tidak ada navigasi atau pengisian otomatis: hasilnya hanya keluar saat
///    teknisi menekan "Pakai jenis lembar ini".
///
/// Dipanggil alur "Pindai lembar kerja" (`lib/screens/pindai/pindai_lembar_flow.dart`)
/// dari tombol di beranda teknisi, Master Data, dan super admin. Tombolnya
/// tersembunyi selama server belum menyatakan ada jenis lembar yang boleh
/// dipindai.
Future<FormulirDikenal?> tampilkanPilihJenisLembar(
  BuildContext context, {
  required HasilJenisLembar? petunjuk,
  required List<FormulirDikenal> dikenal,
}) => showModalBottomSheet<FormulirDikenal>(
  context: context,
  isScrollControlled: true,
  builder: (_) => PilihJenisLembarSheet(petunjuk: petunjuk, dikenal: dikenal),
);

class PilihJenisLembarSheet extends StatefulWidget {
  const PilihJenisLembarSheet({
    super.key,
    required this.petunjuk,
    required this.dikenal,
  });

  /// `null` = tidak ada petunjuk sama sekali.
  final HasilJenisLembar? petunjuk;

  /// Semua jenis lembar yang dikenal server (bahan daftar manual).
  final List<FormulirDikenal> dikenal;

  static const kunciPilihManual = ValueKey('jl-pilih-manual');
  static const kunciPakai = ValueKey('jl-pakai');

  static ValueKey<String> kunciBaris(String templateId) =>
      ValueKey('jl-baris-$templateId');

  @override
  State<PilihJenisLembarSheet> createState() => _PilihJenisLembarSheetState();
}

class _PilihJenisLembarSheetState extends State<PilihJenisLembarSheet> {
  String? _terpilih;
  bool _semua = false;

  HasilJenisLembar? get _p => widget.petunjuk;

  /// Kode lain di halaman = bacaan kacau / dua formulir: petunjuk tidak dipakai
  /// untuk menyempitkan daftar.
  bool get _petunjukDipakai => _p != null && _p!.kodeLain.isEmpty;

  List<FormulirDikenal> get _kandidat =>
      _petunjukDipakai ? _p!.kandidat : const [];

  @override
  void initState() {
    super.initState();

    // Pilihan AWAL datang dari keputusan pengenal (`praPilihTemplateId`): kode
    // bersih yang cocok tepat satu jenis, atau bukti berlapis yang kuat, unik,
    // dan saling sepakat. Kode ambigu, bacaan samar yang lemah, kode dan judul
    // yang bertentangan, serta judul saja tidak memilihkan (judul bukan
    // pengenal, hanya usulan yang ditampilkan).
    if (_petunjukDipakai) _terpilih = _p!.praPilihTemplateId;
    _semua = _kandidat.isEmpty;
  }

  FormulirDikenal? get _pilihan {
    for (final d in widget.dikenal) {
      if (d.templateId == _terpilih) return d;
    }
    for (final d in _kandidat) {
      if (d.templateId == _terpilih) return d;
    }

    return null;
  }

  String _pesan(AppLocalizations l10n) {
    final p = _p;
    if (p == null) return l10n.jlKodeTidakTerbaca;
    if (p.sumber == SumberJenisLembar.judul) return l10n.jlDariJudul;

    // Hasil pengenal berlapis membawa alasannya; pesan mengikuti alasan itu.
    switch (p.alasan) {
      case AlasanPetunjuk.bertentangan:
        return l10n.jlBertentangan;
      case AlasanPetunjuk.praPilihKodeSamar:
      case AlasanPetunjuk.praPilihBerlapis:
        return l10n.jlSamarCocok;
      case AlasanPetunjuk.lemah:
        return l10n.jlSamarUsulan;
      case AlasanPetunjuk.beberapaKandidat:
        return p.sumber == SumberJenisLembar.kodeSamar
            ? l10n.jlSamarUsulan
            : l10n.jlBeberapaJenis;
      case AlasanPetunjuk.praPilihKode:
      case AlasanPetunjuk.kodeBersama:
      case AlasanPetunjuk.kodeTakDikenal:
      case AlasanPetunjuk.judulSaja:
      case null:
        break;
    }

    final kode = p.kodeFormulir ?? '';
    if (p.kodeLain.isNotEmpty) {
      return l10n.jlBeberapaKode([kode, ...p.kodeLain].join(', '));
    }
    if (p.kandidat.isEmpty) return l10n.jlKodeTakDikenal(kode);
    if (p.kandidat.length > 1) return l10n.jlBeberapaJenis;

    return l10n.jlSatuJenis;
  }

  Widget _baris(FormulirDikenal d) {
    final dipilih = d.templateId == _terpilih;

    return ListTile(
      key: PilihJenisLembarSheet.kunciBaris(d.templateId),
      leading: Icon(
        dipilih ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(namaPendekJudul(d.judul)),
      subtitle: Text(d.kodeDokumen),
      selected: dipilih,
      onTap: () => setState(() => _terpilih = d.templateId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final kode = _p?.kodeFormulir;

    // Kandidat sudah tampil di atas; daftar manual memuat sisanya (kunci baris
    // tidak boleh kembar dalam satu kolom).
    final idKandidat = {for (final k in _kandidat) k.templateId};
    final semua = [
      for (final d in widget.dikenal)
        if (!idKandidat.contains(d.templateId)) d,
    ]..sort((a, b) => a.judul.compareTo(b.judul));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.jlJudul, style: tema.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (kode != null && _p!.sumber == SumberJenisLembar.kodeFormulir)
                Text(
                  l10n.jlKodeTerbaca(kode),
                  key: const ValueKey('jl-kode'),
                  style: tema.textTheme.bodyLarge,
                ),
              Text(_pesan(l10n), key: const ValueKey('jl-pesan')),
              const SizedBox(height: AppSpacing.sm),
              for (final d in _kandidat) _baris(d),
              OutlinedButton.icon(
                key: PilihJenisLembarSheet.kunciPilihManual,
                icon: const Icon(Icons.list_alt_outlined),
                label: Text(l10n.jlPilihManual),
                onPressed: () => setState(() => _semua = true),
              ),
              if (_semua) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.jlDaftarManual, style: tema.textTheme.titleSmall),
                for (final d in semua) _baris(d),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.jlCatatan, style: tema.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                key: PilihJenisLembarSheet.kunciPakai,
                onPressed: _pilihan == null
                    ? null
                    : () => Navigator.pop(context, _pilihan),
                child: Text(l10n.jlPakai),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
