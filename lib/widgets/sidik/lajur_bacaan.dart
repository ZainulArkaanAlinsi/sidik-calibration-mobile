import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../core/theme/warna_lajur.dart';
// Aturan mengetik (digit, koma desimal, minus, hapus) dan ambang keypad layar
// dipakai APA ADANYA dari keypad yang sudah ada: Lajur tidak menulis aturan
// parsing sendiri, jadi lembar kerja dan layar tinjau foto mengetik dengan
// aturan yang sama. Berkas itu hanya dibaca, tidak diubah.
import '../../screens/calibration/widgets/keypad_angka.dart';

/// Cara Lajur menerima angka.
enum ModeLajur {
  /// Keypad layar besar (digit, koma, minus, hapus, "Berikutnya" tinggi).
  keypad,

  /// Tanpa keypad: papan ketik sistem yang mengetik (di cell lembar), Lajur
  /// hanya memperlihatkan sel dan tombol "Berikutnya". Dipakai di layar
  /// pendek, huruf besar, dan HP lanskap ([bolehKeypadLayar]).
  ringkas,
}

/// Kata-kata Lajur untuk pembaca layar dan tombol. Bawaan Indonesia; layar
/// mengirim terjemahan bila perlu.
@immutable
class LabelLajur {
  const LabelLajur({
    this.berikutnya = 'Berikutnya',
    this.hapus = 'Hapus satu karakter',
    this.minus = 'Tanda minus',
    this.koma = 'Koma desimal',
    this.papanKetik = 'Pakai papan ketik sistem',
    this.keypad = 'Pakai keypad angka',
    this.kelompokKeypad = 'Keypad angka',
    this.belumDiisi = 'Belum diisi',
    this.nilai = 'Nilai',
    this.pengulangan = 'Pengulangan',
    this.dari = 'dari',
  });

  final String berikutnya;
  final String hapus;
  final String minus;
  final String koma;
  final String papanKetik;
  final String keypad;

  /// Nama kelompok tombol keypad untuk pembaca layar.
  final String kelompokKeypad;
  final String belumDiisi;
  final String nilai;
  final String pengulangan;
  final String dari;
}

/// LAJUR BACAAN: panel instrumen gelap untuk sel angka yang sedang diisi.
///
/// Satu-satunya momen "berani" di Lab, dan fungsional: permukaan gelap di atas
/// layar terang memberi tahu teknisi "di sini angka masuk". Isinya, dari atas:
///
/// 1. kepala: [judul] sel, [subjudul], [posisi] ("8/30") dan tik
///    [pengulangan] (tik ke-3 dari 5);
/// 2. [catatan] opsional (mis. "Saran dari foto, periksa angkanya");
/// 3. angka besar Plex Mono dengan kursor kobalt terang dan [satuan];
/// 4. keypad 4 x 4 (digit, koma, minus, hapus) dengan tombol tinggi
///    "Berikutnya" yang merentang tiga baris. Tombol keypad 52 dp (HP) atau
///    64 dp (tablet).
///
/// ## Batas (sengaja)
///
/// - TIDAK menghitung, memvonis, atau mewarnai angka hijau/merah, dan TIDAK
///   menampilkan selisih terhadap sel lain: HP tidak menghitung hasil, dan
///   selisih mana yang bermakna per alat masih pertanyaan untuk lab. Warna
///   Lajur hanya dari [WarnaLajur] (tanpa hijau atau merah).
/// - TIDAK mengisi apa pun sendiri. [onUbah] menerima teks baru hasil
///   `terapkanTombolKeypad`; "Berikutnya" pada sel kosong tidak menyalin angka
///   dari sel lain (aturan OCR: sel kosong tetap kosong).
/// - Papan ketik sistem tetap bisa dipakai sebagai cadangan: [onPakaiPapanKetik]
///   menampilkan tombol untuk beralih, dan [ModeLajur.ringkas] adalah bentuk
///   Lajur saat papan ketik sistem yang mengetik.
///
/// Lajur tidak membuka sendiri: layar yang memakainya memasangnya di dasar
/// layar atau di kolom kanan tablet (380 dp, dengan peta lembar di atasnya).
class LajurBacaan extends StatelessWidget {
  const LajurBacaan({
    super.key,
    required this.judul,
    required this.nilai,
    required this.onUbah,
    required this.onBerikutnya,
    this.subjudul,
    this.posisi,
    this.pengulangan,
    this.satuan,
    this.catatan,
    this.alasanMati,
    this.mode,
    this.onPakaiPapanKetik,
    this.onPakaiKeypad,
    this.label = const LabelLajur(),
  });

  /// Nama sel yang diisi ("Set point 150 °C").
  final String judul;

  /// Keterangan kedua ("Detik ke-20").
  final String? subjudul;

  /// Urutan sel di lembar: `ke` dari `dari` ("8/30").
  final ({int ke, int dari})? posisi;

  /// Pengulangan: `ke` dari `dari` (tik ke-3 dari 5). Tik digambar bila
  /// `dari` <= 10.
  final ({int ke, int dari})? pengulangan;

  /// Isi sel sekarang, memakai koma desimal ("150,0"). Kosong = belum diisi.
  final String nilai;

  /// Satuan di belakang angka ("°C").
  final String? satuan;

  /// Menerima teks baru setiap tombol keypad mengubah [nilai].
  final ValueChanged<String> onUbah;

  /// Pindah ke sel berikutnya. `null` = mati (isi [alasanMati]).
  final VoidCallback? onBerikutnya;

  /// Kalimat pendek di atas tombol saat [onBerikutnya] `null`.
  final String? alasanMati;

  /// Keadaan sel yang perlu diketahui sebelum mengetik, ikon + kata, amber.
  /// Bukan penilaian angka.
  final String? catatan;

  /// `null` = otomatis menurut [bolehKeypadLayar].
  final ModeLajur? mode;

  /// Menampilkan tombol "Pakai papan ketik sistem" (mode keypad).
  final VoidCallback? onPakaiPapanKetik;

  /// Menampilkan tombol "Pakai keypad angka" (mode ringkas).
  final VoidCallback? onPakaiKeypad;

  final LabelLajur label;

  /// Mode yang dipakai untuk [mq] bila [mode] `null`.
  static ModeLajur modeUntuk(MediaQueryData mq) =>
      bolehKeypadLayar(mq) ? ModeLajur.keypad : ModeLajur.ringkas;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ragam = mode ?? modeUntuk(mq);
    final tablet = mq.size.shortestSide >= AmbangLab.tablet;
    final w = WarnaLajur.of(context);
    final t = Theme.of(context).textTheme;

    final gayaJudul = t.titleMedium?.copyWith(color: w.angka);
    final gayaRedup = t.bodySmall?.copyWith(color: w.redup);

    final kepala = _Kepala(
      judul: judul,
      subjudul: subjudul,
      posisi: posisi,
      pengulangan: pengulangan,
      warna: w,
      gayaJudul: gayaJudul,
      gayaRedup: gayaRedup,
      label: label,
    );

    final angka = _Angka(
      nilai: nilai,
      satuan: satuan,
      warna: w,
      ringkas: ragam == ModeLajur.ringkas,
      tablet: tablet,
      label: label,
    );

    final tombolGanti = ragam == ModeLajur.keypad
        ? (onPakaiPapanKetik == null
              ? null
              : _TombolGanti(
                  ikon: Icons.keyboard_alt_outlined,
                  teks: label.papanKetik,
                  warna: w,
                  onTap: onPakaiPapanKetik!,
                ))
        : (onPakaiKeypad == null
              ? null
              : _TombolGanti(
                  ikon: Icons.dialpad,
                  teks: label.keypad,
                  warna: w,
                  onTap: onPakaiKeypad!,
                ));

    final tampilAlasan = onBerikutnya == null && alasanMati != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: w.panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(BentukLab.lembar),
        ),
        border: Border.all(color: w.garisAtas, width: AppUkuran.garis),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AmbangLab.lebarBilah),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  kepala,
                  if (catatan != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Catatan(teks: catatan!, warna: w),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  angka,
                  if (tombolGanti != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: tombolGanti,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (tampilAlasan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(alasanMati!, style: gayaRedup),
                    ),
                  if (ragam == ModeLajur.keypad)
                    _Keypad(
                      nilai: nilai,
                      onUbah: onUbah,
                      onBerikutnya: onBerikutnya,
                      warna: w,
                      label: label,
                      tablet: tablet,
                    )
                  else
                    SizedBox(
                      height: UkuranLab.aksiUtama,
                      child: _TombolBerikutnya(
                        onPressed: onBerikutnya,
                        warna: w,
                        label: label.berikutnya,
                        ikonSaja: false,
                        tegak: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({
    required this.judul,
    required this.subjudul,
    required this.posisi,
    required this.pengulangan,
    required this.warna,
    required this.gayaJudul,
    required this.gayaRedup,
    required this.label,
  });

  final String judul;
  final String? subjudul;
  final ({int ke, int dari})? posisi;
  final ({int ke, int dari})? pengulangan;
  final WarnaLajur warna;
  final TextStyle? gayaJudul;
  final TextStyle? gayaRedup;
  final LabelLajur label;

  @override
  Widget build(BuildContext context) {
    final kalimat = [
      judul,
      ?subjudul,
      if (posisi != null) '${posisi!.ke} ${label.dari} ${posisi!.dari}',
      if (pengulangan != null)
        '${label.pengulangan} ${pengulangan!.ke} ${label.dari} '
            '${pengulangan!.dari}',
    ].join(', ');

    return Semantics(
      container: true,
      label: kalimat,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: gayaJudul,
                ),
                if (subjudul != null)
                  Text(
                    subjudul!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: gayaRedup,
                  ),
              ],
            ),
          ),
          if (posisi != null || pengulangan != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (posisi != null)
                  Text(
                    '${posisi!.ke}/${posisi!.dari}',
                    style: SidikTheme.gayaAngka(
                      ukuran: UkuranTeksLab.stempel,
                      berat: FontWeight.w500,
                      warna: warna.redup,
                    ),
                  ),
                if (pengulangan != null && pengulangan!.dari <= _maksTik) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _TikUlang(
                    ke: pengulangan!.ke,
                    dari: pengulangan!.dari,
                    warna: warna,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Tik pengulangan digambar sampai sekian pengulangan.
  static const int _maksTik = 10;
}

/// Tik pengulangan: yang sudah lewat = batang pejal redup, yang sekarang =
/// batang kobalt terang yang lebih tinggi, yang belum = hanya garis tepi.
/// Bentuk (tinggi dan isi) membedakannya, bukan warna saja.
class _TikUlang extends StatelessWidget {
  const _TikUlang({required this.ke, required this.dari, required this.warna});

  final int ke;
  final int dari;
  final WarnaLajur warna;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= dari; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 1 ? 0 : AppSpacing.xs / 2),
            child: SizedBox(
              key: ValueKey(
                i < ke
                    ? 'tik-ulang-lewat-$i'
                    : i == ke
                    ? 'tik-ulang-kini-$i'
                    : 'tik-ulang-nanti-$i',
              ),
              width: UkuranTikLab.tikUlang,
              height: i == ke
                  ? UkuranTikLab.tinggiTikUlang * 2
                  : UkuranTikLab.tinggiTikUlang,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i == ke ? warna.aksen : (i < ke ? warna.redup : null),
                  border: i > ke
                      ? Border.all(
                          color: warna.tepiKunci,
                          width: AppUkuran.garis,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks, required this.warna});

  final String teks;
  final WarnaLajur warna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final skala = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: teks,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs / 2),
            child: Icon(
              Icons.info_outline,
              size: skala.scale(UkuranIkonLab.stempel),
              color: warna.peringatan,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              teks,
              style: t.bodySmall?.copyWith(color: warna.peringatan),
            ),
          ),
        ],
      ),
    );
  }
}

/// Angka besar: Plex Mono 500 (HP 40/48, tablet 56/64; ringkas 24) dengan
/// kursor kobalt terang. Mengecil (tidak memotong) bila 12 karakter + satuan
/// tidak muat.
class _Angka extends StatelessWidget {
  const _Angka({
    required this.nilai,
    required this.satuan,
    required this.warna,
    required this.ringkas,
    required this.tablet,
    required this.label,
  });

  final String nilai;
  final String? satuan;
  final WarnaLajur warna;
  final bool ringkas;
  final bool tablet;
  final LabelLajur label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ukuran = ringkas
        ? UkuranTeksLab.angkaRingkas
        : (tablet
              ? UkuranTeksLab.angkaBacaanTablet
              : UkuranTeksLab.angkaBacaan);
    final baris = ringkas
        ? UkuranTeksLab.angkaRingkas * 4 / 3
        : (tablet
              ? UkuranTeksLab.angkaBacaanTabletBaris
              : UkuranTeksLab.angkaBacaanBaris);
    final kosong = nilai.isEmpty;
    final gaya = SidikTheme.gayaAngka(
      ukuran: ukuran,
      berat: FontWeight.w500,
      warna: warna.angka,
    ).copyWith(height: baris / ukuran);

    final bacaan = kosong
        ? '${label.nilai}: ${label.belumDiisi}'
        : '${label.nilai}: $nilai${satuan == null ? '' : ' $satuan'}';

    return Semantics(
      liveRegion: true,
      label: bacaan,
      excludeSemantics: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!kosong)
                Text(nilai, key: const Key('lajur-nilai'), style: gaya),
              Container(
                key: const Key('lajur-kursor'),
                width: UkuranLajur.kursor,
                height: ukuran,
                color: warna.aksen,
              ),
              if (kosong) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label.belumDiisi,
                  key: const Key('lajur-kosong'),
                  style: t.titleMedium?.copyWith(color: warna.redup),
                ),
              ],
              if (satuan != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  satuan!,
                  key: const Key('lajur-satuan'),
                  style: t.titleLarge?.copyWith(
                    color: warna.redup,
                    fontSize: UkuranTeksLab.satuanBacaan,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TombolGanti extends StatelessWidget {
  const _TombolGanti({
    required this.ikon,
    required this.teks,
    required this.warna,
    required this.onTap,
  });

  final IconData ikon;
  final String teks;
  final WarnaLajur warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: warna.aksen,
        minimumSize: Size(0, UkuranLab.aksi),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      icon: Icon(ikon, size: UkuranIkonLab.sebaris),
      label: Text(teks, style: t.labelLarge?.copyWith(color: warna.aksen)),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.nilai,
    required this.onUbah,
    required this.onBerikutnya,
    required this.warna,
    required this.label,
    required this.tablet,
  });

  final String nilai;
  final ValueChanged<String> onUbah;
  final VoidCallback? onBerikutnya;
  final WarnaLajur warna;
  final LabelLajur label;
  final bool tablet;

  /// Lebar kolom: tiga kolom digit sama lebar, kolom keempat sedikit lebih
  /// lebar supaya kata "Berikutnya" muat pada 392 dp.
  static const int _bobotDigit = 4;
  static const int _bobotAksi = 5;

  void _tekan(TombolKeypad tombol) {
    final baru = terapkanTombolKeypad(nilai, tombol);
    if (baru != nilai) onUbah(baru);
  }

  @override
  Widget build(BuildContext context) {
    final tinggi = tablet ? UkuranLajur.tombolTablet : UkuranLajur.tombolHp;
    const jarak = AppSpacing.sm;
    final tinggiBerikutnya =
        UkuranLajur.barisBerikutnya * tinggi +
        (UkuranLajur.barisBerikutnya - 1) * jarak;

    // Urutan baca = urutan BARIS (7 8 9 hapus, 4 5 6 Berikutnya, 1 2 3, minus
    // 0 koma), bukan urutan kolom pohon widget: tata letak visualnya per baris.
    Widget kunci(
      Widget isi,
      TombolKeypad tombol, {
      required String semantik,
      required String kunciUji,
      required int urutan,
    }) => _Kunci(
      key: Key('keypad-$kunciUji'),
      tinggi: tinggi,
      warna: warna,
      semantik: semantik,
      urutan: urutan,
      onTap: () => _tekan(tombol),
      isi: isi,
    );

    Widget digit(String d, int urutan) => kunci(
      _TeksKunci(d, warna),
      TombolDigit(d),
      semantik: d,
      kunciUji: d,
      urutan: urutan,
    );

    Widget kolom(List<Widget> baris, int bobot) => Expanded(
      flex: bobot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < baris.length; i++) ...[
            if (i > 0) const SizedBox(height: jarak),
            baris[i],
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label.kelompokKeypad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kolom([
            digit('7', 1),
            digit('4', 5),
            digit('1', 9),
            kunci(
              _TeksKunci('−', warna),
              const TombolMinus(),
              semantik: label.minus,
              kunciUji: 'minus',
              urutan: 12,
            ),
          ], _bobotDigit),
          const SizedBox(width: jarak),
          kolom([
            digit('8', 2),
            digit('5', 6),
            digit('2', 10),
            digit('0', 13),
          ], _bobotDigit),
          const SizedBox(width: jarak),
          kolom([
            digit('9', 3),
            digit('6', 7),
            digit('3', 11),
            kunci(
              _TeksKunci(',', warna),
              const TombolKoma(),
              semantik: label.koma,
              kunciUji: 'koma',
              urutan: 14,
            ),
          ], _bobotDigit),
          const SizedBox(width: jarak),
          kolom([
            kunci(
              Icon(
                Icons.backspace_outlined,
                size: UkuranIkonLab.navigasi,
                color: warna.angka,
              ),
              const TombolHapus(),
              semantik: label.hapus,
              kunciUji: 'hapus',
              urutan: 4,
            ),
            SizedBox(
              height: tinggiBerikutnya,
              child: LayoutBuilder(
                builder: (context, batas) => _TombolBerikutnya(
                  onPressed: onBerikutnya,
                  warna: warna,
                  label: label.berikutnya,
                  ikonSaja: !_labelMuat(context, batas.maxWidth),
                  tegak: true,
                  urutan: 8,
                ),
              ),
            ),
          ], _bobotAksi),
        ],
      ),
    );
  }

  /// Apakah kata "Berikutnya" muat satu baris di lebar [lebar] (dikurangi
  /// bantalan tombol) pada skala huruf yang berlaku. Bila tidak, tombol
  /// menampilkan panah saja dan kata tetap dibacakan.
  bool _labelMuat(BuildContext context, double lebar) {
    final gaya = _gayaBerikutnya(context, warna);
    final pengukur = TextPainter(
      text: TextSpan(text: label.berikutnya, style: gaya),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final muat = pengukur.width <= lebar - 2 * AppSpacing.xs;
    pengukur.dispose();
    return muat;
  }
}

TextStyle? _gayaBerikutnya(BuildContext context, WarnaLajur w) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(color: w.teksTombol);

class _TeksKunci extends StatelessWidget {
  const _TeksKunci(this.teks, this.warna);

  final String teks;
  final WarnaLajur warna;

  @override
  Widget build(BuildContext context) => Text(
    teks,
    style: SidikTheme.gayaAngka(
      ukuran: UkuranTeksLab.tombolKeypad,
      berat: FontWeight.w500,
      warna: warna.angka,
    ),
  );
}

class _Kunci extends StatelessWidget {
  const _Kunci({
    super.key,
    required this.tinggi,
    required this.warna,
    required this.semantik,
    required this.urutan,
    required this.onTap,
    required this.isi,
  });

  final double tinggi;
  final WarnaLajur warna;
  final String semantik;

  /// Urutan baca (per baris) di antara tombol keypad.
  final int urutan;
  final VoidCallback onTap;
  final Widget isi;

  @override
  Widget build(BuildContext context) {
    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukLab.kontrol),
      side: BorderSide(color: warna.tepiKunci, width: AppUkuran.garis),
    );
    return Semantics(
      button: true,
      label: semantik,
      sortKey: OrdinalSortKey(urutan.toDouble()),
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        height: tinggi,
        child: Material(
          color: warna.kunci,
          shape: bentuk,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: bentuk,
            child: Center(child: isi),
          ),
        ),
      ),
    );
  }
}

/// Tombol "Berikutnya": kobalt terang dengan label kobalt tua, sudut 16.
/// Dalam keypad ia merentang tiga baris; mati = permukaan kunci + kata redup.
class _TombolBerikutnya extends StatelessWidget {
  const _TombolBerikutnya({
    required this.onPressed,
    required this.warna,
    required this.label,
    required this.ikonSaja,
    required this.tegak,
    this.urutan,
  });

  final VoidCallback? onPressed;
  final WarnaLajur warna;
  final String label;

  /// Hanya panah (kata dibacakan lewat semantik).
  final bool ikonSaja;

  /// Panah di atas kata (tombol tinggi di keypad); `false` = sebaris.
  final bool tegak;

  /// Urutan baca di antara tombol keypad (hanya di dalam keypad).
  final int? urutan;

  @override
  Widget build(BuildContext context) {
    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukLab.utama),
    );
    final penunjuk = Icon(Icons.arrow_forward, size: UkuranIkonLab.navigasi);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      sortKey: urutan == null ? null : OrdinalSortKey(urutan!.toDouble()),
      onTap: onPressed,
      excludeSemantics: true,
      child: FilledButton(
        key: const Key('lajur-berikutnya'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: warna.tombol,
          foregroundColor: warna.teksTombol,
          disabledBackgroundColor: warna.kunci,
          disabledForegroundColor: warna.redup,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          shape: bentuk,
        ),
        child: ikonSaja
            ? penunjuk
            : tegak
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  penunjuk,
                  // Tanpa gaya sendiri: warna kata mengikuti keadaan tombol (aktif atau
                  // mati) dari `foregroundColor` dan `disabledForegroundColor`.
                  Text(label, maxLines: 1, softWrap: false),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label)),
                  const SizedBox(width: AppSpacing.sm),
                  penunjuk,
                ],
              ),
      ),
    );
  }
}
