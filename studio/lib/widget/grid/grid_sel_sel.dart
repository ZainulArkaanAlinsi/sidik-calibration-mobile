part of 'grid_sel.dart';

// ═══════════════════════════════════════════════════════════════ ukur teks

/// Gaya teks sel yang memengaruhi ukuran (warna tidak).
typedef _KunciGaya = ({double ukuran, bool tebal, bool miring, bool mono});

/// Pengukur teks bersama satu grid — lebar per (teks, gaya) di-cache supaya
/// sel yang dibangun ulang (seleksi, data tiba) tidak mengukur lagi.
class _PengukurTeks {
  final _lebar = <(String, _KunciGaya), double>{};
  final _tinggiBaris = <_KunciGaya, double>{};
  final _p = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  );

  /// `inherit: false`: teks sel TIDAK mewarisi `DefaultTextStyle` tema
  /// (letterSpacing, height). Teks sendiri (widget `Text`), pengukuran, dan
  /// potongan luberan di sel tetangga (`TextPainter`) harus berukuran
  /// identik — selisih sepersekian dp saja membuat sambungan luberan patah.
  static TextStyle gaya(_KunciGaya k, [Color? warna]) => TextStyle(
    inherit: false,
    fontFamily: k.mono ? FontStudio.mono : FontStudio.inter,
    fontFamilyFallback: k.mono ? const ['monospace'] : null,
    fontSize: k.ukuran,
    fontWeight: k.tebal ? FontWeight.w700 : FontWeight.w400,
    fontStyle: k.miring ? FontStyle.italic : FontStyle.normal,
    color: warna,
    // Digit selebar sama (Calibri pun begitu): kolom angka lurus.
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  double lebar(String teks, _KunciGaya k) {
    if (_lebar.length > 20000) _lebar.clear();
    return _lebar.putIfAbsent((teks, k), () {
      _p
        ..text = TextSpan(text: teks, style: gaya(k))
        ..layout();
      return _p.width;
    });
  }

  double tinggiBaris(_KunciGaya k) => _tinggiBaris.putIfAbsent(k, () {
    _p
      ..text = TextSpan(text: 'Hg', style: gaya(k))
      ..layout();
    return _p.height;
  });

  double tinggiBungkus(
    String teks,
    _KunciGaya k,
    double lebar,
    TextAlign rata,
  ) {
    _p
      ..text = TextSpan(text: teks, style: gaya(k))
      ..textAlign = rata
      ..layout(maxWidth: math.max(1, lebar));
    final t = _p.height;
    _p.textAlign = TextAlign.start;
    return t;
  }

  void dispose() => _p.dispose();
}

// ═══════════════════════════════════════════════════════════════ konteks

/// Yang ditampilkan satu sel: teks, perataan, dan aturan luberannya.
typedef _Tampil = ({
  String teks,
  TextAlign rata,
  bool angka,
  bool luber,
  bool bungkus,
  RataVertikal vertikal,
  _KunciGaya gaya,
});

/// Tampilan `####` pengganti angka yang tak muat: rata kiri, tak meluber.
_Tampil _pagar(_Tampil t) => (
  teks: t.teks,
  rata: TextAlign.left,
  angka: true,
  luber: false,
  bungkus: false,
  vertikal: t.vertikal,
  gaya: t.gaya,
);

const _sisiAtas = 1;
const _sisiKanan = 2;
const _sisiBawah = 4;
const _sisiKiri = 8;

class _KonteksGrid {
  _KonteksGrid({
    required this.kendali,
    required this.selTonton,
    required this.geo,
    required this.warna,
    required this.dpr,
    required this.ukur,
    required this.onKetuk,
    required this.onTekanLama,
    required this.onPilihKolom,
    required this.onPilihBaris,
    required this.onPilihSemua,
    required this.onSinyal,
    required this.fokusEdit,
    required this.onSimpanEdit,
  }) : pad = math.max(1.0, (2 * geo.zoom).roundToDouble()),
       padAtas = math.max(1.0, geo.zoom.roundToDouble()),
       padBawah = math.max(1.0, (2 * geo.zoom).roundToDouble()),
       piksel = 1 / dpr,
       batasLuber = 2400 * geo.zoom,
       garisKisi = geo.tataLetak.garisKisi,
       warnaKisi = warna.garis,
       // Garis tepi "otomatis" Excel = hitam. Di tema gelap kertasnya gelap,
       // jadi garisnya terang.
       warnaTepi = warna.terang ? const Color(0xFF000000) : warna.teks2,
       warnaBeku = warna.garisKuat,
       tintaSeleksi = warna.aksen.withValues(alpha: warna.terang ? 0.16 : 0.24),
       gayaKepala = TextStyle(
         fontFamily: FontStudio.inter,
         fontSize: math.max(8, 11 * geo.zoom),
         height: 1.2,
         fontWeight: FontWeight.w400,
         color: warna.teks2,
         fontFeatures: const [FontFeature.tabularFigures()],
       );

  final KendaliGridSel kendali;
  final PenontonSelGrid selTonton;
  final _Geometri geo;
  final WarnaStudio warna;
  final double dpr;
  final _PengukurTeks ukur;
  final ValueChanged<AlamatSel> onKetuk;
  final ValueChanged<AlamatSel>? onTekanLama;
  final ValueChanged<int> onPilihKolom;
  final ValueChanged<int> onPilihBaris;
  final VoidCallback onPilihSemua;
  final ValueChanged<PointerSignalEvent> onSinyal;

  /// Fokus editor sel ([kunciEditorSel]).
  final FocusNode fokusEdit;

  /// Simpan edit & pindah — Enter keyboard lunak (aksi "selesai").
  final bool Function(int arahBaris, int arahKolom) onSimpanEdit;

  /// Jarak teks dari tepi kiri/kanan sel (Excel: 2 px pada 100 %).
  final double pad;
  final double padAtas;
  final double padBawah;

  /// Satu piksel layar (garis kisi & garis "hair" Excel).
  final double piksel;

  /// Teks yang meluber lebih jauh dari ini tidak dicari tetangganya.
  final double batasLuber;
  final bool garisKisi;
  final Color warnaKisi;
  final Color warnaTepi;
  final Color warnaBeku;
  final Color tintaSeleksi;
  final TextStyle gayaKepala;

  final _cacheTeks = <(Color, Color), Color>{};

  /// Sel di dalam rentang terpakai dari sumbernya; di luarnya = kosong tanpa
  /// bertanya ke sumber.
  SelGrid? tonton(WidgetRef ref, int baris, int kolom) {
    if (baris < 1 || kolom < 1) return SelGrid.kosong;
    if (geo.diLuarData(baris, kolom)) return SelGrid.kosong;
    return selTonton(ref, baris, kolom);
  }

  /// Tetangga SEBARIS sel yang sedang dibangun. Sengaja lewat [tonton]
  /// (`ref.watch`), BUKAN `ref.read`: di Riverpod 3 tiap `read` membuat &
  /// menutup langganan sementara (diukur ±0,9 ms/sel di test debug),
  /// sedangkan `watch` ke provider yang sudah ditonton sel ini (halaman
  /// barisnya sendiri) cuma pencarian map.
  SelGrid? sebaris(WidgetRef ref, int baris, int kolom) =>
      tonton(ref, baris, kolom);

  /// Isi sel dari sumbernya. Di tema gelap warna kertas putih Excel
  /// (kuning muda, hijau muda) jadi panel menyala — diredupkan ke 30 % di
  /// atas permukaan, rona tetap terbaca.
  Color latarIsi(Color isi) => warna.terang
      ? isi
      : Color.alphaBlend(isi.withValues(alpha: 0.30), warna.permukaan);

  /// Warna teks yang tetap ≥ 4,5:1 terhadap [latar]. Warna sumber dipakai
  /// bila aman; kalau tidak, digeser ke hitam/putih secukupnya (rona merah
  /// tetap kemerahan, bukan hilang).
  Color teksAman(Color? diminta, Color latar) {
    final kandidat = diminta ?? warna.teks;
    return _cacheTeks.putIfAbsent((
      kandidat,
      latar,
    ), () => warnaTeksAman(kandidat, latar));
  }

  final _cacheGeneral = <(double, double, MetrikGeneral), String>{};

  /// Teks General [s] di sel/gabungan selebar [lebarIsi] (sudah dikali
  /// zoom). Anggarannya dihitung pada zoom 100 % — seperti `Range.Text`
  /// Excel — jadi teksnya tidak berubah saat diperbesar/diperkecil. Metrik =
  /// Calibri seukuran font sel, bukan Inter yang menggambarnya: yang ditiru
  /// adalah PILIHAN teks Excel.
  String general(SelGrid s, double lebarIsi) {
    final n = s.nilai!.toDouble();
    final ruang = ruangTeksGeneral(lebarIsi / geo.zoom);
    final m = MetrikGeneral.calibri(s.ukuran, tebal: s.tebal);
    if (_cacheGeneral.length > 20000) _cacheGeneral.clear();
    return _cacheGeneral.putIfAbsent((
      n,
      ruang,
      m,
    ), () => teksGeneral(n, ruang, metrik: m));
  }

  static TextAlign rataBawaan(JenisSelGrid j) => switch (j) {
    JenisSelGrid.angka => TextAlign.right,
    JenisSelGrid.logika || JenisSelGrid.galat => TextAlign.center,
    JenisSelGrid.teks || JenisSelGrid.kosong => TextAlign.left,
  };

  /// Yang ditampilkan [s]; `null` = tidak ada teks.
  _Tampil? tampilan(SelGrid s, bool modeRumus) {
    if (s.gagalMuat) return null;
    final pakaiRumus = modeRumus && s.rumus != null;
    final mentah = pakaiRumus ? s.rumus! : s.teks;
    if (mentah.isEmpty) return null;
    final angka = !pakaiRumus && s.jenis == JenisSelGrid.angka;
    final bungkus = s.bungkus && !angka;
    return (
      teks: bungkus ? mentah : teksSatuBaris(mentah),
      // Mode rumus: rumus tampil sebagai teks rata kiri, kecuali sel itu
      // diratakan eksplisit.
      rata: s.rata ?? (pakaiRumus ? TextAlign.left : rataBawaan(s.jenis)),
      angka: angka,
      luber: !bungkus && (pakaiRumus || s.jenis == JenisSelGrid.teks),
      bungkus: bungkus,
      vertikal: s.vertikal ?? RataVertikal.bawah,
      gaya: (
        ukuran: ukuranFontExcelKeDp(s.ukuran ?? ukuranFontBawaanPt) * geo.zoom,
        tebal: s.tebal,
        miring: s.miring,
        mono: pakaiRumus || fontMonospace(s.font),
      ),
    );
  }

  /// Kolom-kolom yang TIDAK kosong (berisi atau penghalang) per baris, urut
  /// naik — memo selama geometri ini hidup. Hanya baris yang seluruh selnya
  /// sudah termuat & tak ada yang gagal yang dimemo; baris lain dipindai
  /// langsung tiap kali (dan dimemo begitu lengkap).
  final _isiBaris = <int, ({List<int> kolom, List<bool> berisi})>{};

  ({List<int> kolom, List<bool> berisi})? _memoBaris(WidgetRef ref, int b) {
    final ada = _isiBaris[b];
    if (ada != null) return ada;
    final kolom = <int>[];
    final berisi = <bool>[];
    final batasData = math.min(geo.kolomData, geo.jumlahKolom);
    for (var k = 1; k <= batasData; k++) {
      final s = sebaris(ref, b, k);
      if (s == null || s.gagalMuat) return null;
      if (geo.digabung(b, k)) {
        kolom.add(k);
        berisi.add(false);
      } else if (!s.tanpaIsi) {
        kolom.add(k);
        berisi.add(true);
      }
    }
    // Sel gabungan di luar rentang data (jarang) tetap penghalang.
    for (var k = batasData + 1; k <= geo.jumlahKolom; k++) {
      if (geo.digabung(b, k)) {
        kolom.add(k);
        berisi.add(false);
      }
    }
    return _isiBaris[b] = (kolom: kolom, berisi: berisi);
  }

  /// Sumber teks yang mungkin meluber ke sel kosong ([baris], [kolom]) dari
  /// arah [arah] — sama dengan [cariSumberLuber], tapi lewat memo baris.
  int? sumberLuber(WidgetRef ref, int baris, int kolom, int arah) {
    final memo = baris <= geo.barisData ? _memoBaris(ref, baris) : null;
    if (memo == null) {
      return cariSumberLuber(
        kolom: kolom,
        arah: arah,
        kolomTerakhir: geo.jumlahKolom,
        keadaan: (x) => keadaanLuber(ref, baris, x),
        lebarKolom: geo.lebar,
        batas: batasLuber,
      );
    }
    // Pencarian biner kolom tidak-kosong terdekat ke arah [arah].
    final daftar = memo.kolom;
    var lo = 0;
    var hi = daftar.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (daftar[m] < kolom) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    // lo = indeks kolom pertama ≥ [kolom].
    final i = arah < 0
        ? lo - 1
        : (lo < daftar.length && daftar[lo] == kolom ? lo + 1 : lo);
    if (i < 0 || i >= daftar.length) return null;
    if (!memo.berisi[i]) return null;
    final s = daftar[i];
    final jarak = arah < 0
        ? geo.lebarRentang(s + 1, kolom - 1)
        : geo.lebarRentang(kolom + 1, s - 1);
    return jarak > batasLuber ? null : s;
  }

  /// Bagi luberan teks: boleh dilintasi, berisi, atau penghalang.
  KeadaanLuber keadaanLuber(WidgetRef ref, int baris, int kolom) {
    if (geo.digabung(baris, kolom)) return KeadaanLuber.penghalang;
    final s = sebaris(ref, baris, kolom);
    if (s == null || s.gagalMuat) return KeadaanLuber.penghalang;
    return s.tanpaIsi ? KeadaanLuber.kosong : KeadaanLuber.berisi;
  }

  /// Letak teks (satu baris) sel [kolom] di baris [baris].
  LetakTeks letak(
    WidgetRef ref,
    int baris,
    int kolom,
    _Tampil t,
    double lebarTeks, {
    double? lebarSel,
    bool meluber = true,
  }) => letakTeks(
    kolom: kolom,
    lebarSel: lebarSel ?? geo.lebar(kolom),
    lebarTeks: lebarTeks,
    rata: t.rata,
    padding: pad,
    lebarKolom: geo.lebar,
    bolehDilintasi: (k) => keadaanLuber(ref, baris, k) == KeadaanLuber.kosong,
    kolomTerakhir: geo.jumlahKolom,
    meluber: meluber && t.luber,
  );

  double posisiY(RataVertikal v, double tinggiSel, double tinggiTeks) =>
      switch (v) {
        RataVertikal.atas => padAtas,
        RataVertikal.tengah => (tinggiSel - tinggiTeks) / 2,
        RataVertikal.bawah => tinggiSel - padBawah - tinggiTeks,
      };
}

// ═══════════════════════════════════════════════════════════════ sel

/// Seleksi satu sel/gabungan menurut [KendaliGridSel] — dibandingkan supaya
/// sel cuma membangun ulang dirinya bila keadaannya SENDIRI berubah.
/// [tepi] = sisi bagian ini yang menjadi tepi rentang terpilih (bit
/// `_sisi*`), tempat garis tebal seleksi digambar.
/// [edit] = sel ini sedang diedit DI SEL (editor menggantikan isinya).
typedef _KeadaanSel = ({
  bool aktif,
  bool terpilih,
  bool rumus,
  int tepi,
  bool edit,
});

/// Potongan teks tetangga yang meluber ke sel ini.
typedef _Irisan = ({TextPainter pelukis, Offset posisi});

/// Satu segmen garis tepi: [sisi] (bit `_sisi*`), sepanjang [mulai]..[akhir]
/// pada sumbu sisi itu (y untuk kiri/kanan, x untuk atas/bawah).
typedef _Segmen = ({int sisi, double mulai, double akhir, JenisGaris jenis});

class _SelWidget extends ConsumerStatefulWidget {
  const _SelWidget({
    super.key,
    required this.baris,
    required this.kolom,
    required this.bagian,
    required this.konteks,
    this.gabungan,
  });

  /// Sel jangkar (kiri-atas gabungan).
  final int baris;
  final int kolom;

  /// Rentang yang digambar widget ini: satu sel, gabungan utuh, atau bagian
  /// gabungan yang dipecah di batas freeze.
  final RentangSel bagian;
  final _KonteksGrid konteks;

  /// Gabungan utuh, `null` bila bukan sel gabungan.
  final RentangSel? gabungan;

  @override
  ConsumerState<_SelWidget> createState() => _SelWidgetState();
}

class _SelWidgetState extends ConsumerState<_SelWidget> {
  late _KeadaanSel _keadaan;
  KendaliGridSel? _kendali;
  List<TextPainter> _pelukis = const [];

  _KeadaanSel _hitung() {
    final k = widget.konteks.kendali;
    final p = widget.bagian;
    final g = widget.gabungan ?? p;
    final r = k.rentang;
    final aktif =
        k.aktif.baris == widget.baris && k.aktif.kolom == widget.kolom;
    final terpilih = r.beririsan(g);
    var tepi = 0;
    if (terpilih) {
      if (p.barisAwal <= r.barisAwal) tepi |= _sisiAtas;
      if (p.kolomAkhir >= r.kolomAkhir) tepi |= _sisiKanan;
      if (p.barisAkhir >= r.barisAkhir) tepi |= _sisiBawah;
      if (p.kolomAwal <= r.kolomAwal) tepi |= _sisiKiri;
    }
    return (
      aktif: aktif,
      terpilih: terpilih,
      rumus: k.tampilkanRumus,
      tepi: tepi,
      // Gabungan yang dipecah di batas beku: editor HANYA di potongan yang
      // memuat sel jangkar (satu kolom isian, satu fokus).
      edit:
          k.tempatEdit == TempatEdit.sel &&
          k.selEdit?.baris == widget.baris &&
          k.selEdit?.kolom == widget.kolom &&
          p.memuat(widget.baris, widget.kolom),
    );
  }

  void _dengar() {
    final baru = _hitung();
    if (baru != _keadaan) setState(() => _keadaan = baru);
  }

  @override
  void initState() {
    super.initState();
    _kendali = widget.konteks.kendali..addListener(_dengar);
    _keadaan = _hitung();
  }

  @override
  void didUpdateWidget(covariant _SelWidget lama) {
    super.didUpdateWidget(lama);
    if (!identical(_kendali, widget.konteks.kendali)) {
      _kendali?.removeListener(_dengar);
      _kendali = widget.konteks.kendali..addListener(_dengar);
    }
    _keadaan = _hitung();
  }

  @override
  void dispose() {
    _kendali?.removeListener(_dengar);
    for (final p in _pelukis) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.konteks;
    final geo = k.geo;
    final w = k.warna;
    final b = widget.baris;
    final c = widget.kolom;
    final bagian = widget.bagian;
    final penuh = widget.gabungan;
    final kotak = penuh ?? bagian;

    // Ukuran yang digambar widget ini & kotak isinya (gabungan utuh, bisa
    // lebih besar dan digeser bila gabungannya dipecah di batas freeze).
    final lebarBagian = geo.lebarRentang(bagian.kolomAwal, bagian.kolomAkhir);
    final tinggiBagian = geo.tinggiRentang(bagian.barisAwal, bagian.barisAkhir);
    final geser = Offset(
      geo.lebarRentang(kotak.kolomAwal, bagian.kolomAwal - 1),
      geo.tinggiRentang(kotak.barisAwal, bagian.barisAwal - 1),
    );
    final lebarIsi = geo.lebarRentang(kotak.kolomAwal, kotak.kolomAkhir);
    final tinggiIsi = geo.tinggiRentang(kotak.barisAwal, kotak.barisAkhir);

    final sel = k.tonton(ref, b, c);
    final modeRumus = _keadaan.rumus;

    // ── latar: isi sumber (menutup kisi) + tinta seleksi
    Color? isi;
    if (sel != null && sel.isi != null) isi = k.latarIsi(sel.isi!);
    if (sel != null && sel.gagalMuat) isi = w.gagalTipis;
    final latarNyata = isi ?? w.permukaan;
    Color? latar = isi;
    if (_keadaan.terpilih && !_keadaan.aktif) {
      latar = latar == null
          ? k.tintaSeleksi
          : Color.alphaBlend(k.tintaSeleksi, latar);
    }

    // ── isi sendiri
    final t = sel == null ? null : k.tampilan(sel, modeRumus);
    Widget? anak;
    var klip = false;
    var lintasKanan = false;
    if (_keadaan.edit) {
      // Editor menutup seluruh kotak isi (gabungan utuh), seperti Excel.
      klip = true;
      anak = Positioned(
        left: -geser.dx,
        top: -geser.dy,
        width: lebarIsi,
        height: tinggiIsi,
        child: _EditorSel(
          konteks: k,
          latar: latarNyata,
          gaya: _PengukurTeks.gaya((
            ukuran:
                ukuranFontExcelKeDp(sel?.ukuran ?? ukuranFontBawaanPt) *
                geo.zoom,
            tebal: sel?.tebal ?? false,
            miring: sel?.miring ?? false,
            mono: fontMonospace(sel?.font),
          ), w.teks),
        ),
      );
    } else if (t != null) {
      final gaya = _PengukurTeks.gaya(
        t.gaya,
        k.teksAman(sel!.warnaTeks, latarNyata),
      );
      if (t.bungkus) {
        final dalam = math.max(0.0, lebarIsi - 2 * k.pad);
        final tinggiTeks = k.ukur.tinggiBungkus(t.teks, t.gaya, dalam, t.rata);
        final x = k.pad - geser.dx;
        final y = k.posisiY(t.vertikal, tinggiIsi, tinggiTeks) - geser.dy;
        klip =
            x < 0 ||
            y < 0 ||
            x + dalam > lebarBagian ||
            y + tinggiTeks > tinggiBagian;
        anak = Positioned(
          left: x,
          top: y,
          width: dalam,
          child: Text(
            t.teks,
            style: gaya,
            textAlign: t.rata,
            softWrap: true,
            textScaler: TextScaler.noScaling,
          ),
        );
      } else {
        var teks = t.teks;
        var tampil = t;
        final dalam = lebarIsi - 2 * k.pad;
        final general = t.angka && sel.general && sel.nilai != null;
        if (general) {
          // Format General: teks dibangun dari NILAI untuk lebar ini, seperti
          // Excel — termasuk `#` bila tak muat ([teksGeneral]).
          teks = k.general(sel, lebarIsi);
          if (teks.startsWith('#')) tampil = _pagar(t);
        }
        var lebarTeks = k.ukur.lebar(teks, t.gaya);
        if (!general && t.angka && lebarTeks > dalam) {
          // Angka tidak meluber: Excel mengisi selnya dengan `#`.
          teks = teksPagar(dalam, k.ukur.lebar('#', t.gaya));
          lebarTeks = k.ukur.lebar(teks, t.gaya);
          tampil = _pagar(t);
        }
        final letak = k.letak(
          ref,
          b,
          c,
          tampil,
          lebarTeks,
          lebarSel: lebarIsi,
          meluber: penuh == null,
        );
        lintasKanan = letak.kolomAkhir > c;
        final tinggiTeks = k.ukur.tinggiBaris(t.gaya);
        final x = letak.kiri - geser.dx;
        final y = k.posisiY(t.vertikal, tinggiIsi, tinggiTeks) - geser.dy;
        klip =
            x < 0 ||
            y < 0 ||
            x + lebarTeks > lebarBagian ||
            y + tinggiTeks > tinggiBagian;
        anak = Positioned(
          left: x,
          top: y,
          width: lebarTeks + 1,
          child: Text(
            teks,
            style: gaya,
            // Kotaknya sudah diletakkan persis ([letak]); rata di dalamnya
            // akan menggeser teks sampai 1 dp.
            textAlign: TextAlign.left,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.visible,
            // Geometri sel = piksel Excel; teks yang ikut diskalakan akan
            // terpotong di tinggi baris yang tetap.
            textScaler: TextScaler.noScaling,
          ),
        );
      }
    }

    // ── teks tetangga yang meluber ke sel kosong ini
    final irisan = <_Irisan>[];
    for (final p in _pelukis) {
      p.dispose();
    }
    _pelukis = const [];
    final kosong =
        !_keadaan.edit &&
        penuh == null &&
        sel != null &&
        !sel.gagalMuat &&
        sel.tanpaIsi &&
        b <= geo.barisData;
    if (kosong) {
      final tinggiSel = geo.tinggi(b);
      void ambil(int arah) {
        final s = k.sumberLuber(ref, b, c, arah);
        if (s == null) return;
        final sumber = k.sebaris(ref, b, s);
        if (sumber == null) return;
        final ts = k.tampilan(sumber, modeRumus);
        if (ts == null || !ts.luber) return;
        final kanan = ts.rata == TextAlign.right || ts.rata == TextAlign.end;
        // Dari kiri: cuma teks rata kiri/tengah yang meluber ke kanan.
        if (arah < 0 && kanan) return;
        // Dari kanan: cuma rata kanan/tengah yang meluber ke kiri.
        if (arah > 0 && !kanan && ts.rata != TextAlign.center) return;
        final lebarTeks = k.ukur.lebar(ts.teks, ts.gaya);
        final l = k.letak(ref, b, s, ts, lebarTeks);
        if (c < l.kolomAwal || c > l.kolomAkhir) return;
        if (c < l.kolomAkhir) lintasKanan = true;
        final pelukis = TextPainter(
          text: TextSpan(
            text: ts.teks,
            style: _PengukurTeks.gaya(
              ts.gaya,
              k.teksAman(sumber.warnaTeks, latarNyata),
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        _pelukis = [..._pelukis, pelukis];
        irisan.add((
          pelukis: pelukis,
          posisi: Offset(
            l.kiri + geo.xKolom(s) - geo.xKolom(c),
            k.posisiY(ts.vertikal, tinggiSel, k.ukur.tinggiBaris(ts.gaya)),
          ),
        ));
      }

      ambil(-1);
      ambil(1);
    }

    // ── garis kisi: kanan & bawah milik sel ini; hilang di bawah isi warna
    // (sel ini atau tetangganya) dan di bawah teks yang melintas.
    final kolomKanan = bagian.kolomAkhir + 1;
    final barisBawah = bagian.barisAkhir + 1;
    final selKanan = kolomKanan <= geo.jumlahKolom
        ? k.sebaris(ref, b, kolomKanan)
        : null;
    final selBawah = barisBawah <= geo.jumlahBaris
        ? k.tonton(ref, barisBawah, c)
        : null;
    final kisiKanan =
        k.garisKisi &&
        isi == null &&
        selKanan?.isi == null &&
        !lintasKanan &&
        (penuh == null || bagian.kolomAkhir == penuh.kolomAkhir);
    final kisiBawah =
        k.garisKisi &&
        isi == null &&
        selBawah?.isi == null &&
        (penuh == null || bagian.barisAkhir == penuh.barisAkhir);

    // ── garis tepi Excel, dibagi dengan tetangga (yang lebih tebal menang)
    final segmen = <_Segmen>[];
    if (penuh == null) {
      final g = sel?.garis ?? GarisSel.tanpa;
      final kanan = JenisGaris.terberat(
        g.jenisKanan,
        selKanan?.garis.jenisKiri ?? JenisGaris.tanpa,
      );
      if (kanan.ada) {
        segmen.add((
          sisi: _sisiKanan,
          mulai: 0,
          akhir: tinggiBagian,
          jenis: kanan,
        ));
      }
      final bawah = JenisGaris.terberat(
        g.jenisBawah,
        selBawah?.garis.jenisAtas ?? JenisGaris.tanpa,
      );
      if (bawah.ada) {
        segmen.add((
          sisi: _sisiBawah,
          mulai: 0,
          akhir: lebarBagian,
          jenis: bawah,
        ));
      }
      // Kiri/atas digambar tetangga (sebagai kanan/bawahnya) — kecuali di
      // tepi lembar atau di sebelah baris/kolom tersembunyi.
      if (g.kiri && (c == 1 || geo.lebar(c - 1) <= 0)) {
        segmen.add((
          sisi: _sisiKiri,
          mulai: 0,
          akhir: tinggiBagian,
          jenis: g.jenisKiri,
        ));
      }
      if (g.atas && (b == 1 || geo.tinggi(b - 1) <= 0)) {
        segmen.add((
          sisi: _sisiAtas,
          mulai: 0,
          akhir: lebarBagian,
          jenis: g.jenisAtas,
        ));
      }
    } else {
      _segmenGabungan(k, bagian, penuh, segmen);
    }

    final beku =
        (geo.kolomBeku > 0 && bagian.kolomAkhir == geo.kolomBeku
            ? _sisiKanan
            : 0) |
        (geo.barisBeku > 0 && bagian.barisAkhir == geo.barisBeku
            ? _sisiBawah
            : 0);

    final alamat = AlamatSel(b, c);
    return Listener(
      onPointerSignal: k.onSinyal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => k.onKetuk(alamat),
        onLongPress: k.onTekanLama == null
            ? null
            : () {
                k.onKetuk(alamat);
                k.onTekanLama!(alamat);
              },
        child: CustomPaint(
          painter: _LukisLatar(
            latar: latar,
            kisiKanan: kisiKanan,
            kisiBawah: kisiBawah,
            warnaKisi: k.warnaKisi,
            tebalKisi: k.piksel,
            irisan: irisan,
          ),
          foregroundPainter: _LukisTepi(
            segmen: segmen,
            warnaTepi: k.warnaTepi,
            piksel: k.piksel,
            beku: beku,
            warnaBeku: k.warnaBeku,
            tepiSeleksi: _keadaan.terpilih ? _keadaan.tepi : 0,
            warnaSeleksi: w.aksen,
          ),
          child: anak == null
              ? const SizedBox.expand()
              : SizedBox.expand(
                  child: Stack(
                    clipBehavior: klip ? Clip.hardEdge : Clip.none,
                    children: [anak],
                  ),
                ),
        ),
      ),
    );
  }

  /// Garis tepi kanan & bawah sel gabungan, per baris/kolom anggota (Excel
  /// menyimpan garis gabungan di sel-sel anggotanya), plus kiri/atas di tepi
  /// lembar. Bagian yang dipecah di batas freeze cuma menggambar tepi luar
  /// gabungan, bukan garis potongnya.
  void _segmenGabungan(
    _KonteksGrid k,
    RentangSel bagian,
    RentangSel penuh,
    List<_Segmen> segmen,
  ) {
    final geo = k.geo;
    if (bagian.kolomAkhir == penuh.kolomAkhir) {
      var y = 0.0;
      for (var r = bagian.barisAwal; r <= bagian.barisAkhir; r++) {
        final t = geo.tinggi(r);
        final kanan = JenisGaris.terberat(
          k.tonton(ref, r, penuh.kolomAkhir)?.garis.jenisKanan ??
              JenisGaris.tanpa,
          penuh.kolomAkhir + 1 <= geo.jumlahKolom
              ? k.tonton(ref, r, penuh.kolomAkhir + 1)?.garis.jenisKiri ??
                    JenisGaris.tanpa
              : JenisGaris.tanpa,
        );
        if (kanan.ada && t > 0) {
          segmen.add((sisi: _sisiKanan, mulai: y, akhir: y + t, jenis: kanan));
        }
        y += t;
      }
    }
    if (bagian.barisAkhir == penuh.barisAkhir) {
      var x = 0.0;
      for (var c = bagian.kolomAwal; c <= bagian.kolomAkhir; c++) {
        final l = geo.lebar(c);
        final bawah = JenisGaris.terberat(
          k.tonton(ref, penuh.barisAkhir, c)?.garis.jenisBawah ??
              JenisGaris.tanpa,
          penuh.barisAkhir + 1 <= geo.jumlahBaris
              ? k.tonton(ref, penuh.barisAkhir + 1, c)?.garis.jenisAtas ??
                    JenisGaris.tanpa
              : JenisGaris.tanpa,
        );
        if (bawah.ada && l > 0) {
          segmen.add((sisi: _sisiBawah, mulai: x, akhir: x + l, jenis: bawah));
        }
        x += l;
      }
    }
    if (bagian.kolomAwal == penuh.kolomAwal &&
        (penuh.kolomAwal == 1 || geo.lebar(penuh.kolomAwal - 1) <= 0)) {
      var y = 0.0;
      for (var r = bagian.barisAwal; r <= bagian.barisAkhir; r++) {
        final t = geo.tinggi(r);
        final kiri =
            k.tonton(ref, r, penuh.kolomAwal)?.garis.jenisKiri ??
            JenisGaris.tanpa;
        if (kiri.ada && t > 0) {
          segmen.add((sisi: _sisiKiri, mulai: y, akhir: y + t, jenis: kiri));
        }
        y += t;
      }
    }
    if (bagian.barisAwal == penuh.barisAwal &&
        (penuh.barisAwal == 1 || geo.tinggi(penuh.barisAwal - 1) <= 0)) {
      var x = 0.0;
      for (var c = bagian.kolomAwal; c <= bagian.kolomAkhir; c++) {
        final l = geo.lebar(c);
        final atas =
            k.tonton(ref, penuh.barisAwal, c)?.garis.jenisAtas ??
            JenisGaris.tanpa;
        if (atas.ada && l > 0) {
          segmen.add((sisi: _sisiAtas, mulai: x, akhir: x + l, jenis: atas));
        }
        x += l;
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════ pelukis

/// Lapis bawah sel: isi warna, garis kisi, lalu potongan teks tetangga yang
/// meluber (di ATAS isi warna sel ini, seperti Excel).
class _LukisLatar extends CustomPainter {
  _LukisLatar({
    required this.latar,
    required this.kisiKanan,
    required this.kisiBawah,
    required this.warnaKisi,
    required this.tebalKisi,
    required this.irisan,
  });

  final Color? latar;
  final bool kisiKanan;
  final bool kisiBawah;
  final Color warnaKisi;
  final double tebalKisi;
  final List<_Irisan> irisan;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = Offset.zero & size;
    final l = latar;
    if (l != null) canvas.drawRect(kotak, Paint()..color = l);
    if (kisiKanan || kisiBawah) {
      final p = Paint()
        ..color = warnaKisi
        ..strokeWidth = tebalKisi;
      final h = tebalKisi / 2;
      if (kisiKanan) {
        canvas.drawLine(
          Offset(size.width - h, 0),
          Offset(size.width - h, size.height),
          p,
        );
      }
      if (kisiBawah) {
        canvas.drawLine(
          Offset(0, size.height - h),
          Offset(size.width, size.height - h),
          p,
        );
      }
    }
    if (irisan.isNotEmpty) {
      canvas
        ..save()
        ..clipRect(kotak);
      for (final i in irisan) {
        i.pelukis.paint(canvas, i.posisi);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LukisLatar lama) =>
      lama.latar != latar ||
      lama.kisiKanan != kisiKanan ||
      lama.kisiBawah != kisiBawah ||
      lama.warnaKisi != warnaKisi ||
      lama.tebalKisi != tebalKisi ||
      lama.irisan.isNotEmpty ||
      irisan.isNotEmpty;
}

/// Lapis atas sel: garis tepi Excel (di atas kisi), garis freeze, dan garis
/// tebal tepi rentang terpilih.
class _LukisTepi extends CustomPainter {
  _LukisTepi({
    required this.segmen,
    required this.warnaTepi,
    required this.piksel,
    required this.beku,
    required this.warnaBeku,
    required this.tepiSeleksi,
    required this.warnaSeleksi,
  });

  final List<_Segmen> segmen;
  final Color warnaTepi;
  final double piksel;
  final int beku;
  final Color warnaBeku;
  final int tepiSeleksi;
  final Color warnaSeleksi;

  static double tebal(JenisGaris j, double piksel) => switch (j) {
    JenisGaris.tanpa => 0,
    JenisGaris.rambut => piksel,
    JenisGaris.titik || JenisGaris.putus || JenisGaris.tipis => 1,
    JenisGaris.sedang || JenisGaris.sedangPutus => 2,
    JenisGaris.ganda => 3,
    JenisGaris.tebal => 3,
  };

  static List<double>? pola(JenisGaris j) => switch (j) {
    JenisGaris.titik => const [1, 1],
    JenisGaris.putus => const [3, 1],
    JenisGaris.sedangPutus => const [6, 2],
    _ => null,
  };

  /// Garis sepanjang sisi [sisi] dari [mulai] ke [akhir], [tebal] tebal,
  /// sepenuhnya DI DALAM kotak sel, [inset] dari tepinya.
  static void garis(
    Canvas canvas,
    Size size,
    int sisi,
    double mulai,
    double akhir,
    double tebal,
    Paint p, {
    double inset = 0,
    List<double>? pola,
  }) {
    final h = inset + tebal / 2;
    final (Offset a, Offset b) = switch (sisi) {
      _sisiKanan => (
        Offset(size.width - h, mulai),
        Offset(size.width - h, akhir),
      ),
      _sisiBawah => (
        Offset(mulai, size.height - h),
        Offset(akhir, size.height - h),
      ),
      _sisiKiri => (Offset(h, mulai), Offset(h, akhir)),
      _ => (Offset(mulai, h), Offset(akhir, h)),
    };
    p.strokeWidth = tebal;
    if (pola == null) {
      canvas.drawLine(a, b, p);
      return;
    }
    final panjang = (b - a).distance;
    if (panjang <= 0) return;
    final arah = (b - a) / panjang;
    var s = 0.0;
    var i = 0;
    while (s < panjang) {
      final l = pola[i % pola.length];
      if (i.isEven) {
        canvas.drawLine(a + arah * s, a + arah * math.min(panjang, s + l), p);
      }
      s += l;
      i++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (segmen.isNotEmpty) {
      final p = Paint()
        ..color = warnaTepi
        ..style = PaintingStyle.stroke;
      for (final s in segmen) {
        if (s.jenis == JenisGaris.ganda) {
          garis(canvas, size, s.sisi, s.mulai, s.akhir, 1, p);
          garis(canvas, size, s.sisi, s.mulai, s.akhir, 1, p, inset: 2);
        } else {
          garis(
            canvas,
            size,
            s.sisi,
            s.mulai,
            s.akhir,
            tebal(s.jenis, piksel),
            p,
            pola: pola(s.jenis),
          );
        }
      }
    }
    if (beku != 0) {
      final p = Paint()..color = warnaBeku;
      if (beku & _sisiKanan != 0) {
        garis(canvas, size, _sisiKanan, 0, size.height, 1, p);
      }
      if (beku & _sisiBawah != 0) {
        garis(canvas, size, _sisiBawah, 0, size.width, 1, p);
      }
    }
    if (tepiSeleksi != 0) {
      final p = Paint()..color = warnaSeleksi;
      for (final sisi in const [_sisiAtas, _sisiKanan, _sisiBawah, _sisiKiri]) {
        if (tepiSeleksi & sisi == 0) continue;
        final mendatar = sisi == _sisiAtas || sisi == _sisiBawah;
        garis(canvas, size, sisi, 0, mendatar ? size.width : size.height, 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LukisTepi lama) => true;
}

// ═══════════════════════════════════════════════════════════════ kepala

/// Kepala kolom/baris & sudut bergaya Excel: abu muda, teks di tengah,
/// garis pemisah; yang terpilih disorot dengan garis aksen di sisi dalam.
class _LukisKepala extends CustomPainter {
  _LukisKepala({
    required this.latar,
    required this.garis,
    required this.garisLuar,
    required this.sisiLuar,
    required this.piksel,
    this.aksen,
  });

  final Color latar;
  final Color garis;
  final Color garisLuar;

  /// Sisi yang berbatasan dengan sel (bawah untuk kepala kolom, kanan untuk
  /// nomor baris).
  final int sisiLuar;
  final double piksel;
  final Color? aksen;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = latar);
    final p = Paint()..color = garis;
    final pl = Paint()..color = garisLuar;
    final tebal = math.max(piksel, 1.0);
    for (final sisi in const [_sisiKanan, _sisiBawah]) {
      final mendatar = sisi == _sisiBawah;
      _LukisTepi.garis(
        canvas,
        size,
        sisi,
        0,
        mendatar ? size.width : size.height,
        tebal,
        sisi == sisiLuar ? pl : p,
      );
    }
    final a = aksen;
    if (a != null) {
      final mendatar = sisiLuar == _sisiBawah;
      _LukisTepi.garis(
        canvas,
        size,
        sisiLuar,
        0,
        mendatar ? size.width : size.height,
        2,
        Paint()..color = a,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LukisKepala lama) =>
      lama.latar != latar ||
      lama.garis != garis ||
      lama.garisLuar != garisLuar ||
      lama.aksen != aksen ||
      lama.piksel != piksel;
}

class _Sudut extends StatelessWidget {
  const _Sudut({super.key, required this.konteks});

  final _KonteksGrid konteks;

  @override
  Widget build(BuildContext context) {
    final w = konteks.warna;
    return Listener(
      onPointerSignal: konteks.onSinyal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: konteks.onPilihSemua,
        child: CustomPaint(
          painter: _LukisKepala(
            latar: w.permukaanRendah,
            garis: w.garisKuat,
            garisLuar: w.garisKuat,
            sisiLuar: _sisiKanan | _sisiBawah,
            piksel: konteks.piksel,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KepalaKolom extends StatefulWidget {
  const _KepalaKolom({super.key, required this.kolom, required this.konteks});

  final int kolom;
  final _KonteksGrid konteks;

  @override
  State<_KepalaKolom> createState() => _KepalaKolomState();
}

class _KepalaKolomState extends State<_KepalaKolom> {
  late bool _sorot;
  KendaliGridSel? _kendali;

  bool _hitung() {
    final r = widget.konteks.kendali.rentang;
    return widget.kolom >= r.kolomAwal && widget.kolom <= r.kolomAkhir;
  }

  void _dengar() {
    final baru = _hitung();
    if (baru != _sorot) setState(() => _sorot = baru);
  }

  @override
  void initState() {
    super.initState();
    _kendali = widget.konteks.kendali..addListener(_dengar);
    _sorot = _hitung();
  }

  @override
  void didUpdateWidget(covariant _KepalaKolom lama) {
    super.didUpdateWidget(lama);
    if (!identical(_kendali, widget.konteks.kendali)) {
      _kendali?.removeListener(_dengar);
      _kendali = widget.konteks.kendali..addListener(_dengar);
    }
    _sorot = _hitung();
  }

  @override
  void dispose() {
    _kendali?.removeListener(_dengar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.konteks;
    if (k.geo.lebar(widget.kolom) <= 0) return const SizedBox.shrink();
    return _Kepala(
      teks: hurufKolom(widget.kolom),
      sorot: _sorot,
      sisiLuar: _sisiBawah,
      konteks: k,
      onTap: () => k.onPilihKolom(widget.kolom),
    );
  }
}

class _KepalaBaris extends StatefulWidget {
  const _KepalaBaris({super.key, required this.baris, required this.konteks});

  final int baris;
  final _KonteksGrid konteks;

  @override
  State<_KepalaBaris> createState() => _KepalaBarisState();
}

class _KepalaBarisState extends State<_KepalaBaris> {
  late bool _sorot;
  KendaliGridSel? _kendali;

  bool _hitung() {
    final r = widget.konteks.kendali.rentang;
    return widget.baris >= r.barisAwal && widget.baris <= r.barisAkhir;
  }

  void _dengar() {
    final baru = _hitung();
    if (baru != _sorot) setState(() => _sorot = baru);
  }

  @override
  void initState() {
    super.initState();
    _kendali = widget.konteks.kendali..addListener(_dengar);
    _sorot = _hitung();
  }

  @override
  void didUpdateWidget(covariant _KepalaBaris lama) {
    super.didUpdateWidget(lama);
    if (!identical(_kendali, widget.konteks.kendali)) {
      _kendali?.removeListener(_dengar);
      _kendali = widget.konteks.kendali..addListener(_dengar);
    }
    _sorot = _hitung();
  }

  @override
  void dispose() {
    _kendali?.removeListener(_dengar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.konteks;
    if (k.geo.tinggi(widget.baris) <= 0) return const SizedBox.shrink();
    return _Kepala(
      teks: '${widget.baris}',
      sorot: _sorot,
      sisiLuar: _sisiKanan,
      konteks: k,
      onTap: () => k.onPilihBaris(widget.baris),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({
    required this.teks,
    required this.sorot,
    required this.sisiLuar,
    required this.konteks,
    required this.onTap,
  });

  final String teks;
  final bool sorot;
  final int sisiLuar;
  final _KonteksGrid konteks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = konteks.warna;
    return Listener(
      onPointerSignal: konteks.onSinyal,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: _LukisKepala(
              latar: sorot ? w.aksenTipis : w.permukaanRendah,
              garis: w.garis,
              garisLuar: w.garisKuat,
              sisiLuar: sisiLuar,
              piksel: konteks.piksel,
              aksen: sorot ? w.aksen : null,
            ),
            child: Center(
              child: Text(
                teks,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: sorot
                    ? konteks.gayaKepala.copyWith(
                        color: w.teks,
                        fontWeight: FontWeight.w600,
                      )
                    : konteks.gayaKepala,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════ editor

/// Kolom isian di dalam sel yang sedang diedit. Teks = [KendaliGridSel.
/// teksEdit] (sama dengan bilah rumus); Enter/Tab/Esc ditangkap fokusnya
/// ([_KonteksGrid.fokusEdit]) sebelum sampai ke kolom isian. Keyboard lunak
/// tablet muncul karena kolom ini memegang fokus; tombol "selesai"-nya =
/// Enter.
class _EditorSel extends StatefulWidget {
  const _EditorSel({
    required this.konteks,
    required this.latar,
    required this.gaya,
  });

  final _KonteksGrid konteks;
  final Color latar;
  final TextStyle gaya;

  @override
  State<_EditorSel> createState() => _EditorSelState();
}

class _EditorSelState extends State<_EditorSel> {
  @override
  void initState() {
    super.initState();
    // Dibangun ulang sesudah sel digulir keluar lalu masuk lagi: fokusnya
    // kembali ke sini (selama masih mengedit di sel).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final k = widget.konteks;
      if (mounted &&
          k.kendali.sedangEdit &&
          k.kendali.tempatEdit == TempatEdit.sel &&
          !k.fokusEdit.hasFocus) {
        k.fokusEdit.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.konteks;
    return ColoredBox(
      color: widget.latar,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: k.pad),
        child: Center(
          child: MediaQuery.withNoTextScaling(
            child: TextField(
              key: kunciEditorSel,
              controller: k.kendali.teksEdit,
              focusNode: k.fokusEdit,
              // Gaya sel `inherit: false` (ukuran identik dengan teks sel);
              // kolom isian mewajibkan garis dasar eksplisit untuk itu.
              style: widget.gaya.copyWith(
                textBaseline: TextBaseline.alphabetic,
              ),
              cursorColor: k.warna.aksen,
              cursorWidth: 1.5,
              maxLines: 1,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration.collapsed(hintText: null),
              scrollPadding: EdgeInsets.zero,
              // Ketukan di luar (sel lain, tombol ✓) diurus grid/bilah rumus,
              // bukan dengan melepas fokus diam-diam.
              onTapOutside: (_) {},
              onSubmitted: (_) => k.onSimpanEdit(1, 0),
            ),
          ),
        ),
      ),
    );
  }
}
