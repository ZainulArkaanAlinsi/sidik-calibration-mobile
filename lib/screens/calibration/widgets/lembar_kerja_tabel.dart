import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/lembar_kerja.dart';
import '../../../models/standard.dart';
import '../../../providers/calibration_input_provider.dart';
import '../../../services/ambil_foto_tabel.dart';
import '../../../services/peta_tabel_foto.dart';
import '../../../widgets/label_standar.dart';
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
    this.pindaiAktif = AppConfig.pindaiLembarAktif,
  });

  final TabelHasil tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Saklar tombol `FOTO TABEL INI`. Default ngikut
  /// [AppConfig.pindaiLembarAktif] — sekarang NYALA.
  ///
  /// Dibikin parameter, bukan dibaca langsung dari `AppConfig` di dalam
  /// `build`: nilai `const bool.fromEnvironment` nggak bisa disetel dari
  /// `flutter test`, jadi tanpa jalan masuk ini test alur fotonya cuma bisa
  /// dihapus. Layar ngisinya dari `pindaiLembarAktifProvider` biar satu bagian
  /// nggak bisa setengah nyala.
  final bool pindaiAktif;

  /// Baris yang digambar — **ngikut satuan yang lagi kepilih**, bukan
  /// `tabel.baris` yang isinya set bawaan dari backend.
  ///
  /// Refractometer ngirim titik standar beda per skala (1,33659/1,39986 n20D
  /// vs 2,5/40 °Brix), dan `LembarKerjaState` mbangun `titik`-nya dari set yang
  /// kepilih. Waktu widget ini masih baca `tabel.baris` sementara state-nya
  /// udah pindah ke °Brix, `isian.titik[...]!` nabrak null dan tabelnya gagal
  /// digambar sama sekali.
  // Lewat state, BUKAN `tabel.barisUntuk()` langsung — lembar yang titiknya
  // boleh diatur teknisi (TITS) barisnya datang dari situ. Lihat
  // `LembarKerjaState.barisTabel`.
  List<BarisTabelHasil> get _baris => isian.barisTabel(tabel);

  /// Semua baris nunjuk ke SATU standar tercetak yang sama?
  ///
  /// `false` kalau cuma ada satu baris (nggak ada yang digabung), atau kalau
  /// ada baris tanpa pasangan standar sama sekali — yang begitu butuh
  /// dropdown-nya sendiri, dan nyembunyiin di balik baris gabungan bikin
  /// teknisi nggak punya jalan buat ngisinya.
  bool get _satuStandarSemuaTitik {
    final baris = _baris;
    if (baris.length < 2) return false;

    final pertama = isian.titik[baris.first.titikUkur]?.standardIdTercetak;
    if (pertama == null) return false;

    return baris.every(
      (b) => isian.titik[b.titikUkur]?.standardIdTercetak == pertama,
    );
  }

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
    if (tabel.judulNilaiUntuk(isian.modeKalibrasi) != null || satuan.isEmpty) {
      return baris.label;
    }

    return '${baris.label} $satuan';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ukuran = _ukurKolomLabel(context);

    // Dihitung SEKALI. `_baris` itu getter yang menyusun ulang daftarnya tiap
    // dibaca; dipanggil di dalam perulangan kolom label, tabel sepuluh baris
    // menyusunnya puluhan kali per frame.
    final barisTabel = _baris;

    // Nomor pengulangan dipotong jadi baris-baris sesuai lembar cetaknya —
    // satu potongan buat alat biasa, dua buat blok %T (X1..X3 dua kali).
    final potongan = tabel.pengulanganPerBarisnya;
    final judulPengulangan = tabel.judulPengulanganUntuk(isian.modeKalibrasi);
    final tinggiKepala = _tinggiKepala +
        (judulPengulangan == null ? 0.0 : _tinggiKepalaGabungan);

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

        // Peringatan "isinya belum punya tempat" duduk DI ATAS tabelnya,
        // bukan di bawah: teknisi yang membaca setelah mengisi 35 kotak sudah
        // terlambat diberi tahu.
        if (tabel.tanpaTempatSimpan) ...[
          _CatatanTabel(teks: AppLocalizations.of(context).lkTabelBelumDisimpan),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Tombolnya sengaja LEBAR & BERLABEL, bukan ikon kecil di pojok: ini
        // jalan pintas yang paling sering dipakai di lapangan, dan waktu cuma
        // ikon di sebelah judul, teknisi nggak nemu sama sekali.
        //
        // Spacer bawahnya ikut masuk `if`, bukan ditinggal di luar: kalau cuma
        // tombolnya yang hilang, yang ketinggalan celah kosong dua kali `sm`
        // di atas SETIAP tabel — dan celah kosong tanpa isi kelihatannya kayak
        // widget yang gagal digambar.
        if (pindaiAktif) ...[
          SizedBox(
            width: double.infinity,
            child: _TombolFotoTabel(
              tabel: tabel,
              isian: isian,
              onBerubah: onBerubah,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

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
                  // Judulnya BERTUKAR sisi antar mode di TITS — lihat
                  // `TabelHasil.judulNilaiPerMode`. Alat lain nggak punya peta
                  // itu dan jatuh ke `judulNilai` seperti dulu.
                  teks: tabel.judulNilaiUntuk(isian.modeKalibrasi) ?? 'Standard',
                  tinggi: tinggiKepala,
                ),
                for (var iBaris = 0; iBaris < barisTabel.length; iBaris++)
                  if (!barisTabel[iBaris].titikDitentukan)
                    // Kertas TIDS mencetak tujuh baris `Setpoint` KOSONG —
                    // angkanya ditulis teknisi di lapangan, bukan dipatok
                    // master seperti buffer pH. Jadi kolom kiri baris ini kotak
                    // isian, bukan label mati.
                    _SelSetpoint(
                      lebar: ukuran.lebar,
                      tinggi: ukuran.tinggi * potongan.length,
                      state: isian.titikUntukBaris(barisTabel, iBaris, tabel),
                      satuan: isian.bentuk.satuanUntuk(barisTabel[iBaris]),
                      onBerubah: onBerubah,
                    )
                  else
                  _SelKepala(
                    lebar: ukuran.lebar,
                    // Satuannya ikut, persis sheet INPUT DATA yang nulis
                    // "1,74 mg/L". Tanpa itu angka standarnya kebaca telanjang
                    // dan gampang ketuker sama pembacaan di sebelahnya.
                    // Satuan diambil PER BARIS lewat `satuanUntuk` — lembar
                    // Conductivity nyampur µS/cm & mS/cm, dan ngambil dari
                    // level lembar bikin 111 mS/cm kelabel µS/cm.
                    teks: _labelBaris(barisTabel[iBaris]),
                    // Keterangan singkat kenapa baris ini mati — tanpa itu
                    // teknisi lihat kotak abu tanpa sebab.
                    catatan: isian.titikTerkunci(barisTabel[iBaris].titikUkur)
                        ? AppLocalizations.of(context).lkTitikAlternatifSatuan
                        : null,
                    // Diketuk = keluar penjelasan penuhnya, termasuk CARA
                    // mbukanya. Catatan sebarisnya nggak muat nampung itu.
                    onKetuk: isian.titikTerkunci(barisTabel[iBaris].titikUkur)
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).lkTitikAlternatifSatuanBantuan,
                              ),
                              duration: const Duration(seconds: 8),
                            ),
                          )
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
                    if (judulPengulangan != null)
                      _SelKepala(
                        lebar: _lebarSel * tabel.kolom.length * potongan.first.length,
                        teks: judulPengulangan,
                        tinggi: _tinggiKepalaGabungan,
                        // Jatahnya 26 dp — satu baris. Judul yang lebih panjang
                        // dipotong berellipsis, BUKAN dibiarkan membungkus:
                        // dua baris meluber keluar kotaknya dan di debug yang
                        // kelihatan pita kuning-hitam menutupi tabel.
                        maksBaris: 1,
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
                            // `UP X1` / `DOWN X2` buat TITS. Kosong buat alat
                            // lain, dan di situ nomornya digambar seperti dulu.
                            label: tabel.pengulanganArah[r],
                          ),
                      ],
                    ),

                    for (var indexBaris = 0; indexBaris < _baris.length; indexBaris++)
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
                                terkunci: !isian.titikBisaDiisi(
                                  isian.kunciBaris(_baris, indexBaris, tabel),
                                ),
                                // Index kotak diambil dari POSISI nomor
                                // pengulangan di daftar aslinya, bukan dari
                                // urutan gambar — baris kedua %T isinya
                                // pengulangan 4-6 dan kotaknya beda dari
                                // baris pertama walau kepalanya sama.
                                // Kuncinya lewat `kunciBaris`, BUKAN
                                // `baris.titikUkur` mentah. Autoklaf ngirim
                                // `titik_ukur: 0` buat kedelapan barisnya —
                                // besarannya emang beda-beda, bukan titik ukur
                                // — jadi kalau dibaca mentah kedelapan baris
                                // nunjuk ke controller yang SAMA dan yang
                                // keliatan cuma satu baris keisi.
                                controller: isian
                                    .titik[isian.kunciBaris(_baris, indexBaris, tabel)]!
                                    .kotak(
                                      tabel.kunciTabel,
                                      kolom.kode,
                                      tabel.pengulangan.indexOf(r),
                                    ),
                                // Sel yang diminta admin dibetulin, atau yang
                                // diisi pindai dengan keyakinan rendah —
                                // ditandai supaya dicek yang itu saja, bukan
                                // seluruh tabel.
                                tanda: isian.tandaSel(
                                  isian.kunciBaris(_baris, indexBaris, tabel),
                                  tabel.kunciTabel,
                                  kolom.kode,
                                  tabel.pengulangan.indexOf(r),
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
          // Satu standar buat SEMUA titik cuma ditanya sekali.
          //
          // Di pH tiap titik memang punya larutannya sendiri (buffer 4 nggak
          // bisa dipakai buat titik 7), jadi tiga baris itu tiga pertanyaan
          // beda. Di TITS satu kalibrator melayani sembilan titik: sembilan
          // baris yang bunyinya sama persis bukan cuma berisik — dia bikin
          // pembaca ngira tiap titik punya kalibrator sendiri, dan ngedorong
          // tabel After Adjustment jauh ke bawah.
          //
          // Diputusin dari DATA (semua baris nunjuk standar yang sama), bukan
          // dari daftar nama alat: alat mana pun yang standarnya satu ikut
          // rapi tanpa nyentuh file ini, dan yang standarnya beneran beda per
          // titik tetap dapat satu baris per titik seperti dulu.
          if (_satuStandarSemuaTitik)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PilihStandarTitik(
                label: _baris.first.label,
                state: isian.titik[_baris.first.titikUkur]!,
                judulGabungan: true,
                // Centang & "Ganti" berlaku buat seluruh titik — itu memang
                // artinya waktu kalibratornya cuma satu.
                serempak: [
                  for (final b in _baris.skip(1)) isian.titik[b.titikUkur]!,
                ],
                onBerubah: onBerubah,
              ),
            )
          else
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
  static const _lebarSel = 78.0;
  static const _tinggiBaris = 56.0;

  /// Lantai tiap baris kepala — tinggi SEBENARNYA diukur dari isinya di
  /// [_ukurKepala], dan nggak pernah turun di bawah angka-angka ini.
  ///
  /// Dulu keenam ukuran di blok ini dipatok mati. Yang dipatok itu kotaknya,
  /// bukan isinya: `Resolusi: 0,01 mS/cm` butuh dua baris di kolom 156px, dan
  /// `Repeat` sendiri nggak muat di kolom 72px. Hasilnya enam kotak kepala
  /// meluber sekaligus — tabelnya kelihatan berantakan tanpa satu pun error.
  static const _tinggiKepalaSlotMin = 46.0;
  static const _tinggiResolusiMin = 28.0;
  static const _tinggiKepalaSatuanMin = 30.0;
  static const _tinggiJudulMin = 26.0;

  /// Kolom "Repeat" yang nempel di kiri. Batas atasnya biar area gulung
  /// nggak keburu habis di HP sempit.
  static const _lebarRepeatMin = 72.0;
  static const _lebarRepeatMaks = 120.0;

  TabelHasil get _tabel => widget.tabel;

  List<KolomTabelHasil> get _kolom => _tabel.kolom;

  double get _lebarSlot => _lebarSel * _kolom.length;

  /// Lebar seluruh kolom slot berikut garis pemisah di antaranya.
  double get _lebarSemuaSlot {
    final n = _tabel.slotCetak.length;

    return _lebarSlot * n + _garisPemisah * (n - 1).clamp(0, n);
  }

  /// Ukur satu potong teks pada lebar yang bakal dipakai waktu digambar.
  ({double lebar, double tinggi}) _ukurTeks(
    String teks,
    TextStyle? gaya, {
    double lebarMaks = double.infinity,
    int? maksBaris,
  }) {
    final pelukis = TextPainter(
      text: TextSpan(text: teks, style: gaya),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maksBaris,
    )..layout(maxWidth: lebarMaks);

    return (lebar: pelukis.width, tinggi: pelukis.height);
  }

  /// Ukuran seluruh blok kepala, diukur dari ISINYA.
  ///
  /// Dihitung sekali di [build] dan dioper ke DUA sisi: kolom "Repeat" yang
  /// nempel di kiri, dan kolom slot di dalam area gulung. Kalau tiap sisi
  /// ngukur sendiri-sendiri, barisnya lari begitu salah satu isinya berubah.
  ({
    double lebarRepeat,
    double tinggiJudul,
    double tinggiKepalaSlot,
    double tinggiResolusi,
    double tinggiKepalaSatuan,
  })
  _ukurKepala(ThemeData theme, AppLocalizations l10n) {
    final gayaLabel = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final gayaSub = theme.textTheme.labelSmall;
    final slot = _tabel.slotCetak;

    // --- kolom "Repeat" yang nempel di kiri -------------------------------
    final lebarRepeat = (_ukurTeks(l10n.lkRepeat, gayaLabel).lebar +
            _selaKepala)
        .clamp(_lebarRepeatMin, _lebarRepeatMaks);

    // --- kepala slot: pil pilihan satuan + larutan yang sebenarnya ---------
    final lebarIsiSlot = _lebarSlot - _selaKepala;
    var tinggiKepalaSlot = _tinggiKepalaSlotMin;

    for (final s in slot) {
      final double tinggiPilihan;

      if (s.titikUkur.length < 2) {
        tinggiPilihan =
            _ukurTeks(s.label, gayaLabel, lebarMaks: lebarIsiSlot).tinggi;
      } else {
        // Pilnya digambar sendiri, bukan `ChoiceChip`: geometri chip diputus
        // theme dan nggak bisa diukur dari luar, jadi dua pil `1413 µS` /
        // `1.413 mS` dulu minta 265px di kolom 156px dan meluber 109px.
        final teks = [
          s.label,
          for (var i = 1; i < s.titikUkur.length; i++) s.varian ?? s.label,
        ];

        var lebarSemua = 0.0;
        var tinggiSatu = 0.0;

        for (final t in teks) {
          final u = _ukurTeks(t, gayaSub, maksBaris: 1);
          lebarSemua += u.lebar + 2 * (_selaPilX + _garisPil);
          tinggiSatu = tinggiSatu < u.tinggi ? u.tinggi : tinggiSatu;
        }

        lebarSemua += _jarakPil * (teks.length - 1);
        tinggiSatu += 2 * (_selaPilY + _garisPil);

        // `Wrap` nurunin pil yang nggak muat ke baris berikutnya — jadi yang
        // diukur di sini jumlah barisnya, bukan mengandaikan selalu sebaris.
        final baris = lebarSemua <= lebarIsiSlot ? 1 : teks.length;
        tinggiPilihan = baris * tinggiSatu + (baris - 1) * _jarakPil;
      }

      final tinggiSub = _ukurTeks(
        _subLabelSlot(s, l10n),
        gayaSub,
        lebarMaks: lebarIsiSlot,
        maksBaris: 1,
      ).tinggi;

      final perlu = tinggiPilihan + tinggiSub + _selaKepala;
      if (perlu > tinggiKepalaSlot) tinggiKepalaSlot = perlu;
    }

    // --- baris `Resolusi: ( )` --------------------------------------------
    var tinggiResolusi = _tinggiResolusiMin;

    for (final s in slot) {
      final teks = _teksResolusi(s, l10n);

      final perlu =
          _ukurTeks(teks, gayaLabel, lebarMaks: lebarIsiSlot).tinggi +
          _selaKepala;
      if (perlu > tinggiResolusi) tinggiResolusi = perlu;
    }

    // --- kepala satuan per kolom, plus kata "Repeat" di kolom nempel ------
    var tinggiKepalaSatuan =
        _ukurTeks(
          l10n.lkRepeat,
          gayaLabel,
          lebarMaks: lebarRepeat - _selaKepala,
        ).tinggi +
        _selaKepala;

    for (final s in slot) {
      for (final k in _kolom) {
        final teks = k.kode == 'suhu'
            ? (k.satuan ?? '°C')
            : (s.satuan ?? k.label);

        final perlu =
            _ukurTeks(
              teks,
              gayaLabel,
              lebarMaks: _lebarSel - _selaKepala,
            ).tinggi +
            _selaKepala;
        if (perlu > tinggiKepalaSatuan) tinggiKepalaSatuan = perlu;
      }
    }

    if (tinggiKepalaSatuan < _tinggiKepalaSatuanMin) {
      tinggiKepalaSatuan = _tinggiKepalaSatuanMin;
    }

    // --- kepala yang memayungi seluruh kolom slot (`Solution Standard`) ----
    final judul = _tabel.judulNilaiUntuk(widget.isian.modeKalibrasi);
    var tinggiJudul = 0.0;

    if (judul != null && judul.isNotEmpty) {
      tinggiJudul =
          _ukurTeks(
            judul,
            gayaLabel,
            lebarMaks: _lebarSemuaSlot - _selaKepala,
          ).tinggi +
          _selaKepala;
      if (tinggiJudul < _tinggiJudulMin) tinggiJudul = _tinggiJudulMin;
    }

    return (
      lebarRepeat: lebarRepeat,
      tinggiJudul: tinggiJudul,
      tinggiKepalaSlot: tinggiKepalaSlot,
      tinggiResolusi: tinggiResolusi,
      tinggiKepalaSatuan: tinggiKepalaSatuan,
    );
  }

  /// Titik yang aktif buat slot ini — jawabannya dari
  /// [LembarKerjaState.titikAktifSlot], yang dipakai bareng sama tombol foto
  /// tabel.
  double? _titikAktif(int index, SlotCetak slot) =>
      widget.isian.titikAktifSlot(_tabel.kunciTabel, index, slot);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final slot = _tabel.slotCetak;
    final ulang = _tabel.pengulangan;
    final ukuran = _ukurKepala(theme, l10n);
    final judul = _tabel.judulNilaiUntuk(widget.isian.modeKalibrasi);

    final garis = theme.colorScheme.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kolom "Repeat" nempel di kiri, di luar area gulung — sama alasannya
        // kayak kolom label di bentuk pH: tanpa itu teknisi kehilangan nomor
        // pengulangan begitu geser ke slot paling kanan.
        //
        // Garis di kanannya yang misahin dia dari area gulung. Tanpa itu nomor
        // Repeat kelihatan nempel ke kolom angka slot pertama, dan waktu
        // tabelnya digeser dia kelihatan seperti ikut bergeser.
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: garis)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ukuran.tinggiJudul > 0)
                _SelKepala(
                  lebar: ukuran.lebarRepeat,
                  teks: '',
                  tinggi: ukuran.tinggiJudul,
                ),
              _SelKepala(
                lebar: ukuran.lebarRepeat,
                teks: '',
                tinggi: ukuran.tinggiKepalaSlot + ukuran.tinggiResolusi,
              ),
              _SelKepala(
                lebar: ukuran.lebarRepeat,
                teks: l10n.lkRepeat,
                tinggi: ukuran.tinggiKepalaSatuan,
              ),
              _GarisMendatar(lebar: ukuran.lebarRepeat),
              for (final r in ulang)
                _SelKepala(
                  lebar: ukuran.lebarRepeat,
                  teks: '$r',
                  tinggi: _tinggiBaris,
                ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kepala yang memayungi seluruh kolom slot
                // (`Solution Standard`). Tanpa ini, kolom-kolom di kanan
                // berdiri tanpa keterangan apa pun — dan yang di bawahnya
                // justru angka pembacaan, jadi gampang kebaca kebalik.
                //
                // Rata KIRI, bukan tengah: lebarnya seluruh tabel (jauh lebih
                // lebar dari layar), jadi kalau ditaruh di tengah tulisannya
                // mendarat di luar layar dan teknisi baru nemu sesudah
                // menggeser.
                if (judul != null && ukuran.tinggiJudul > 0)
                  _SelKepala(
                    lebar: _lebarSemuaSlot,
                    teks: judul,
                    tinggi: ukuran.tinggiJudul,
                    kiri: true,
                  ),

                // Tiap slot digambar sebagai SATU kolom utuh — kepala, baris
                // resolusi, kepala satuan, lalu angkanya — bukan sebagai baris
                // yang memotong semua slot. Begitu slotnya jadi satu kolom,
                // garis pemisahnya tinggal border kiri; sebelumnya empat slot
                // nyambung tanpa batas dan `Resolusi: 0,1 µS/cm` kelihatan
                // nempel ke `Resolusi: 1 µS/cm` sebelahnya.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < slot.length; i++)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : Border(left: BorderSide(color: garis)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _KepalaSlot(
                              lebar: _lebarSlot,
                              tinggi: ukuran.tinggiKepalaSlot,
                              slot: slot[i],
                              titikAktif: _titikAktif(i, slot[i]),
                              onPilih: slot[i].titikUkur.length < 2
                                  ? null
                                  : (pilih) => setState(() {
                                      widget.isian.pilihanSlot[LembarKerjaState
                                              .kunciSlot(_tabel.kunciTabel, i)] =
                                          pilih;
                                    }),
                            ),

                            // Baris `Resolusi: ( )` — di kertas satu baris
                            // sendiri per slot. Angkanya dari spesifikasi
                            // alat, jadi ditampilin, bukan dikosongin buat
                            // diisi tangan.
                            _SelKepala(
                              lebar: _lebarSlot,
                              tinggi: ukuran.tinggiResolusi,
                              teks: _teksResolusi(slot[i], l10n),
                            ),

                            // Kepala satuan per kolom: `µS` / `°C` di kertas.
                            Row(
                              children: [
                                for (final k in _kolom)
                                  _SelKepala(
                                    lebar: _lebarSel,
                                    tinggi: ukuran.tinggiKepalaSatuan,
                                    teks: k.kode == 'suhu'
                                        ? (k.satuan ?? '°C')
                                        : (slot[i].satuan ?? k.label),
                                  ),
                              ],
                            ),

                            _GarisMendatar(lebar: _lebarSlot),

                            for (final r in ulang)
                              Row(
                                children: [
                                  for (final k in _kolom)
                                    _selAngka(slot[i], i, k, r),
                                ],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tulisan baris resolusi, dengan koma desimal seperti lembar kerjanya.
  String _teksResolusi(SlotCetak slot, AppLocalizations l10n) =>
      slot.resolusi == null
      ? l10n.lkResolusiKosong
      : l10n.lkResolusiNilai(_angkaTampil(slot.resolusi!), slot.satuan ?? '');

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
      controller: state.kotak(_tabel.kunciTabel, kolom.kode, urutan),
      tanda: widget.isian.tandaSel(titik, _tabel.kunciTabel, kolom.kode, urutan),
    );
  }
}

/// Jarak nafas di dalam sel kepala tabel ke-bawah, kiri-kanan dan atas-bawah.
const _selaKepala = 8.0;

/// Tebal garis pemisah antar slot. Ikut kehitung di lebar tabel — kalau nggak,
/// kepala `Solution Standard` di atasnya jadi lebih pendek dari kolom yang
/// dipayunginya.
const _garisPemisah = 1.0;

/// Angka yang DITAMPILIN di kepala tabel — koma desimal, seperti lembar
/// kerjanya. Beda dari [formatAngka], yang sengaja ngasih titik karena hasilnya
/// masuk ke kotak isian buat diketik ulang.
String _angkaTampil(double nilai) => formatAngka(nilai).replaceAll('.', ',');

/// Larutan yang SEBENARNYA di balik satu slot cetak.
///
/// Dipakai bareng sama yang menggambar ([_KepalaSlot]) dan yang mengukur
/// (`_TabelKeBawahState._ukurKepala`), supaya tinggi yang diukur nggak pernah
/// beda dari teks yang kegambar.
String _subLabelSlot(SlotCetak slot, AppLocalizations l10n) => slot.mati
    ? l10n.lkSlotTanpaLarutan
    : '${_angkaTampil(slot.titikUkur.first)} ${slot.satuan ?? ''}';

/// Garis mendatar yang misahin blok kepala dari baris angkanya.
///
/// Digambar di DUA sisi — kolom "Repeat" yang nempel dan tiap kolom slot — di
/// urutan yang sama, jadi tingginya ikut sama dan barisnya nggak lari.
class _GarisMendatar extends StatelessWidget {
  const _GarisMendatar({required this.lebar});

  final double lebar;

  @override
  Widget build(BuildContext context) => Container(
    width: lebar,
    height: _garisPemisah,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// Geometri pil pilihan satuan. Dipakai buat MENGGAMBAR (di [_PilSatuan]) dan
/// buat MENGUKUR (di `_TabelKeBawahState._ukurKepala`) — satu sumber, supaya
/// yang diukur nggak pernah beda dari yang kegambar.
const _selaPilX = 8.0;
const _selaPilY = 6.0;
const _garisPil = 1.0;
const _jarakPil = 4.0;

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _selaKepala / 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (onPilih == null)
              Text(slot.label, style: gaya, textAlign: TextAlign.center)
            else
              // Kertasnya bilang "ceklis salah satu" — jadi di layar pun ini
              // pilihan, bukan dua kolom terpisah. Yang kepilih nentuin sel di
              // bawahnya nulis ke titik yang mana.
              //
              // `Wrap`, bukan `Row`: kolom slot ini selebar sel angkanya
              // (78px × jumlah kolom), dan dua pil nggak selalu muat sebaris
              // di HP sempit atau waktu teks sistemnya diperbesar. Yang nggak
              // muat turun ke baris bawah — tingginya udah ikut keukur.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: _jarakPil,
                runSpacing: _jarakPil,
                children: [
                  for (var i = 0; i < slot.titikUkur.length; i++)
                    _PilSatuan(
                      teks: i == 0 ? slot.label : (slot.varian ?? slot.label),
                      dipilih: titikAktif == slot.titikUkur[i],
                      onTekan: () => onPilih!(i),
                    ),
                ],
              ),

            // Larutan yang SEBENARNYA di balik slot ini. Tulisan kertasnya
            // nominal botol lama, jadi tanpa baris ini teknisi bisa menuang
            // botol yang salah — lihat `SlotCetak`.
            Text(
              _subLabelSlot(slot, l10n),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu pilihan satuan di kepala slot — `1413 µS` atau `1.413 mS`.
///
/// Digambar sendiri, bukan pakai [ChoiceChip]. Bukan soal selera: padding,
/// densitas, dan ukuran tap-target chip diputus theme, jadi lebarnya nggak bisa
/// diukur dari luar. Waktu masih chip, dua pilihan minta 265px di kolom 156px
/// dan meluber 109px keluar kotaknya — kepala tabel Conductivity kelihatan
/// belang kuning-hitam di HP.
///
/// Bentuknya tetap "pil kepilih vs nggak", dan yang kepilih dibedain dari WARNA
/// & LATAR, bukan dari ketebalan huruf: tebal huruf ngubah lebar teks, dan lebar
/// itu yang barusan diukur.
class _PilSatuan extends StatelessWidget {
  const _PilSatuan({
    required this.teks,
    required this.dipilih,
    required this.onTekan,
  });

  final String teks;
  final bool dipilih;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: dipilih,
      button: true,
      child: InkWell(
        onTap: onTekan,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _selaPilX,
            vertical: _selaPilY,
          ),
          decoration: BoxDecoration(
            color: dipilih ? theme.colorScheme.secondaryContainer : null,
            // Yang nggak kepilih pakai `outline`, bukan `outlineVariant`:
            // di theme terang, varian-nya nyaris nggak kelihatan di atas
            // permukaan kepala tabel, dan pilihan yang nggak kelihatan sebagai
            // KOTAK kebaca teknisi sebagai tulisan biasa — bukan sesuatu yang
            // bisa dipencet.
            border: Border.all(
              color: dipilih
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.outline,
              width: _garisPil,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            teks,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: dipilih
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
    this.label,
  });

  final int nomor;
  final List<KolomTabelHasil> kolom;
  final double lebarSel;

  /// Tulisan kepala yang datang UTUH dari backend — `UP X1`, `DOWN X3`.
  ///
  /// Menang atas [prefiks] dan atas `Repeat n` bawaan: arah pembacaan itu
  /// bagian dari kertasnya, dan layar nggak boleh nurunin sendiri dari nomor
  /// (kalau lab suatu saat baca empat kali per arah, hitungannya salah).
  final String? label;

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
              label ??
                  (prefiks == null
                      ? '${l10n.lkRepeat} $nomor'
                      : '$prefiks$nomor'),
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
                    // Sama alasannya dengan `FittedBox` di atas, dan ini
                    // kelanjutan bolongnya: dulu cuma teks "Repeat N" yang
                    // dijaga, label kolomnya nggak. Selama tiap tabel
                    // berkolom-satu kebetulan pakai `prefiks_pengulangan`
                    // (Spectrophotometer pakai `X`), baris label ini memang
                    // nggak pernah digambar dan bolongnya nggak kelihatan.
                    //
                    // Gas Detector yang pertama berkolom satu TANPA prefiks:
                    // lebar kepalanya cuma `lebarSel` × 1, dan labelnya bikin
                    // kolom ini lewat dari `_tinggiKepala` yang dipatok — 3,6px
                    // yang keluar sebagai garis loreng kuning-hitam di layar
                    // teknisi, bukan sebagai error.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        k.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
    this.onKetuk,
    this.maksBaris,
  });

  final double lebar;
  final String teks;
  final double tinggi;
  final bool kiri;

  /// Batas baris [teks]. Null = nggak dibatasi sama sekali — persis kelakuan
  /// sel kepala sebelum lembar suhu masuk, dan itu yang bikin golden empat
  /// belas lembar lama tetap cocok.
  ///
  /// Disetel EKSPLISIT oleh kepala gabungan, yang jatah tingginya cuma 26 dp —
  /// muat satu baris, nggak muat dua. Lihat pemakaiannya.
  final int? maksBaris;

  /// Keterangan kecil di bawah label — dipakai buat bilang kenapa baris ini
  /// dikunci (alternatif satuan dari botol yang sama).
  ///
  /// SENGAJA pendek. Sel ini mangkas di 2 baris (`maxLines: 2` + ellipsis) di
  /// kolom selebar maksimal 152 dp, jadi kalimat panjang kepotong tepat di
  /// bagian yang menjelaskan. Cara ngeganti satuannya dipindah ke [onKetuk].
  final String? catatan;

  /// Dipanggil waktu label baris terkunci diketuk.
  ///
  /// Baris yang mati tanpa jalan keluar itu jalan buntu: teknisi lihat kotak
  /// abu, baca catatan yang kepotong, dan nggak punya cara tau kalau baris ini
  /// kebuka sendiri begitu baris pasangannya dikosongin.
  final VoidCallback? onKetuk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isi = Align(
        alignment: kiri ? Alignment.centerLeft : Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              kiri ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              teks,
              // Dibatasi HANYA kalau yang manggil minta dibatasi.
              //
              // Sempat dipasang batas bawaan `catatan == null ? 2 : 1` buat
              // semua sel. Itu salah, dan salahnya nggak kelihatan dari lembar
              // yang lagi dikerjain: sel kepala yang labelnya membungkus jadi
              // ikut kena `textAlign: center`, dan golden
              // `lembar-kerja-spectrophotometer.png` geser 0,15% (4923 px) —
              // di atas ambang 0,10%. Empat belas lembar lain nggak kegeser
              // cuma karena label kepalanya kebetulan muat satu baris.
              //
              // Jadi bawaannya dibalikin persis kayak sebelumnya: nggak ada
              // batas baris, nggak ada ellipsis, nggak ada `textAlign`. Yang
              // butuh dipangkas minta sendiri lewat [maksBaris].
              maxLines: maksBaris,
              overflow: maksBaris == null ? null : TextOverflow.ellipsis,
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
      );

    return SizedBox(
      width: lebar,
      height: tinggi,
      child: onKetuk == null
          ? isi
          : InkWell(onTap: onKetuk, child: isi),
    );
  }
}

class _SelAngka extends StatelessWidget {
  const _SelAngka({
    required this.lebar,
    required this.tinggi,
    required this.controller,
    this.tanda = TandaSel.tidakAda,
    this.terkunci = false,
  });

  final double lebar;

  /// Dikirim dari luar, bukan konstanta: harus PERSIS setinggi sel label di
  /// kolom nempel sebelah kiri, atau barisnya lari sendiri-sendiri.
  final double tinggi;
  final TextEditingController controller;

  /// Penanda yang nempel di sel ini. Bukan ngunci apa-apa — cuma pengingat
  /// visual, dan selnya tetap bisa diketik.
  ///
  /// Dua warna buat dua arti yang beda, dan bedanya penting:
  /// **kuning** = mesin nggak yakin waktu mindai, tolong dicek.
  /// **merah** = admin bilang angka INI yang salah.
  ///
  /// Yang merah itu yang bikin revisi berhenti jadi "ulangi tabelnya": teknisi
  /// lihat persis kotak mana yang diminta, dan sisa tabelnya — yang sudah dia
  /// isi benar — tetap berdiri.
  final TandaSel tanda;

  /// Baris pasangannya udah mulai diisi, jadi baris ini nggak boleh diisi.
  /// Tetap KELIHATAN — cuma nggak bisa diketik — supaya teknisi paham ini
  /// alternatif satuan dari botol yang sama, bukan titik yang hilang.
  final bool terkunci;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dua-duanya dipatok, bukan diambil dari skema tema: yang merah HARUS beda
    // jelas dari yang kuning di layar HP di bawah lampu bengkel, dan
    // `colorScheme.error` di tema terang ini terlalu dekat ke ambernya.
    final warna = switch (tanda) {
      TandaSel.tidakAda => null,
      // Amber gelap, kebaca di light & dark.
      TandaSel.keyakinanRendah => kuningPerluDicek,
      TandaSel.revisi => const Color(0xFFC62828),
    };

    final borderTanda = warna == null
        ? null
        : OutlineInputBorder(
            borderSide: BorderSide(color: warna, width: 1.5),
          );

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
            filled: warna != null || terkunci,
            fillColor: warna != null
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
    this.judulGabungan = false,
    this.serempak = const [],
  });

  final String label;
  final TitikState state;
  final VoidCallback onBerubah;

  /// Baris ini mewakili SELURUH titik, bukan titik [label] doang — judulnya
  /// nyebut "Semua titik", bukan satu nilai titik yang kebetulan paling atas.
  final bool judulGabungan;

  /// Titik lain yang ikut berubah bareng [state]. Isi cuma waktu satu standar
  /// melayani semua titik; kosong = perilaku lama, satu baris satu titik.
  final List<TitikState> serempak;

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
        judul: widget.judulGabungan
            ? l10n.lkStandarSemuaTitikDipakai(state.standardNama!)
            : l10n.lkStandarTitikDipakai(widget.label, state.standardNama!),
        subjudul: l10n.lkStandarTitikTercetak,
        nilai: state.standarTercetakDipakai,
        onUbah: (dicentang) {
          setState(() {
            for (final t in [state, ...widget.serempak]) {
              t.standardId = dicentang ? t.standardIdTercetak : null;
            }
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
      // Ganti manual di baris gabungan mesti nyeret titik lain juga —
      // kalibratornya satu, jadi nggak ada keadaan sah di mana titik 1000 °C
      // pakai kalibrator lain dari titik -20 °C tanpa teknisi milihnya.
      serempak: widget.serempak,
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
    this.serempak = const [],
  });

  final String label;
  final TitikState state;
  final VoidCallback onBerubah;

  /// Titik lain yang ikut kena pilihan ini. Kosong = cuma [state], persis
  /// kayak dulu. Lihat [_PilihStandarTitik.serempak].
  final List<TitikState> serempak;

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
          // Tinggi baris menu ngikutin isinya: nama dua baris plus
          // baris peringatan lewat dari jatah tetap 48 dp.
          itemHeight: null,
          decoration: InputDecoration(
            isDense: true,
            labelText: '${l10n.lkStandarPerTitik} $label',
            border: const OutlineInputBorder(),
          ),
          hint: Text(l10n.lkPilih),
          selectedItemBuilder: (_) => [
            for (final Standard s in urut) LabelStandarDropdown.namaSaja(s),
          ],
          items: [
            for (final Standard s in urut)
              DropdownMenuItem(
                value: s.id,
                enabled: s.masihBerlaku,
                child: LabelStandarDropdown(standard: s),
              ),
          ],
          onChanged: (value) {
            for (final t in [state, ...serempak]) {
              t.standardId = value;
            }
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
/// Keterangan sebaris di atas tabel — dipakai buat tabel yang isinya belum
/// punya tempat di server ([TabelHasil.tanpaTempatSimpan]).
class _CatatanTabel extends StatelessWidget {
  const _CatatanTabel({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              teks,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom kiri buat baris yang set point-nya BELUM ditentukan — kotak isian,
/// bukan label.
///
/// Cuma lembar TIDS yang punya (`SIDIK-FM-CAL-0506 Rev.4`): kertasnya mencetak
/// tujuh baris `Setpoint` kosong. Sembilan belas lembar lain set point-nya
/// tercetak, dan kolom ini tetap label mati seperti dulu.
///
/// **Baris yang kotaknya dibiarkan kosong nggak ikut dikirim.** Baris tanpa set
/// point nggak punya identitas buat dihitung — lihat `TitikState.siapKirim`.
class _SelSetpoint extends StatelessWidget {
  const _SelSetpoint({
    required this.lebar,
    required this.tinggi,
    required this.state,
    required this.satuan,
    required this.onBerubah,
  });

  final double lebar;
  final double tinggi;
  final TitikState? state;
  final String satuan;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: lebar,
      height: tinggi,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: state == null
          ? const SizedBox.shrink()
          : TextField(
              controller: state!.titikCtl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                // Batasan yang SAMA dengan sel pembacaan — bukan sekadar
                // "karakternya boleh ini".
                //
                // Daftar karakter meloloskan `12..5`, `1-2`, `--3`. Bentuk
                // begitu bikin `parseAngka` pulang null, `siapKirim` jadi
                // false, dan SELURUH barisnya — lima kotak pembacaan yang
                // sudah diisi sekalian — hilang dari yang dikirim tanpa satu
                // pun tanda. Pola berjangkar begini cuma menerima awalan yang
                // masih bisa jadi angka.
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: satuan,
                hintStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onBerubah(),
            ),
    );
  }
}

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

  /// Tulisan kepala kolom pengulangan yang TERCETAK di kertas, per nomor.
  ///
  /// Tiga sumber, dan yang mana yang menang menentukan benar-salahnya angka:
  ///
  ///  1. **`pengulangan_arah[].label`** — tulisan yang SERVER bilang kecetak
  ///     di atas kolom itu, dan tulisan yang sama persis digambar layar ini
  ///     sebagai kepala kolomnya (`label:` di `_KepalaPengulangan`).
  ///  2. `prefiks_pengulangan` (`X` bikin `X1`) — dikirim Spectrophotometer.
  ///  3. Bawaan [PetaTabelFoto.kepalaBawaan] (`Xn` / `Repeat n`).
  ///
  /// **Begitu (1) menyebut sesuatu yang bukan `Xn`, dia SENDIRIAN.** Kepala
  /// kolom TITS kecetak `UP X1` … `DOWN X3`, dan ML Kit membacanya per KATA —
  /// jadi potongan `X1` muncul DUA kali, sekali di bawah `UP` dan sekali di
  /// bawah `DOWN`. Selama `Xn` ikut jadi calon, jangkar Repeat 1 bisa mendarat
  /// di kolom DOWN, dan yang masuk ke situ pembacaan arah sebaliknya. Nggak ada
  /// error, jumlah selnya pas, angkanya wajar — persis bentuk kegagalan yang
  /// paling mahal di fitur ini. Yang tahu bentuk kertasnya server; begitu dia
  /// bicara, tebakan nggak boleh ikut bersuara.
  ///
  /// Kalau labelnya justru `Xn` itu sendiri (Thermohygro — `tabelPembacaan` di
  /// server memberinya sebagai NILAI BAWAAN, bukan pernyataan soal kertasnya),
  /// dia nggak menggantikan apa-apa: `Repeat n` tetap ikut diterima seperti
  /// sebelumnya.
  ///
  /// Yang belum pernah kejangkar sama sekali sebelum ini: **TITS** (`UP X1`…)
  /// dan **Thermocouple / Termometer Gelas** (`0″ 20″ 40″ 60″ 80″` di sisi
  /// standar, `10″ 30″ 50″ 70″ 90″` di sisi UUT). Ketiganya nyetak kepala kolom
  /// yang bukan `Xn`, bukan `Repeat n`, dan bukan nomor polos — jadi ketiga
  /// jalur jangkar kolom yang ada semuanya lewat, dan tiap jepretan pulang NOL
  /// SEL sebagus apa pun fotonya. Yang sampai ke teknisi bukan "kolomnya nggak
  /// kebaca", tapi "tabelnya masih kosong" — nyuruh dia mengisi lembar yang
  /// sudah penuh di tangannya.
  Map<int, List<String>> _kepalaPengulangan() {
    final prefiks = widget.tabel.prefiksPengulangan;
    final arah = widget.tabel.pengulanganArah;

    if (prefiks == null && arah.isEmpty) return const {};

    return {
      for (final r in widget.tabel.pengulangan) r: _kepalaSatuKolom(r, prefiks),
    };
  }

  /// Calon tulisan kepala buat SATU kolom pengulangan — lihat
  /// [_kepalaPengulangan] soal kenapa label kertas menang sendirian.
  List<String> _kepalaSatuKolom(int r, String? prefiks) {
    final label = widget.tabel.pengulanganArah[r];
    final bawaan = [
      if (prefiks != null) '$prefiks$r',
      ...PetaTabelFoto.kepalaBawaan(r),
    ];

    if (label == null || label.isEmpty) return bawaan;

    return bawaan.contains(label) ? bawaan : [label];
  }

  /// Slot larutan seperti TERCETAK, buat lembar yang Repeat-nya turun ke bawah.
  ///
  /// Titik tujuannya diambil dari [LembarKerjaState.titikAktifSlot] — slot
  /// bersatuan dobel nunjuk titik yang lagi dicentang teknisi, bukan ditebak
  /// dari angka yang kebaca.
  List<SlotFoto> _slotFoto() => [
    for (var i = 0; i < widget.tabel.slotCetak.length; i++)
      (
        titikUkur: widget.isian.titikAktifSlot(
          widget.tabel.kunciTabel,
          i,
          widget.tabel.slotCetak[i],
        ),
        kepala: [
          widget.tabel.slotCetak[i].label,
          if (widget.tabel.slotCetak[i].varian != null)
            widget.tabel.slotCetak[i].varian!,
        ],
        labelField: {
          for (final k in widget.tabel.kolom)
            k.kode: k.kode == 'suhu'
                ? (k.satuan ?? '°C')
                : (widget.tabel.slotCetak[i].satuan ?? k.label),
        },
      ),
  ];

  Future<void> _foto() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sibuk = true);

    try {
      // Ambil & bacanya lewat helper bersama — tiga tombol memakainya sekarang
      // (tabel di sini, grid Enclosure, matriks Autoklaf), dan dua angka di
      // dalamnya punya alasan yang mahal kalau ikut disalin salah. Lihat
      // `services/ambil_foto_tabel.dart`.
      final foto = await ambilDanBacaTabel(ref);

      if (!mounted || foto.dibatalkan) return;

      if (foto.terbaca == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.lkFotoTabelGagal)));

        return;
      }

      final HasilPetaTabel hasil;

      {
        final terbaca = foto.terbaca!;

        // Lembar yang Repeat-nya turun ke bawah (Conductivity) dipetakan lewat
        // jalur sendiri: di kertasnya nomor Repeat dan slot larutan ada di
        // sumbu yang KEBALIK dari bentuk pH, jadi jalur biasa nggak nemu satu
        // jangkar pun dan seluruh angkanya kebuang.
        if (widget.tabel.pengulanganKeBawah &&
            widget.tabel.slotCetak.isNotEmpty) {
          hasil = const PetaTabelFoto().petakanKeBawah(
            terbaca: terbaca,
            slot: _slotFoto(),
            pengulangan: widget.tabel.pengulangan,
            kepalaPengulangan: _kepalaPengulangan(),
          );
        } else {
          // Titik TABEL INI, bukan seluruh lembar. Spectrophotometer punya tiga
          // tabel dengan titik beda-beda (10 nm + 9 nm + 5 %T); ngasih seluruh
          // titik bikin nilai `20,0 %T` bisa nyamar jadi jangkar baris nm.
          final titik = widget.isian.titikTabel(widget.tabel);

          hasil = const PetaTabelFoto().petakan(
            terbaca: terbaca,
            titikUkur: [for (final t in titik) t.titikUkur],
            pengulangan: widget.tabel.pengulangan,
            fieldPerRepeat: [for (final k in widget.tabel.kolom) k.kode],
            labelField: {
              for (final k in widget.tabel.kolom) k.kode: k.label,
            },
            // Viscometer: kertas nyetak label larutan bulat ("1000"), bukan
            // nilai sertifikat (1018) — lihat komentar `labelTercetak` di
            // `PetaTabelFoto.petakan`. Alat lain labelnya == nilainya, jadi
            // ini nggak ngubah apa-apa buat mereka.
            labelTercetak: {
              for (final t in titik) t.titikUkur: t.label,
            },
            kepalaPengulangan: _kepalaPengulangan(),
            ukuranCitra: foto.ukuran,
          );
        }
      }

      if (!mounted) return;

      if (hasil.kosong) {
        // Nol sel bukan "OCR-nya jelek" — biasanya yang kefoto bukan tabelnya,
        // atau kolom jangkarnya nggak ikut masuk frame. Pesannya nyebut itu,
        // karena mengulang jepretan yang sama nggak akan menolong.
        //
        // Jangkarnya beda per bentuk kertas, jadi petunjuknya juga beda:
        // nyuruh teknisi mastiin "kepala kolom X1" di lembar Conductivity itu
        // nunjuk sesuatu yang emang nggak ada di kertasnya.
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(
              // Label sub-kolom yang hilang disebut NAMANYA. Sebabnya beda
              // dari jangkar baris/kolom yang kepotong, dan nyuruh teknisi
              // "pastikan kolom nilai standar kefoto" waktu yang hilang
              // sebenarnya baris satuan itu nyuruh dia mbenerin hal yang
              // udah bener.
              // Bentuk tabelnya sendiri yang nggak bisa dipetakan: ada
              // penanda baris yang kembar, jadi angkanya nggak bisa
              // dipastikan masuk baris yang mana. Disebut duluan dan disebut
              // beda, karena ini satu-satunya sebab di daftar ini yang
              // JEPRETAN ULANGNYA NGGAK NOLONG — yang harus dibetulin master
              // lembarnya, bukan fotonya.
              hasil.barisKembar.isNotEmpty
                  ? l10n.lkFotoTabelBarisKembar(
                      hasil.barisKembar.map(_angkaTampil).join(', '),
                    )
                  : hasil.labelKolomKurang.isNotEmpty
                  ? l10n.lkFotoTabelKolomHilang(
                      hasil.labelKolomKurang.join(' & '),
                    )
                  // Jangkarnya ketemu SEMUA, cuma badan tabelnya nggak ada
                  // angkanya — kertas yang difoto memang belum diisi. Nyuruh
                  // teknisi "pastikan kolom nilai standar kefoto" di sini
                  // bikin dia motret ulang lembar yang sama berkali-kali,
                  // karena yang disuruh perbaiki udah bener dari tadi.
                  : (hasil.titikKetemu.isNotEmpty &&
                        hasil.repeatKetemu.isNotEmpty)
                  ? l10n.lkFotoTabelKosong
                  : widget.tabel.pengulanganKeBawah
                  ? l10n.lkFotoTabelTanpaJangkarKeBawah
                  : l10n.lkFotoTabelTanpaJangkar,
            ),
          ),
        );

        return;
      }

      final terisi = widget.isian.terapkanHasilFotoTabel(
        hasil.sel,
        tahap: widget.tabel.kunciTabel,
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
