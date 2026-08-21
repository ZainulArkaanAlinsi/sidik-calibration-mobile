import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/jam_lembar.dart';
import '../../../models/lembar_kerja.dart';
import '../lembar_kerja_state.dart';

/// Tabel MATRIKS: satu baris = satu besaran, satu kolom = satu titik waktu.
///
/// Bedanya dari [LembarKerjaTabel] bukan gaya, tapi arti sumbunya. Di tabel
/// biasa, baris = titik ukur dan kolom = pengulangan pembacaan titik yang
/// SAMA. Di sini baris = besaran yang berbeda-beda (`Temp. Disk 1`,
/// `Indikator Pressure`, `Suhu Ruang`) dan kolom = saat pengambilannya selama
/// proses berlangsung.
///
/// Susunannya SEBARIS-SEBARIS ngikut kertas, dan itu bukan soal selera:
/// teknisi ngisi layar ini sambil megang kertas yang barusan dia tulis di
/// lapangan, dan matanya lompat baris per baris. Waktu Autoklaf sempat
/// dipaksa masuk bentuk lembar pH (20 Agu 2026), baris kelima di kertas
/// (`Indikator Pressure`) ketemu baris kelima di layar (`Suhu Ruang`) — salah
/// salin satu baris berarti bacaan manometer masuk ke kolom suhu, dan angka
/// itu jalan terus sampai sertifikat tanpa satu pun error.
///
/// Yang mana mendarat di mana ditentukan [BarisMatriks.kodeData] dari backend,
/// bukan urutan baris di layar ini.
class LembarKerjaMatriks extends StatelessWidget {
  const LembarKerjaMatriks({
    super.key,
    required this.matriks,
    required this.isian,
    required this.onBerubah,
    this.tabelTambahan,
    this.setPoint,
  });

  final MatriksHasil matriks;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Tabel satu-baris di luar matriks (`Pressure Disk Logger`).
  final TabelSatuBaris? tabelTambahan;

  /// Kolom yang tercetak MENYATU sama kepala tabel di kertas — di Autoklaf
  /// `Set Point` duduk di pojok kiri-atas, sebaris sama banner kolom.
  final FieldLembarKerja? setPoint;

  static const _lebarLabel = 148.0;
  static const _lebarKolom = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kolom = matriks.titikWaktu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (setPoint != null || matriks.judulKolom.isNotEmpty)
                _barisKepala(context, theme, kolom.length),
              for (final b in matriks.semuaBaris)
                _baris(context, theme, b, kolom),
            ],
          ),
        ),

        if (tabelTambahan != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _TabelTambahan(
            tabel: tabelTambahan!,
            isian: isian,
            onBerubah: onBerubah,
            lebarLabel: _lebarLabel,
            lebarKolom: _lebarKolom,
          ),
        ],
      ],
    );
  }

  Widget _selLabel(ThemeData theme, String teks, {bool tebal = false}) =>
      Container(
        width: _lebarLabel,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          teks,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: tebal ? FontWeight.w600 : null,
          ),
        ),
      );

  /// Baris Set Point + banner kolom, persis kayak pojok kiri-atas kertasnya.
  Widget _barisKepala(BuildContext context, ThemeData theme, int jumlahKolom) {
    final sisa = jumlahKolom - (setPoint == null ? 0 : 1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selLabel(
            theme,
            setPoint == null
                ? ''
                : [
                    setPoint!.label,
                    if (setPoint!.satuan != null) '(${setPoint!.satuan})',
                  ].join(' '),
            tebal: true,
          ),
          if (setPoint != null)
            SizedBox(
              width: _lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  controller: isian.teks[setPoint!.kode],
                  onBerubah: onBerubah,
                ),
              ),
            ),
          if (sisa > 0)
            Container(
              width: _lebarKolom * sisa,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                matriks.judulKolom,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _baris(
    BuildContext context,
    ThemeData theme,
    BarisMatriks b,
    List<int> kolom,
  ) {
    // Satuan tekanan ikut kolom `satuan_tekanan` yang lagi kepilih — angkanya
    // sama, artinya beda tergantung Bar/Psi/kPa. Ditulis di label barisnya
    // supaya teknisi lihat satuannya di baris yang lagi dia isi, bukan cuma
    // jauh di atas di panel identitas alat.
    final satuan =
        b.satuan ??
        (b.satuanDari == null
            ? null
            : isian.teks[b.satuanDari]?.text.trim().isEmpty ?? true
            ? null
            : isian.teks[b.satuanDari]!.text.trim());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selLabel(
            theme,
            satuan == null ? b.label : '${b.label} ($satuan)',
            tebal: b.jam,
          ),
          for (final t in kolom)
            SizedBox(
              width: _lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: b.jam
                    ? _KotakJam(
                        controller: isian.kotakMatriks(b.kodeData, t),
                        onBerubah: onBerubah,
                      )
                    : _KotakAngka(
                        // Kunci per sel — dipakai test buat ngukur lebar kotak
                        // di lebar HP beneran. Kotak yang lebih sempit dari
                        // ~60 dp bikin angka berkoma tiga desimal (`1.231`)
                        // kepotong waktu dibaca ulang sebelum dikirim.
                        key: Key('matriks_${b.kodeData}_$t'),
                        controller: isian.kotakMatriks(b.kodeData, t),
                        onBerubah: onBerubah,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tabel satu-baris di bawah matriks. Autoklaf: `Pressure Disk Logger`.
///
/// Dikasih penanda "di luar kertas" terang-terangan. Teknisi yang nyocokin
/// layar ke lembarnya bakal nyariin baris ini di kertas dan nggak nemu —
/// tanpa penanda, dia bakal ngira layarnya yang salah, atau lebih buruk,
/// ngira barisnya boleh dilewat.
class _TabelTambahan extends StatelessWidget {
  const _TabelTambahan({
    required this.tabel,
    required this.isian,
    required this.onBerubah,
    required this.lebarLabel,
    required this.lebarKolom,
  });

  final TabelSatuBaris tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;
  final double lebarLabel;
  final double lebarKolom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (tabel.diLuarKertas) ...[
              Icon(
                Icons.info_outline,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                tabel.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (tabel.catatan != null) ...[
          const SizedBox(height: 4),
          Text(
            tabel.catatan!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: lebarLabel,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  color: theme.colorScheme.surfaceContainerHighest,
                  // Labelnya dipakai apa adanya. Ditempelin satuan lagi di
                  // sini bikin "Pressure Disk Logger — hasil unduh (Bar) (Bar)"
                  // — judul bloknya di atas SUDAH menyebut satuannya, dan
                  // backend nulis satuan itu di dua tempat.
                  child: Text(
                    tabel.label,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                for (final n in tabel.pengulangan)
                  SizedBox(
                    width: lebarKolom,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _KotakAngka(
                        controller: isian.kotakMatriks(tabel.kodeData, n),
                        onBerubah: onBerubah,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KotakAngka extends StatelessWidget {
  const _KotakAngka({
    super.key,
    required this.controller,
    required this.onBerubah,
  });

  final TextEditingController? controller;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => onBerubah(),
    );
  }
}

/// Jam pengambilan, bukan nomor urut kolom.
///
/// Nggak ikut dihitung, tapi tetap disimpan: tanpa jamnya lima kolom angka
/// nggak bisa diadu balik ke rekaman disk waktu sertifikatnya diperiksa.
///
/// **Teknisi cukup ngetik angka.** Titik duanya muncul sendiri
/// ([FormatJamLembar]), dan begitu kotaknya ditinggal isinya dirapikan jadi
/// `HH:MM:SS` — `2` jadi `02:00:00`, `830` jadi `08:30:00`.
///
/// Dulu kotak ini nerima ketikan bebas asal angka & titik dua, lalu dikirim apa
/// adanya. Backend nuntut `H:i`/`H:i:s`, jadi `8:30` ditolak — dan penolakannya
/// nyampe ke layar sebagai `The waktu.0 field must match the format H:i`, nama
/// yang nggak ada di kertas kerjanya sama sekali. Di HP efeknya dobel: titik
/// dua ada di papan tombol simbol, jadi tiap sel butuh dua kali pindah papan
/// tombol buat menghasilkan sesuatu yang ternyata ditolak.
class _KotakJam extends StatefulWidget {
  const _KotakJam({required this.controller, required this.onBerubah});

  final TextEditingController controller;
  final VoidCallback onBerubah;

  @override
  State<_KotakJam> createState() => _KotakJamState();
}

class _KotakJamState extends State<_KotakJam> {
  final _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fokus.addListener(_rapikanSaatDitinggal);
  }

  @override
  void dispose() {
    _fokus
      ..removeListener(_rapikanSaatDitinggal)
      ..dispose();
    super.dispose();
  }

  /// Dirapikan waktu DITINGGAL, bukan tiap ketukan: ngisi nol buat bagian yang
  /// belum diketik di tengah pengetikan bikin kursornya lompat.
  void _rapikanSaatDitinggal() {
    if (_fokus.hasFocus) return;

    final rapi = normalisasiJam(widget.controller.text);
    if (rapi == null || rapi == widget.controller.text) return;

    widget.controller.text = rapi;
    widget.onBerubah();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _fokus,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      // Papan tombol angka doang — titik duanya disisipin formatter, jadi
      // nggak ada lagi alasan mindah ke papan tombol simbol.
      keyboardType: TextInputType.number,
      inputFormatters: const [FormatJamLembar()],
      decoration: const InputDecoration(
        hintText: '--:--:--',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => widget.onBerubah(),
    );
  }
}
