import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/jam_lembar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/lembar_kerja.dart';
import '../../../providers/contoh_sel_provider.dart';
import '../../../services/potong_sel_foto.dart';
import '../../../services/ambil_foto_tabel.dart';
import '../../../services/peta_tabel_foto.dart';
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
    this.pindaiAktif = AppConfig.pindaiLembarAktif,
  });

  final MatriksHasil matriks;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Tabel satu-baris di luar matriks (`Pressure Disk Logger`).
  final TabelSatuBaris? tabelTambahan;

  /// Kolom yang tercetak MENYATU sama kepala tabel di kertas — di Autoklaf
  /// `Set Point` duduk di pojok kiri-atas, sebaris sama banner kolom.
  final FieldLembarKerja? setPoint;

  /// Tombol `FOTO TABEL INI` di atas matriks.
  ///
  /// **Sengaja TIDAK membaca `pindai_foto.didukung`.** Penanda itu menjawab
  /// pertanyaan lain — "kertas alat ini muat di bentuk titik ukur × Repeat?" —
  /// dan buat matriks jawabannya memang `false`: barisnya BESARAN yang
  /// berbeda-beda, bukan level dari besaran yang sama. Jalur di sini nggak
  /// memakai bentuk dua-penanda itu sama sekali; barisnya dijangkar TULISAN
  /// yang tercetak di kolom kiri.
  final bool pindaiAktif;

  static const _lebarLabel = 148.0;
  static const _lebarKolom = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kolom = matriks.titikWaktu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pindaiAktif) ...[
          SizedBox(
            width: double.infinity,
            child: _TombolFotoMatriks(
              matriks: matriks,
              isian: isian,
              onBerubah: onBerubah,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
                        dariFoto: isian.matriksDariFoto.contains(
                          LembarKerjaState.kunciMatriks(b.kodeData, t),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `FOTO TABEL INI` buat tabel MATRIKS (Autoklaf).
///
/// Aturannya sama dengan jalur tabel biasa — tiap angka wajib punya DUA jangkar
/// sebelum ditaruh — cuma jangkar barisnya beda:
///
///  - **baris** dari TULISAN besaran di kolom kiri (`Temp. Disk 1`,
///    `Indikator Pressure`). Bukan dari angka: baris matriks itu besaran, dan
///    `titik_ukur`-nya nol semua. Lihat [MatriksHasil.penandaBarisFoto].
///  - **kolom** dari kepala titik waktu yang tercetak di atasnya.
///
/// Baris yang tulisannya nggak kebaca nggak pernah keisi — dan itu justru
/// penjagaannya. Salah salin SATU baris di lembar ini berarti bacaan manometer
/// masuk ke kolom suhu, dan angka itu jalan terus sampai sertifikat tanpa satu
/// pun error; sudah pernah kejadian 20 Agu 2026 waktu Autoklaf sempat dipaksa
/// masuk bentuk lembar pH.
class _TombolFotoMatriks extends ConsumerStatefulWidget {
  const _TombolFotoMatriks({
    required this.matriks,
    required this.isian,
    required this.onBerubah,
  });

  final MatriksHasil matriks;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  ConsumerState<_TombolFotoMatriks> createState() => _TombolFotoMatriksState();
}

class _TombolFotoMatriksState extends ConsumerState<_TombolFotoMatriks> {
  bool _sibuk = false;

  Future<void> _foto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    void pesan(String teks, {int detik = 8}) => messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: detik),
        content: Text(teks),
      ),
    );

    setState(() => _sibuk = true);

    try {
      final foto = await ambilDanBacaTabel(ref);

      if (!mounted || foto.dibatalkan) return;

      if (foto.terbaca == null) {
        pesan(l10n.lkFotoTabelGagal, detik: 6);

        return;
      }

      final penanda = widget.matriks.penandaBarisFoto();

      final hasil = const PetaTabelFoto().petakan(
        terbaca: foto.terbaca!,
        titikUkur: penanda.penanda,
        pengulangan: widget.matriks.titikWaktu,
        fieldPerRepeat: const ['pembacaan'],
        labelTercetak: penanda.label,
        ukuranCitra: foto.ukuran,
      );

      if (!mounted) return;

      // Penanda baris yang KEMBAR disebut duluan, dan disebut beda.
      //
      // Ini satu-satunya sebab di daftar ini yang JEPRETAN ULANGNYA NGGAK
      // NOLONG: dua baris berbagi satu penanda itu bentuk lembarnya, bukan
      // fotonya. Ikut jatuh ke pesan "pastikan kepala kolomnya kefoto",
      // teknisi menjepret lembar yang sama berkali-kali tanpa satu pun
      // kemungkinan hasilnya berubah.
      //
      // Penandanya dibangun unik di `MatriksHasil.penandaBarisFoto`,
      // jadi cabang ini nggak punya jalan masuk hari ini. Tetap dipasang:
      // yang dijaga bukan bug yang ada sekarang, tapi harga kalau cara
      // membangun penandanya berubah — dan harganya teknisi yang terjebak
      // motret selamanya.
      if (hasil.barisKembar.isNotEmpty) {
        pesan(
          l10n.lkFotoTabelBarisKembar(
            hasil.barisKembar
                .map((b) => penanda.label[b] ?? '${b.round()}')
                .join(', '),
          ),
        );

        return;
      }

      if (hasil.kosong) {
        pesan(
          hasil.titikKetemu.isNotEmpty && hasil.repeatKetemu.isNotEmpty
              ? l10n.lkFotoTabelKosong
              : l10n.lkMatriksFotoTanpaJangkar,
        );

        return;
      }

      // Potongan selnya DITAHAN sampai teknisi menekan Simpan — labelnya angka
      // final, bukan yang dibaca OCR sekarang. Lihat [PenampungContohSel].
      //
      // Alamat sel matriks BEDA dari lembar bertabel: barisnya besaran
      // (`suhu.disk.0`), bukan titik ukur. Makanya pembaca labelnya disediakan
      // di sini, di tempat yang tahu bentuk formulirnya.
      //
      // Kegagalannya sengaja DIAM: ini pengumpul data latih, bukan bagian
      // kalibrasinya.
      final citra = foto.citra;

      if (citra != null && hasil.kotakSel.isNotEmpty) {
        // Disalin ke lokal — closure-nya hidup sampai Simpan, dan `widget`
        // ditukar tiap rebuild.
        final matriks = widget.matriks;
        final isian = widget.isian;

        try {
          (await ref.read(penampungContohSelProvider.future)).tampung(
            potongan: const PotongSelFoto()
                .potong(citra: citra, kotak: hasil.kotakSel)
                .potongan,
            penanda: (k) => 'matriks|${k.titikUkur}|${k.repeatNo}',
            labelAkhir: (k) =>
                isian.labelSelMatriks(matriks, k.titikUkur, k.repeatNo),
          );
        } catch (_) {
          // Sengaja ditelan — lihat di atas.
        }
      }

      final terisi = widget.isian.terapkanHasilFotoMatriks(
        widget.matriks,
        hasil.sel,
      );

      widget.onBerubah();

      pesan(
        hasil.angkaTakTerpetakan == 0
            ? l10n.lkFotoTabelTerisi(terisi)
            : l10n.lkFotoTabelSebagian(terisi, hasil.angkaTakTerpetakan),
        detik: 6,
      );
    } catch (e) {
      if (mounted) pesan(l10n.lkFotoTabelError('$e'), detik: 6);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OutlinedButton.icon(
      key: const Key('matriks_foto'),
      onPressed: _sibuk ? null : _foto,
      icon: _sibuk
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.photo_camera_outlined, size: 18),
      label: Text(l10n.lkFotoTabel),
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
                  child: Text(tabel.label, style: theme.textTheme.bodySmall),
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
    this.dariFoto = false,
  });

  final TextEditingController? controller;
  final VoidCallback onBerubah;

  /// Isinya datang dari FOTO, belum diadu ke kertas. Kuningnya sama dengan
  /// `TandaSel.keyakinanRendah` di jalur tabel, dan artinya sama: saran mesin.
  final bool dariFoto;

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
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: const OutlineInputBorder(),
        enabledBorder: dariFoto
            ? const OutlineInputBorder(
                borderSide: BorderSide(color: kuningPerluDicek, width: 2),
              )
            : null,
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
