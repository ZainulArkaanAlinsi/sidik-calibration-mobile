import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/lembar_kerja.dart';
import '../../../models/standard.dart';
import '../../../providers/calibration_input_provider.dart';
import '../../../providers/sumber_foto_provider.dart';
import '../../../providers/worksheet_scan_provider.dart';
import '../../../services/peta_tabel_foto.dart';
import '../lembar_kerja_state.dart';
import 'dropdown_gagal.dart';

/// Satu tabel hasil kalibrasi — Before atau After adjustment.
///
/// Susunannya ngikutin tabel yang tercetak di lembar kerja: **baris = larutan
/// standar**, **kolom = Repeat 1..5**, dan tiap sel isinya **dua angka**
/// (pH & °C). Jumlah baris/kolom/pengulangannya diambil dari [tabel] yang
/// dikirim backend, bukan dipatok di sini.
///
/// Tabelnya digulung mendatar, bukan diperas biar muat: lima Repeat × dua
/// kotak angka nggak akan kebaca di layar HP kalau dipaksa masuk. Kolom
/// pertama (nilai larutan standar) tetap nempel di kiri supaya teknisi nggak
/// kehilangan konteks baris waktu geser ke Repeat 5.
class LembarKerjaTabel extends StatelessWidget {
  const LembarKerjaTabel({
    super.key,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  final TabelHasil tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Baris yang digambar — **ngikut satuan yang lagi kepilih**, bukan
  /// `tabel.baris` yang isinya set bawaan dari backend.
  ///
  /// Refractometer ngirim titik standar beda per skala (1,33659/1,39986 n20D
  /// vs 2,5/40 °Brix), dan `LembarKerjaState` mbangun `titik`-nya dari set yang
  /// kepilih. Waktu widget ini masih baca `tabel.baris` sementara state-nya
  /// udah pindah ke °Brix, `isian.titik[...]!` nabrak null dan tabelnya gagal
  /// digambar sama sekali.
  List<BarisTabelHasil> get _baris => tabel.barisUntuk(isian.satuan);

  static const _lebarSel = 78.0;

  /// Batas kolom label. Bawahnya lebar lama — cukup buat pH (`4`, `7`, `10`).
  /// Atasnya biar area gulung nggak keburu habis di HP sempit.
  static const _lebarLabelMin = 104.0;
  static const _lebarLabelMaks = 152.0;

  /// Jarak nafas di dalam sel label, kiri-kanan dan atas-bawah.
  static const _selaLabel = 8.0;

  /// Ukur kolom label dari ISINYA, bukan dipatok.
  ///
  /// Dulu 104×56 mati. Angka itu pas buat pH, tapi sesak buat Conductivity yang
  /// labelnya bawa satuan (`1,412 mS/cm`) DAN nambah baris keterangan waktu
  /// barisnya terkunci — dua-duanya numpuk di sel yang sama dan meluber 8px.
  ///
  /// Tingginya dipukul rata SATU nilai buat semua baris, bukan per baris:
  /// kolom label ini di luar area gulung, jadi kalau tingginya beda-beda dia
  /// langsung lari dari baris sel angka di sebelahnya.
  ({double lebar, double tinggi}) _ukurKolomLabel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final skala = MediaQuery.textScalerOf(context);

    final gayaLabel = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final gayaCatatan = theme.textTheme.labelSmall;

    double ukur(String teks, TextStyle? gaya, double lebarMaks, int? baris) {
      final pelukis = TextPainter(
        text: TextSpan(text: teks, style: gaya),
        textDirection: Directionality.of(context),
        textScaler: skala,
        maxLines: baris,
      )..layout(maxWidth: lebarMaks);

      return baris == null ? pelukis.width : pelukis.height;
    }

    final teksBaris = [for (final baris in _baris) _labelBaris(baris)];

    // Lebar: cukup buat label terpanjang tanpa membungkus, dalam batas di atas.
    var lebar = _lebarLabelMin;
    for (final teks in [...teksBaris, 'Standard']) {
      final perlu = ukur(teks, gayaLabel, double.infinity, null) + _selaLabel;
      if (perlu > lebar) lebar = perlu;
    }
    lebar = lebar.clamp(_lebarLabelMin, _lebarLabelMaks);

    // Tinggi: diukur PADA lebar yang barusan diputuskan — label yang masih
    // membungkus di lebar maksimum tetap kehitung.
    final adaCatatan = _baris.any((b) => isian.titikTerkunci(b.titikUkur));
    final lebarIsi = lebar - _selaLabel;

    var tinggi = _tinggiBarisMin;
    for (final teks in teksBaris) {
      var perlu = ukur(teks, gayaLabel, lebarIsi, 2);

      if (adaCatatan) {
        perlu += ukur(l10n.lkTitikAlternatifSatuan, gayaCatatan, lebarIsi, 2);
      }

      perlu += _selaLabel;
      if (perlu > tinggi) tinggi = perlu;
    }

    return (lebar: lebar, tinggi: tinggi);
  }


  /// Teks kolom nilai standar.
  ///
  /// Satuannya IKUT — persis sheet INPUT DATA yang nulis "1,74 mg/L". Tanpa itu
  /// angka standarnya kebaca telanjang dan gampang ketuker sama pembacaan di
  /// sebelahnya. Diambil PER BARIS lewat `satuanUntuk`: lembar Conductivity
  /// nyampur µS/cm & mS/cm, dan ngambil dari level lembar bikin 111 mS/cm
  /// kelabel µS/cm.
  ///
  /// KECUALI di lembar yang kepala kolomnya udah ditentuin backend
  /// ([TabelHasil.judulNilai]) — di situ satuannya udah kesebut di judul tabel
  /// & kepala kolom, persis kayak lembar cetaknya, jadi nempelin lagi bikin
  /// `0,0 %T` yang nggak ada di kertas mana pun.
  String _labelBaris(BarisTabelHasil baris) {
    final satuan = isian.bentuk.satuanUntuk(baris);
    if (tabel.judulNilai != null || satuan.isEmpty) return baris.label;

    return '${baris.label} $satuan';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ukuran = _ukurKolomLabel(context);

    // Nomor pengulangan dipotong jadi baris-baris sesuai lembar cetaknya —
    // satu potongan buat alat biasa, dua buat blok %T (X1..X3 dua kali).
    final potongan = tabel.pengulanganPerBarisnya;
    final tinggiKepala = _tinggiKepala +
        (tabel.judulPengulangan == null ? 0.0 : _tinggiKepalaGabungan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tabel.judul,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Tombolnya sengaja LEBAR & BERLABEL, bukan ikon kecil di pojok: ini
        // jalan pintas yang paling sering dipakai di lapangan, dan waktu cuma
        // ikon di sebelah judul, teknisi nggak nemu sama sekali.
        SizedBox(
          width: double.infinity,
          child: _TombolFotoTabel(
            tabel: tabel,
            isian: isian,
            onBerubah: onBerubah,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Lembar yang Repeat-nya turun ke bawah (Conductivity,
        // `SIDIK-FM-CAL-0510`) digambar terbalik dari bentuk pH. Dipisah jadi
        // widget sendiri, bukan ditekuk di sini: dua bentuk itu beda kepala,
        // beda kolom nempel, dan yang satu punya kotak ceklis satuan yang
        // nggak ada di bentuk satunya.
        if (tabel.pengulanganKeBawah && tabel.slotCetak.isNotEmpty)
          _TabelKeBawah(tabel: tabel, isian: isian, onBerubah: onBerubah)
        else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kolom kiri yang di kertas KEGABUNG buat seluruh tabel — di blok
            // %T isinya `λ (nm)` = 560. Digambar sebagai satu sel setinggi
            // seluruh baris, persis kayak sel merge di lembar cetaknya.
            if (tabel.kolomTetap != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelKepala(
                    lebar: _lebarKolomTetap,
                    teks: tabel.kolomTetap!.label,
                    tinggi: tinggiKepala,
                  ),
                  _SelKepala(
                    lebar: _lebarKolomTetap,
                    teks: tabel.kolomTetap!.nilai,
                    tinggi: ukuran.tinggi * potongan.length * _baris.length,
                  ),
                ],
              ),

            // Kolom "No." — nomor urut baris seperti di lembar cetak.
            if (tabel.nomorBaris)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelKepala(
                    lebar: _lebarNomor,
                    teks: 'No.',
                    tinggi: tinggiKepala,
                  ),
                  for (var i = 0; i < _baris.length; i++)
                    _SelKepala(
                      lebar: _lebarNomor,
                      teks: '${i + 1}',
                      tinggi: ukuran.tinggi * potongan.length,
                    ),
                ],
              ),

            // Kolom label yang nempel — di luar area gulung.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelKepala(
                  lebar: ukuran.lebar,
                  // Kepala kolom nilai standar ngikut lembar cetaknya
                  // (`Std Value (λ1)`); alat yang backend-nya nggak nyebut
                  // apa-apa tetap dapat "Standard" seperti dulu.
                  teks: tabel.judulNilai ?? 'Standard',
                  tinggi: tinggiKepala,
                ),
                for (final baris in _baris)
                  _SelKepala(
                    lebar: ukuran.lebar,
                    // Satuannya ikut, persis sheet INPUT DATA yang nulis
                    // "1,74 mg/L". Tanpa itu angka standarnya kebaca telanjang
                    // dan gampang ketuker sama pembacaan di sebelahnya.
                    // Satuan diambil PER BARIS lewat `satuanUntuk` — lembar
                    // Conductivity nyampur µS/cm & mS/cm, dan ngambil dari
                    // level lembar bikin 111 mS/cm kelabel µS/cm.
                    teks: _labelBaris(baris),
                    // Keterangan singkat kenapa baris ini mati — tanpa itu
                    // teknisi lihat kotak abu tanpa sebab.
                    catatan: isian.titikTerkunci(baris.titikUkur)
                        ? AppLocalizations.of(context).lkTitikAlternatifSatuan
                        : null,
                    // Setinggi SELURUH potongan barisnya: satu nilai standar
                    // %T menaungi dua baris X1..X3 di kertas.
                    tinggi: ukuran.tinggi * potongan.length,
                    kiri: true,
                  ),
              ],
            ),

            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kepala yang memayungi seluruh kolom angka
                    // (`Measurement Result`). Cuma muncul kalau backend
                    // nyebutin — alat lain nggak berubah tampilannya.
                    if (tabel.judulPengulangan != null)
                      _SelKepala(
                        lebar: _lebarSel * tabel.kolom.length * potongan.first.length,
                        teks: tabel.judulPengulangan!,
                        tinggi: _tinggiKepalaGabungan,
                      ),

                    // Baris kepala: Repeat 1..n (atau X1..X3 buat lembar yang
                    // nyetaknya begitu), tiap satu dibagi jumlah kolomnya.
                    //
                    // Yang digambar potongan PERTAMA doang: di kertas, dua
                    // baris X1..X3 blok %T berbagi satu kepala.
                    Row(
                      children: [
                        for (final r in potongan.first)
                          _KepalaPengulangan(
                            nomor: r,
                            kolom: tabel.kolom,
                            lebarSel: _lebarSel,
                            prefiks: tabel.prefiksPengulangan,
                          ),
                      ],
                    ),

                    for (final baris in _baris)
                      for (final sepotong in potongan)
                      Row(
                        children: [
                          for (final r in sepotong)
                            for (final kolom in tabel.kolom)
                              _SelAngka(
                                lebar: _lebarSel,
                                tinggi: ukuran.tinggi,
                                // Botol yang sama dibaca dua satuan: begitu
                                // pasangannya mulai diisi, baris ini dikunci.
                                // Dikunci, bukan disembunyikan — teknisi perlu
                                // lihat bahwa ini alternatif satuan.
                                // Mati kalau standarnya belum dicentang ATAU pasangan
                                // satuannya udah diisi. Lihat `titikBisaDiisi`.
                                terkunci: !isian.titikBisaDiisi(baris.titikUkur),
                                // Index kotak diambil dari POSISI nomor
                                // pengulangan di daftar aslinya, bukan dari
                                // urutan gambar — baris kedua %T isinya
                                // pengulangan 4-6 dan kotaknya beda dari
                                // baris pertama walau kepalanya sama.
                                controller: isian
                                    .titik[baris.titikUkur]!
                                    .kotak(
                                      tabel.tahap,
                                      kolom.kode,
                                      tabel.pengulangan.indexOf(r),
                                    ),
                                // Sel yang diisi AI dengan keyakinan rendah
                                // ditandai supaya dicek — bukan seluruh tabel.
                                rendah: isian.selRendahKeyakinan.contains(
                                  LembarKerjaState.kunciSel(
                                    baris.titikUkur,
                                    tabel.tahap,
                                    kolom.kode,
                                    tabel.pengulangan.indexOf(r),
                                  ),
                                ),
                              ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Catatan yang tercetak di bawah tabelnya di lembar kerja, mis.
        // `*) Measured at 25°C and with spectral bandwidth 1 nm.` — bagian dari
        // dokumen, bukan tulisan layar, jadi ditampilin apa adanya.
        if (tabel.catatan != null && tabel.catatan!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            tabel.catatan!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // Standar buffer per titik cuma dipilih SEKALI (di tabel pertama) —
        // buffer yang dipakai sama untuk before & after adjustment, cuma
        // suhunya yang beda. Nanyain dua kali cuma bikin peluang salah pilih.
        if (tabel.sebelumAdjustment) ...[
          const SizedBox(height: AppSpacing.md),
          for (final baris in _baris)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PilihStandarTitik(
                label: baris.label,
                state: isian.titik[baris.titikUkur]!,
                onBerubah: onBerubah,
              ),
            ),
        ],
      ],
    );
  }

  static const _tinggiKepala = 44.0;

  /// Baris kepala gabungan (`Measurement Result`) — di atas kepala X1..X3.
  static const _tinggiKepalaGabungan = 26.0;

  /// Kolom "No." cuma nampung dua digit.
  static const _lebarNomor = 40.0;

  /// Kolom kegabung kiri (`λ (nm)` = 560).
  static const _lebarKolomTetap = 64.0;

  /// Lantai tinggi baris — tinggi sebenarnya diukur dari isi di
  /// [_ukurKolomLabel], dan nggak pernah turun di bawah ini.
  static const _tinggiBarisMin = 56.0;
}

/// Tabel hasil buat lembar yang Repeat-nya TURUN KE BAWAH.
///
/// Susunannya ngikut cetakan `SIDIK-FM-CAL-0510_Rev.5`: kepala "Solution
/// Standard" berjajar ke samping, di bawahnya baris `Resolusi:`, lalu kepala
/// satuan per kolom, baru Repeat 1..5 turun ke bawah.
///
/// Stateful karena kotak "ceklis salah satu" di kepala kolom itu PILIHAN, dan
/// pilihan itu nentuin sel di seluruh kolom bawahnya nulis ke titik yang mana
/// (`1412 µS/cm` atau `1,412 mS/cm` — botol yang sama, dua satuan).
class _TabelKeBawah extends StatefulWidget {
  const _TabelKeBawah({
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  final TabelHasil tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  State<_TabelKeBawah> createState() => _TabelKeBawahState();
}

class _TabelKeBawahState extends State<_TabelKeBawah> {
  /// Index slot → index titik yang lagi kepilih di slot itu. Slot yang cuma
  /// punya satu titik nggak pernah masuk sini.
  final Map<int, int> _pilihan = {};

  static const _lebarSel = 78.0;
  static const _lebarRepeat = 72.0;
  static const _tinggiBaris = 56.0;
  static const _tinggiKepalaSlot = 46.0;
  static const _tinggiResolusi = 28.0;
  static const _tinggiKepalaSatuan = 30.0;

  TabelHasil get _tabel => widget.tabel;

  List<KolomTabelHasil> get _kolom => _tabel.kolom;

  double get _lebarSlot => _lebarSel * _kolom.length;

  /// Titik yang aktif buat slot ini.
  ///
  /// Bukan cuma baca [_pilihan]: kalau salah satu varian udah keisi (mis. draft
  /// yang dipulihkan, atau hasil scan), yang keisi itu yang menang — teknisi
  /// nggak boleh lihat kolom kosong padahal angkanya ada di titik sebelah.
  double? _titikAktif(int index, SlotCetak slot) {
    if (slot.mati) return null;
    if (slot.titikUkur.length == 1) return slot.titikUkur.first;

    for (final titik in slot.titikUkur) {
      if (widget.isian.titikTerkunci(titik)) continue;
      if (!widget.isian.titikBisaDiisi(titik)) continue;

      // Yang pasangannya udah kekunci = yang lagi dipakai. Ini menang atas
      // pilihan manual supaya angka yang udah diketik nggak ketutup.
      if (slot.titikUkur.any(widget.isian.titikTerkunci)) return titik;
    }

    final dipilih = _pilihan[index] ?? 0;
    return slot.titikUkur[dipilih.clamp(0, slot.titikUkur.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slot = _tabel.slotCetak;
    final ulang = _tabel.pengulangan;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kolom "Repeat" nempel di kiri, di luar area gulung — sama alasannya
        // kayak kolom label di bentuk pH: tanpa itu teknisi kehilangan nomor
        // pengulangan begitu geser ke slot paling kanan.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SelKepala(
              lebar: _lebarRepeat,
              teks: '',
              tinggi: _tinggiKepalaSlot + _tinggiResolusi,
            ),
            _SelKepala(
              lebar: _lebarRepeat,
              teks: l10n.lkRepeat,
              tinggi: _tinggiKepalaSatuan,
            ),
            for (final r in ulang)
              _SelKepala(
                lebar: _lebarRepeat,
                teks: '$r',
                tinggi: _tinggiBaris,
              ),
          ],
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kepala "Solution Standard": tulisan kertas + kotak ceklis
                // satuan kalau slotnya punya dua varian.
                Row(
                  children: [
                    for (var i = 0; i < slot.length; i++)
                      _KepalaSlot(
                        lebar: _lebarSlot,
                        tinggi: _tinggiKepalaSlot,
                        slot: slot[i],
                        titikAktif: _titikAktif(i, slot[i]),
                        onPilih: slot[i].titikUkur.length < 2
                            ? null
                            : (pilih) => setState(() => _pilihan[i] = pilih),
                      ),
                  ],
                ),

                // Baris `Resolusi: ( )` — di kertas satu baris sendiri per
                // slot. Angkanya dari spesifikasi alat, jadi ditampilin, bukan
                // dikosongin buat diisi tangan.
                Row(
                  children: [
                    for (final s in slot)
                      _SelKepala(
                        lebar: _lebarSlot,
                        tinggi: _tinggiResolusi,
                        teks: s.resolusi == null
                            ? l10n.lkResolusiKosong
                            : l10n.lkResolusiNilai(
                                formatAngka(s.resolusi!),
                                s.satuan ?? '',
                              ),
                      ),
                  ],
                ),

                // Kepala satuan per kolom: `µS` / `°C` di kertas.
                Row(
                  children: [
                    for (final s in slot)
                      for (final k in _kolom)
                        _SelKepala(
                          lebar: _lebarSel,
                          tinggi: _tinggiKepalaSatuan,
                          teks: k.kode == 'suhu'
                              ? (k.satuan ?? '°C')
                              : (s.satuan ?? k.label),
                        ),
                  ],
                ),

                for (final r in ulang)
                  Row(
                    children: [
                      for (var i = 0; i < slot.length; i++)
                        for (final k in _kolom)
                          _selAngka(slot[i], i, k, r),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _selAngka(SlotCetak slot, int index, KolomTabelHasil kolom, int r) {
    final titik = _titikAktif(index, slot);
    final state = titik == null ? null : widget.isian.titik[titik];

    // Slot mati (`80000 µS` — dicentang di master tapi baris DATABASE-nya
    // kosong) tetap DIGAMBAR karena kotaknya ada di kertas, tapi nggak punya
    // controller: nggak ada titik yang bisa nampung angkanya.
    if (state == null) {
      return _SelKosong(lebar: _lebarSel, tinggi: _tinggiBaris);
    }

    final urutan = _tabel.pengulangan.indexOf(r);

    return _SelAngka(
      lebar: _lebarSel,
      tinggi: _tinggiBaris,
      terkunci: !widget.isian.titikBisaDiisi(titik!),
      controller: state.kotak(_tabel.tahap, kolom.kode, urutan),
      rendah: widget.isian.selRendahKeyakinan.contains(
        LembarKerjaState.kunciSel(titik, _tabel.tahap, kolom.kode, urutan),
      ),
    );
  }
}

/// Kepala satu slot: tulisan kertas di atas, kotak ceklis satuan di bawahnya.
class _KepalaSlot extends StatelessWidget {
  const _KepalaSlot({
    required this.lebar,
    required this.tinggi,
    required this.slot,
    required this.titikAktif,
    required this.onPilih,
  });

  final double lebar;
  final double tinggi;
  final SlotCetak slot;
  final double? titikAktif;

  /// Null = slot ini nggak punya pilihan satuan (`84`, atau slot mati).
  final void Function(int)? onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final gaya = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: slot.mati ? theme.colorScheme.onSurfaceVariant : null,
    );

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (onPilih == null)
            Text(slot.label, style: gaya)
          else
            // Kertasnya bilang "ceklis salah satu" — jadi di layar pun ini
            // pilihan, bukan dua kolom terpisah. Yang kepilih nentuin sel di
            // bawahnya nulis ke titik yang mana.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slot.titikUkur.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(
                        i == 0 ? slot.label : (slot.varian ?? slot.label),
                        style: theme.textTheme.labelSmall,
                      ),
                      selected: titikAktif == slot.titikUkur[i],
                      onSelected: (_) => onPilih!(i),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),

          // Larutan yang SEBENARNYA di balik slot ini. Tulisan kertasnya
          // nominal botol lama, jadi tanpa baris ini teknisi bisa menuang
          // botol yang salah — lihat `SlotCetak`.
          Text(
            slot.mati
                ? l10n.lkSlotTanpaLarutan
                : '${formatAngka(slot.titikUkur.first)} ${slot.satuan ?? ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Kotak yang ada di kertas tapi nggak punya titik — digambar, nggak bisa
/// diisi.
class _SelKosong extends StatelessWidget {
  const _SelKosong({required this.lebar, required this.tinggi});

  final double lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        width: lebar - 4,
        height: tinggi - 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class _KepalaPengulangan extends StatelessWidget {
  const _KepalaPengulangan({
    required this.nomor,
    required this.kolom,
    required this.lebarSel,
    this.prefiks,
  });

  final int nomor;
  final List<KolomTabelHasil> kolom;
  final double lebarSel;

  /// Awalan nomor yang TERCETAK di kertas — `X` bikin `X1`, dan waktu ada
  /// awalannya, label satuan per kolom nggak ikut digambar: lembar cetaknya
  /// juga nggak nulis itu di kepala kolom.
  final String? prefiks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: lebarSel * kolom.length,
      height: LembarKerjaTabel._tinggiKepala,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nggak boleh membungkus: tinggi kepala dipatok
          // [LembarKerjaTabel._tinggiKepala] supaya sebaris sama kolom label
          // yang nempel di kiri, dan "Repeat 10" yang jatuh ke baris kedua
          // bikin kepalanya meluber.
          //
          // Kelihatannya baru di tabel BERKOLOM SATU: lebar kepala =
          // `lebarSel × jumlah kolom`, jadi tabel dua kolom (pembacaan + suhu)
          // punya 156px dan nggak pernah kena. Spectrophotometer cuma punya
          // kolom `pembacaan` — 78px, dan teksnya langsung nggak muat.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              prefiks == null ? '${l10n.lkRepeat} $nomor' : '$prefiks$nomor',
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (prefiks == null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                for (final k in kolom)
                  SizedBox(
                    width: lebarSel,
                    child: Text(
                      k.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelKepala extends StatelessWidget {
  const _SelKepala({
    required this.lebar,
    required this.teks,
    required this.tinggi,
    this.kiri = false,
    this.catatan,
  });

  final double lebar;
  final String teks;
  final double tinggi;
  final bool kiri;

  /// Keterangan kecil di bawah label — dipakai buat bilang kenapa baris ini
  /// dikunci (alternatif satuan dari botol yang sama).
  final String? catatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Align(
        alignment: kiri ? Alignment.centerLeft : Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              kiri ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              teks,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: catatan == null
                    ? null
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (catatan != null)
              Text(
                catatan!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _SelAngka extends StatelessWidget {
  const _SelAngka({
    required this.lebar,
    required this.tinggi,
    required this.controller,
    this.rendah = false,
    this.terkunci = false,
  });

  final double lebar;

  /// Dikirim dari luar, bukan konstanta: harus PERSIS setinggi sel label di
  /// kolom nempel sebelah kiri, atau barisnya lari sendiri-sendiri.
  final double tinggi;
  final TextEditingController controller;

  /// Sel ini diisi AI dengan keyakinan rendah — dikasih border kuning biar
  /// teknisi ngecek angkanya. Bukan ngunci apa-apa, cuma pengingat visual.
  final bool rendah;

  /// Baris pasangannya udah mulai diisi, jadi baris ini nggak boleh diisi.
  /// Tetap KELIHATAN — cuma nggak bisa diketik — supaya teknisi paham ini
  /// alternatif satuan dari botol yang sama, bukan titik yang hilang.
  final bool terkunci;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const warna = Color(0xFFB8860B); // amber gelap, kebaca di light & dark

    final borderTanda = rendah
        ? const OutlineInputBorder(
            borderSide: BorderSide(color: warna, width: 1.5),
          )
        : null;

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: TextField(
          controller: controller,
          enabled: !terkunci,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            // Koma diterima juga — formulir kertasnya pakai koma desimal, dan
            // teknisi ngetik sesuai yang dia lihat. Dikonversi waktu parsing.
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*')),
          ],
          decoration: InputDecoration(
            isDense: true,
            filled: rendah || terkunci,
            fillColor: rendah
                ? warna.withValues(alpha: 0.12)
                : (terkunci
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                    : null),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: const OutlineInputBorder(),
            enabledBorder: borderTanda,
            focusedBorder: borderTanda,
          ),
        ),
      ),
    );
  }
}

/// Standar buffer yang dipakai di satu titik. pH butuh standar BEDA per titik
/// (buffer 4/7/10), bukan satu standar buat seluruh sesi.
///
/// Normalnya ini cuma KOTAK CENTANG: pasangan titik↔larutan udah tercetak di
/// formulir (titik 7,00 pakai Buffer 7), jadi backend yang ngirim pasangannya
/// dan teknisi tinggal mastiin larutan itu yang beneran dia pakai.
///
/// Dulu tiap titik satu dropdown berisi SELURUH master standar. Dua ongkosnya:
/// tiga dropdown yang mesti dibuka buat jawaban yang udah ketentu, dan — yang
/// mahal — salah pilih nggak kelihatan salah. Sesi pH 7 Agt 2026 kepilih
/// Buffer 4 di titik 7,00, dan itu baru ketahuan di sertifikat pelanggan
/// sebagai Correction `-2,99` (= 4,0092 − 7,00) di antara dua angka wajar.
///
/// Dropdownnya nggak dibuang, cuma nggak lagi jadi jalur utama: dipanggil
/// lewat "Ganti", atau otomatis kalau titik ini nggak punya pasangan (standar
/// belum kedaftar di master). Teknisi yang kepaksa pakai lot lain tetap bisa
/// nyatet — bedanya sekarang itu keputusan sadar, bukan bawaan yang gampang
/// meleset.
class _PilihStandarTitik extends ConsumerStatefulWidget {
  const _PilihStandarTitik({
    required this.label,
    required this.state,
    required this.onBerubah,
  });

  final String label;
  final TitikState state;
  final VoidCallback onBerubah;

  @override
  ConsumerState<_PilihStandarTitik> createState() => _PilihStandarTitikState();
}

class _PilihStandarTitikState extends ConsumerState<_PilihStandarTitik> {
  /// Teknisi minta milih sendiri buat titik ini. Sekali dibuka tetap kebuka —
  /// nutup sendiri begitu dia milih cuma bikin pilihannya kelihatan hilang.
  bool _manual = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;

    if (!_manual && state.standardIdTercetak != null) {
      return _Centang(
        judul: l10n.lkStandarTitikDipakai(widget.label, state.standardNama!),
        subjudul: l10n.lkStandarTitikTercetak,
        nilai: state.standarTercetakDipakai,
        onUbah: (dicentang) {
          setState(() {
            state.standardId = dicentang ? state.standardIdTercetak : null;
          });
          widget.onBerubah();
        },
        labelGanti: l10n.lkStandarTitikGanti,
        onGanti: () => setState(() => _manual = true),
      );
    }

    return _Dropdown(
      label: widget.label,
      state: state,
      onBerubah: widget.onBerubah,
    );
  }
}

/// Baris centang "titik ini pakai larutan X", plus jalan keluar ke pilihan
/// manual.
class _Centang extends StatelessWidget {
  const _Centang({
    required this.judul,
    required this.subjudul,
    required this.nilai,
    required this.onUbah,
    required this.labelGanti,
    required this.onGanti,
  });

  final String judul;
  final String subjudul;
  final bool nilai;
  final ValueChanged<bool> onUbah;
  final String labelGanti;
  final VoidCallback onGanti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: nilai,
      onChanged: (v) => onUbah(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(judul, style: theme.textTheme.bodyMedium),
      subtitle: Text(subjudul, style: theme.textTheme.bodySmall),
      secondary: TextButton(onPressed: onGanti, child: Text(labelGanti)),
    );
  }
}

/// Pilihan manual dari master standar — jalur cadangan, bukan jalur utama.
class _Dropdown extends ConsumerWidget {
  const _Dropdown({
    required this.label,
    required this.state,
    required this.onBerubah,
  });

  final String label;
  final TitikState state;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final standarAsync = ref.watch(standardListProvider);

    return standarAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      // Sama kayak `_PilihStandar`, tapi taruhannya lebih besar: ini standar
      // PER TITIK (buffer 4/7/10). Ilang diam-diam artinya tiga baris
      // ketertelusuran hilang sekaligus, dan yang kelihatan di layar cuma
      // ruang kosong di bawah tabel.
      error: (_, _) => DropdownGagal(
        label: '${l10n.lkStandarPerTitik} $label',
        pesan: l10n.standarLoadFailed,
        onCobaLagi: () => ref.invalidate(standardListProvider),
      ),
      data: (list) {
        // Standar yang punya kurva suhu ditaruh duluan: itu yang bikin nilai
        // Standard-nya ngikutin suhu larutan, bukan mentok di nilai nominal.
        final urut = [...list]
          ..sort((a, b) {
            if (a.punyaKurvaSuhu == b.punyaKurvaSuhu) return 0;
            return a.punyaKurvaSuhu ? -1 : 1;
          });

        return DropdownButtonFormField<int>(
          initialValue: state.standardId,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: '${l10n.lkStandarPerTitik} $label',
            border: const OutlineInputBorder(),
          ),
          hint: Text(l10n.lkPilih),
          items: [
            for (final Standard s in urut)
              DropdownMenuItem(
                value: s.id,
                enabled: s.masihBerlaku,
                child: Text(
                  s.masihBerlaku
                      ? s.nama
                      : '${s.nama} (${l10n.lkStandarKadaluarsa})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            state.standardId = value;
            onBerubah();
          },
        );
      },
    );
  }
}

/// Foto SATU tabel → angkanya masuk ke tabel itu.
///
/// ## Kenapa per tabel, bukan selembar
///
/// Ada dua jalur foto di aplikasi ini, dan bedanya bukan selera:
///
///  - **Pindai lembar kerja** (tombol di atas tabel) butuh lembar yang dicetak
///    dari `ocr:cetak-lembar` — bermarker sudut + QR. Angkanya dipotong dari
///    koordinat yang eksak, divonis server, dan lewat layar review. Paling
///    aman, tapi cuma jalan buat kertas yang kita cetak sendiri.
///  - **Foto tabel ini** (tombol ini) jalan di tabel APA ADANYA, termasuk
///    formulir lama yang nggak bermarker. Yang mengunci posisinya bukan
///    koordinat, tapi tinta yang tercetak di tabelnya sendiri: nilai standar
///    di kolom kiri buat baris, `X1`..`Xn` di kepala buat kolom.
///
/// Dua-duanya nolak menebak dari urutan. Yang ini menolak lebih keras: sel
/// yang nggak punya jangkar baris DAN kolom nggak pernah keisi — dan berapa
/// yang kebuang dilaporkan, supaya teknisi tau ada yang nggak keangkut.
///
/// **Semua yang keisi ditandai perlu dicek.** Tanpa server, nggak ada yang
/// mengadu angkanya ke rentang titik maupun resolusi alat; yang tersisa cuma
/// mata teknisi.
class _TombolFotoTabel extends ConsumerStatefulWidget {
  const _TombolFotoTabel({
    required this.tabel,
    required this.isian,
    required this.onBerubah,
  });

  final TabelHasil tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  @override
  ConsumerState<_TombolFotoTabel> createState() => _TombolFotoTabelState();
}

class _TombolFotoTabelState extends ConsumerState<_TombolFotoTabel> {
  bool _sibuk = false;

  Future<void> _foto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);

    try {
      // Resolusinya dipertahankan: yang dibaca ML Kit angka setinggi beberapa
      // puluh piksel, dan tiap piksel yang dibuang di sini hilang dari angka
      // yang kebaca. Yang dibatasi UKURANNYA, bukan mutunya — artefak JPEG di
      // garis tipis itu yang bikin `4,04` kebaca `404`.
      final foto = await ref
          .read(sumberFotoProvider)
          .ambil(maxWidth: 4200, imageQuality: 100);

      if (foto == null || !mounted) return;

      final citra = img.decodeImage(await foto.readAsBytes());

      if (citra == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkFotoTabelGagal)));

        return;
      }

      final pembaca = ref.read(pabrikPembacaPindaiProvider).halaman();

      final HasilPetaTabel hasil;

      try {
        // Titik TABEL INI, bukan seluruh lembar. Spectrophotometer punya tiga
        // tabel dengan titik beda-beda (10 nm + 9 nm + 5 %T); ngasih seluruh
        // titik bikin nilai `20,0 %T` bisa nyamar jadi jangkar baris nm.
        final titik = widget.isian.titikTabel(widget.tabel);

        hasil = const PetaTabelFoto().petakan(
          terbaca: await pembaca.baca(citra),
          titikUkur: [for (final t in titik) t.titikUkur],
          pengulangan: widget.tabel.pengulangan,
          fieldPerRepeat: [for (final k in widget.tabel.kolom) k.kode],
          labelField: {
            for (final k in widget.tabel.kolom) k.kode: k.label,
          },
        );
      } finally {
        await pembaca.tutup();
      }

      if (!mounted) return;

      if (hasil.kosong) {
        // Nol sel bukan "OCR-nya jelek" — biasanya yang kefoto bukan tabelnya,
        // atau kolom nilai standarnya nggak ikut masuk frame. Pesannya nyebut
        // itu, karena mengulang jepretan yang sama nggak akan menolong.
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(l10n.lkFotoTabelTanpaJangkar),
          ),
        );

        return;
      }

      final terisi = widget.isian.terapkanHasilFotoTabel(
        hasil.sel,
        tahap: widget.tabel.tahap,
      );

      widget.onBerubah();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            hasil.angkaTakTerpetakan == 0
                ? l10n.lkFotoTabelTerisi(terisi)
                : l10n.lkFotoTabelSebagian(terisi, hasil.angkaTakTerpetakan),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.lkFotoTabelError('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OutlinedButton.icon(
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
