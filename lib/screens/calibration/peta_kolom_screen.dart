import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/skema_dokumen.dart';
import '../../services/peta_kolom_titik.dart';

/// Apa yang dipulangkan layar ini kalau teknisi menekan terapkan.
typedef PetaKolomTerpakai = ({List<TitikDariDokumen> titik, String satuan});

/// Teknisi menunjuk arti tiap kolom yang dibaca dari kertas.
///
/// ## Kenapa layar ini ada, bukan ditebak saja
///
/// Ini satu-satunya langkah di jalur generik yang **butuh manusia**, dan itu
/// disengaja. Aplikasi bisa melihat bahwa kertasnya punya lima kolom dan dua
/// puluh sel angka; yang nggak bisa dia lihat kolom mana yang nilai acuan dan
/// kolom mana pembacaan alat.
///
/// Menebaknya dari kepala kolom (`Standard` → acuan, `Reading` → pembacaan)
/// kelihatan menggoda dan gampang. Dua sebab kenapa tidak:
///
///  1. Begitu ditulis, jalur generiknya mati. Yang tersisa daftar ejaan kepala
///     kolom — bentuk yang persis dihindari sejak awal, cuma pindah tempat.
///     Lembar berikutnya yang menulis `Set Point` atau `Nilai Rujukan` balik
///     memulangkan nol.
///  2. Ketuker antara acuan dan pembacaan menghasilkan **koreksi yang kebalik
///     tandanya** di sertifikat. Angkanya wajar, tabelnya wajar, dan salahnya
///     cuma ketahuan kalau ada yang mengadu ke kertas aslinya.
///
/// Yang kedua yang menutup perdebatan: kesalahan diam di angka yang
/// dipertanggungjawabkan lab itu kelas kesalahan paling mahal di proyek ini.
/// Satu ketukan dari teknisi jauh lebih murah.
///
/// Contoh isi sel ikut ditampilkan di bawah tiap kepala kolom — diambil dari
/// baris data pertama. Kepala kolom bisa nggak kebaca OCR atau memang nggak
/// dicetak; waktu itu terjadi, angkanya sendiri yang memberi tahu teknisi
/// kolom mana yang dia lihat.
class PetaKolomScreen extends StatefulWidget {
  const PetaKolomScreen({super.key, required this.tabel});

  final TabelSkema tabel;

  @override
  State<PetaKolomScreen> createState() => _PetaKolomScreenState();
}

class _PetaKolomScreenState extends State<PetaKolomScreen> {
  static const _peta = PetaKolomTitik();

  late final int _jumlahKolom = _hitungKolom();

  /// Semua kolom mulai dari [PeranKolom.abaikan] — nggak ada yang dipilihkan.
  ///
  /// Menyetel tebakan awal (mis. kolom pertama jadi acuan) bikin teknisi yang
  /// buru-buru menekan terapkan tanpa melihat, dan tebakan itu mendarat di data
  /// sebagai kalau dia yang memilih.
  late final List<PeranKolom> _peran = List.filled(
    _jumlahKolom,
    PeranKolom.abaikan,
  );

  final _satuan = TextEditingController();

  int _hitungKolom() {
    final t = widget.tabel;
    if (t.kepala.isNotEmpty) return t.kepala.length;
    return t.baris.isEmpty ? 0 : t.baris.first.length;
  }

  @override
  void initState() {
    super.initState();
    _satuan.addListener(_gambarUlang);
  }

  void _gambarUlang() => setState(() {});

  @override
  void dispose() {
    _satuan.removeListener(_gambarUlang);
    _satuan.dispose();
    super.dispose();
  }

  /// Contoh isi kolom [i] dari baris data PERTAMA yang selnya nggak kosong.
  ///
  /// Baris pertama bisa saja kosong di kolom itu (lembar yang belum selesai
  /// diisi), dan contoh kosong nggak menolong siapa pun.
  String? _contoh(int i) {
    for (final b in widget.tabel.baris) {
      if (i < b.length && b[i].trim().isNotEmpty) return b[i].trim();
    }
    return null;
  }

  String _judulKolom(int i, AppLocalizations l10n) {
    final kepala = widget.tabel.kepala;
    if (i < kepala.length && kepala[i].trim().isNotEmpty) return kepala[i];
    return l10n.petaKolomKolomKe(i + 1);
  }

  String _namaPeran(PeranKolom p, AppLocalizations l10n) => switch (p) {
    PeranKolom.abaikan => l10n.petaKolomAbaikan,
    PeranKolom.nilaiAcuan => l10n.petaKolomNilaiAcuan,
    PeranKolom.pembacaan => l10n.petaKolomPembacaan,
  };

  String _sebabBelumSah(PetaBelumSah s, AppLocalizations l10n) => switch (s) {
    PetaBelumSah.tanpaNilaiAcuan => l10n.petaKolomTanpaAcuan,
    PetaBelumSah.nilaiAcuanLebihDariSatu => l10n.petaKolomAcuanDobel,
    PetaBelumSah.pembacaanKurang => l10n.petaKolomPembacaanKurang(
      PetaKolomTitik.minPembacaan,
    ),
  };

  void _terapkan() {
    final hasil = _peta.petakan(tabel: widget.tabel, peran: _peran);

    Navigator.of(context).pop<PetaKolomTerpakai>((
      titik: hasil.titik,
      satuan: _satuan.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final belumSah = _peta.periksa(_peran);
    final hasil = _peta.petakan(tabel: widget.tabel, peran: _peran);

    // Satuan wajib diisi teknisi, dan sengaja NGGAK ditebak dari kertasnya.
    // Satuan yang salah di lembar kalibrasi bukan salah ketik — dia mengubah
    // arti seluruh angkanya.
    final satuanKosong = _satuan.text.trim().isEmpty;
    final bolehTerapkan =
        belumSah == null && !satuanKosong && hasil.titik.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.petaKolomJudul)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.petaKolomPengantar,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          for (var i = 0; i < _jumlahKolom; i++) _kartuKolom(i, l10n, theme),

          const SizedBox(height: 8),
          TextField(
            controller: _satuan,
            decoration: InputDecoration(
              labelText: l10n.petaKolomSatuan,
              helperText: l10n.petaKolomSatuanBantu,
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Yang mau dilakukan tombolnya ditulis SEBELUM ditekan. Teknisi
          // berhak tahu berapa titik yang bakal lahir dan berapa baris
          // kertasnya yang nggak ikut — sesudahnya, dia harus mengadu ke
          // kertas buat tahu ada yang hilang atau nggak.
          if (belumSah != null)
            _catatan(
              Icons.error_outline,
              _sebabBelumSah(belumSah, l10n),
              theme.colorScheme.error,
              theme,
            )
          else ...[
            _catatan(
              Icons.check_circle_outline,
              l10n.petaKolomRingkas(hasil.titik.length),
              theme.colorScheme.onSurfaceVariant,
              theme,
            ),
            if (hasil.barisDilewat > 0)
              _catatan(
                Icons.info_outline,
                l10n.petaKolomDilewat(hasil.barisDilewat),
                theme.colorScheme.onSurfaceVariant,
                theme,
              ),
          ],

          if (satuanKosong)
            _catatan(
              Icons.error_outline,
              l10n.petaKolomSatuanWajib,
              theme.colorScheme.error,
              theme,
            ),

          const SizedBox(height: 16),
          FilledButton(
            onPressed: bolehTerapkan ? _terapkan : null,
            child: Text(l10n.petaKolomTerapkan),
          ),
        ],
      ),
    );
  }

  Widget _catatan(IconData ikon, String teks, Color warna, ThemeData theme) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikon, size: 18, color: warna),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teks,
                style: theme.textTheme.bodyMedium?.copyWith(color: warna),
              ),
            ),
          ],
        ),
      );

  Widget _kartuKolom(int i, AppLocalizations l10n, ThemeData theme) {
    final contoh = _contoh(i);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _judulKolom(i, l10n),
                  style: theme.textTheme.labelLarge,
                ),
                if (contoh != null)
                  Text(
                    l10n.petaKolomContoh(contoh),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<PeranKolom>(
            value: _peran[i],
            onChanged: (p) {
              if (p == null) return;
              setState(() => _peran[i] = p);
            },
            items: [
              for (final p in PeranKolom.values)
                DropdownMenuItem(value: p, child: Text(_namaPeran(p, l10n))),
            ],
          ),
        ],
      ),
    );
  }
}
