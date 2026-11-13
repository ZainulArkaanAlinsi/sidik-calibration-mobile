import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_kamera.dart';
import '../../l10n/app_localizations.dart';
import '../../services/kamera_pindai.dart';
import '../../services/pesan_galat_pindai.dart' show catatGalatPindai;
import '../../services/petunjuk_kamera.dart';

/// Buka layar kamera sendiri di atas [navigator] dan tunggu hasilnya.
///
/// Ditutup tanpa memotret (tombol tutup / tombol kembali) = [KameraDibatalkan],
/// bukan galat. Navigator tidak ada = [KameraTakBisa] (pemanggil jatuh ke
/// cadangan).
Future<HasilKamera> bukaKameraPindai({
  required NavigatorState? navigator,
  required PabrikKontrolKamera pabrik,
  double? rasioKertas,
  PengukurFrame? pengukur,
}) async {
  if (navigator == null || !navigator.mounted) {
    return const KameraTakBisa(SebabKameraGagal.gagalMulai);
  }

  final hasil = await navigator.push<HasilKamera>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => KameraPindaiScreen(
        pabrik: pabrik,
        rasioKertas: rasioKertas,
        pengukur: pengukur ?? ukurFrameDiIsolate,
      ),
    ),
  );

  return hasil ?? const KameraDibatalkan();
}

/// Bingkai panduan di dalam [area]. [rasio] (lebar ÷ tinggi halaman) dipasang
/// sebesar mungkin di dalam area dengan sisa [TokenKamera.sisaBingkai] di tiap
/// sisi; tanpa rasio bingkainya netral (hampir sepenuh area) karena bentuk
/// halamannya tidak diketahui.
@visibleForTesting
Rect hitungBingkaiPanduan(Size area, double? rasio) {
  const sisa = TokenKamera.sisaBingkai;
  final w = area.width * (1 - 2 * sisa);
  final h = area.height * (1 - 2 * sisa);
  final pusat = Offset(area.width / 2, area.height / 2);

  if (rasio == null || !rasio.isFinite || rasio <= 0) {
    return Rect.fromCenter(center: pusat, width: w, height: h);
  }

  var lebar = w;
  var tinggi = lebar / rasio;
  if (tinggi > h) {
    tinggi = h;
    lebar = tinggi * rasio;
  }

  return Rect.fromCenter(center: pusat, width: lebar, height: tinggi);
}

enum _Fase { memuat, siap, menjeda, izinDitolak }

/// Layar kamera "Foto lembar kerja": pratinjau penuh, bingkai panduan, senter,
/// ketuk-untuk-fokus, dan petunjuk langsung (gelap/buram/silau/terpotong).
///
/// Layar ini TIDAK membaca teks dan tidak mengunggah apa pun: ia hanya
/// memotret. Pembacaan, gerbang mutu (`AmbangMutu`), dan tinjauan teknisi
/// tetap di alur pindai sesudahnya. Petunjuk hanyalah saran — tombol jepret
/// tidak pernah dikunci oleh petunjuk, dan senter tidak pernah dinyalakan
/// sendiri.
///
/// ## Tata letak
///
/// Satu aksi utama: tombol jepret besar di tepi ibu jari (tengah bawah di HP
/// tegak; sisi kanan di lanskap/tablet). Senter di sebelahnya, tombol tutup di
/// pojok kiri atas. Semua teks & tombol berdiri di atas dasar gelap
/// semi-buram (`TokenKamera.dasarLapisan`), karena pratinjau bisa selembar
/// kertas putih. Hanya token tema: bahan KACA `SidikMaterial`, `AppSpacing`,
/// `TokenKamera` — tanpa warna/ukuran mentah.
///
/// Hasilnya lewat `Navigator.pop` berupa [HasilKamera]; kamera dilepas saat
/// layar dibuang dan saat aplikasi ke latar (dibuka lagi saat kembali).
///
/// Izin kamera ditolak = keadaan layar sendiri (langkah berikutnya, termasuk
/// jalur manual di Pengaturan, + "Coba lagi"), bukan layar kosong. TIDAK ada
/// tombol ke kamera sistem: `image_picker` meminta izin CAMERA yang sama, jadi
/// berujung galat. Kamera tidak ada atau gagal dibuka = layar menutup dengan
/// [KameraTakBisa] dan pemanggil jatuh ke cadangan.
class KameraPindaiScreen extends StatefulWidget {
  const KameraPindaiScreen({
    super.key,
    required this.pabrik,
    this.rasioKertas,
    this.selangContoh = AmbangFotoLembar.selangContoh,
    this.pengukur = ukurFrameDiIsolate,
  });

  final PabrikKontrolKamera pabrik;

  /// Lebar ÷ tinggi halaman lembar kerja (dari templat), atau `null`.
  final double? rasioKertas;

  /// Jeda antar contoh frame untuk petunjuk.
  final Duration selangContoh;

  /// Pengukur frame — bawaan di isolate lain (tidak menahan frame UI).
  final PengukurFrame pengukur;

  @override
  State<KameraPindaiScreen> createState() => _KameraPindaiScreenState();
}

class _KameraPindaiScreenState extends State<KameraPindaiScreen>
    with WidgetsBindingObserver {
  final _penyaring = PenyaringPetunjuk();

  KontrolKamera? _kontrol;
  _Fase _fase = _Fase.memuat;
  bool _aktif = true;
  bool _sedangMulai = false;
  bool _selesai = false;
  bool _memotret = false;
  bool _senterTersedia = false;
  bool _senterNyala = false;
  bool _contohMati = false;

  /// App sempat ke latar (bukan sekadar dialog izin) sejak izin ditolak —
  /// mis. teknisi mengaktifkannya di Pengaturan. Hanya itu yang membuka kamera
  /// otomatis saat kembali; dialog izin yang baru ditolak tidak boleh memicu
  /// dialog kedua.
  bool _latarSejakDitolak = false;

  PetunjukKamera? _petunjuk;
  Offset? _titikFokus;

  /// Pesan sesaat (jepret gagal, senter tidak ada). Di layar, BUKAN snackbar:
  /// snackbar menutupi tombol jepret di tepi bawah.
  String? _pesan;

  Timer? _timerContoh;
  Timer? _timerFokus;
  Timer? _timerPesan;
  Future<void>? _contohBerjalan;

  /// Pelepasan kamera yang sedang berjalan ([_jeda]). [_mulai] menunggunya:
  /// `dispose` plugin memanggil `unbindAll()` global, jadi membuka kamera baru
  /// selagi yang lama belum selesai dilepas bisa saling membatalkan.
  Future<void>? _pelepasan;

  /// Berapa contoh frame berturut-turut yang tidak pernah datang. Mencapai
  /// [AmbangFotoLembar.contohKosongMaks] = petunjuk langsung dihentikan.
  int _contohKosong = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_mulai());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerContoh?.cancel();
    _timerFokus?.cancel();
    _timerPesan?.cancel();
    final k = _kontrol;
    _kontrol = null;
    if (k != null) unawaited(k.lepas());
    super.dispose();
  }

  // ---- Siklus hidup kamera ----------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _aktif = true;
      if (_fase == _Fase.izinDitolak) {
        if (_latarSejakDitolak && !_sedangMulai) {
          _latarSejakDitolak = false;
          unawaited(_mulai());
        }

        return;
      }
      if (_kontrol == null && !_sedangMulai && !_selesai) unawaited(_mulai());
    } else {
      if (_fase == _Fase.izinDitolak &&
          (state == AppLifecycleState.paused ||
              state == AppLifecycleState.hidden)) {
        _latarSejakDitolak = true;
      }
      _jeda();
    }
  }

  /// App ke latar / kehilangan fokus: kamera HARUS dilepas (dipakai app lain,
  /// baterai, dan batas sistem). Dibuka lagi di [didChangeAppLifecycleState].
  void _jeda() {
    _aktif = false;
    _timerContoh?.cancel();
    final k = _kontrol;
    if (k == null) return; // Sedang membuka: [_mulai] melepasnya sendiri.

    _kontrol = null;
    if (mounted) {
      setState(() {
        _fase = _Fase.menjeda;
        _petunjuk = null;
        _senterNyala = false;
      });
    }
    _pelepasan = k.lepas();
  }

  Future<void> _mulai() async {
    if (_sedangMulai || _kontrol != null) return;
    _sedangMulai = true;
    if (_fase != _Fase.memuat) setState(() => _fase = _Fase.memuat);

    // Tunggu kamera yang lama benar-benar terlepas sebelum membuka yang baru.
    final pelepasan = _pelepasan;
    if (pelepasan != null) {
      try {
        await pelepasan;
      } catch (_) {
        // Gagal melepas tidak menghalangi membuka lagi.
      }
      if (identical(_pelepasan, pelepasan)) _pelepasan = null;
      if (!mounted) {
        _sedangMulai = false;
        return;
      }
    }

    final KontrolKamera k;
    try {
      k = await widget.pabrik();
    } on KameraGagal catch (e, st) {
      _sedangMulai = false;
      if (e.sebab == SebabKameraGagal.izinDitolak) {
        // Keadaan biasa, bukan galat yang dilaporkan: layar menjelaskan
        // langkah berikutnya dan teknisi yang memilih.
        if (mounted) {
          setState(() {
            _fase = _Fase.izinDitolak;
            _latarSejakDitolak = false;
          });
        }

        return;
      }
      catatGalatPindai('kamera-buka', e.detail ?? e, st);
      _tutup(KameraTakBisa(e.sebab, e.detail));
      return;
    } catch (e, st) {
      _sedangMulai = false;
      catatGalatPindai('kamera-buka', e, st);
      _tutup(KameraTakBisa(SebabKameraGagal.gagalMulai, e));
      return;
    }

    // Layar dibuang atau app ke latar selagi kamera dibuka (mis. dialog izin).
    // [_sedangMulai] baru turun SESUDAH kamera terlepas: kembalinya app ke
    // depan di tengah pelepasan tidak boleh membuka kamera kedua.
    if (!mounted || !_aktif) {
      await k.lepas();
      _sedangMulai = false;
      if (mounted) {
        setState(() => _fase = _Fase.menjeda);
        if (_aktif && _kontrol == null) unawaited(_mulai());
      }
      return;
    }
    _sedangMulai = false;

    _penyaring.ulang();
    _contohKosong = 0;
    setState(() {
      _kontrol = k;
      _fase = _Fase.siap;
      _senterTersedia = k.senterTersedia;
      _senterNyala = false;
      _petunjuk = null;
    });
    if (k.bisaContoh && !_contohMati) _jadwalkanContoh();
  }

  void _tutup(HasilKamera hasil) {
    if (_selesai || !mounted) return;
    _selesai = true;
    Navigator.of(context).pop(hasil);
  }

  // ---- Petunjuk langsung ------------------------------------------------------

  void _jadwalkanContoh() {
    _timerContoh?.cancel();
    _timerContoh = Timer(widget.selangContoh, () {
      _contohBerjalan = _ambilContoh();
    });
  }

  /// SATU contoh frame, ukur, lalu jadwalkan berikutnya. Galat di sini hanya
  /// mematikan petunjuk (kamera tetap bisa memotret).
  Future<void> _ambilContoh() async {
    final k = _kontrol;
    if (k == null || !mounted || _memotret) return;

    try {
      final frame = await k.ambilContoh();
      if (!mounted || !identical(_kontrol, k)) return;

      if (frame == null) {
        // Frame tak pernah datang (aliran frame tak jalan di HP ini): jangan
        // memutar start/stop tanpa henti. Berhenti dan beri saran netral.
        _contohKosong++;
        if (_contohKosong >= AmbangFotoLembar.contohKosongMaks) {
          _contohMati = true;
          _tampilkanPesan(AppLocalizations.of(context).lkKameraPetunjukMati);

          return;
        }
      } else {
        _contohKosong = 0;
      }

      final ukuran = frame == null ? null : await widget.pengukur(frame);
      if (!mounted || !identical(_kontrol, k)) return;
      if (ukuran != null) {
        final saran = _penyaring.masukkan(
          petunjukDari(
            ukuran,
            senterTersedia: _senterTersedia,
            senterNyala: _senterNyala,
          ),
        );
        if (saran != _petunjuk) setState(() => _petunjuk = saran);
      }
    } catch (e, st) {
      // Kamera dilepas (app ke latar / layar ditutup) selagi contoh diminta:
      // galat itu akibat pelepasan, bukan tanda aliran frame tidak didukung.
      if (!mounted || !identical(_kontrol, k)) return;
      catatGalatPindai('kamera-contoh', e, st);
      _contohMati = true;
      if (_petunjuk != null) setState(() => _petunjuk = null);
      return;
    }

    if (mounted && identical(_kontrol, k) && !_memotret) _jadwalkanContoh();
  }

  // ---- Aksi ------------------------------------------------------------------

  Future<void> _gantiSenter() async {
    final k = _kontrol;
    if (k == null) return;

    final target = !_senterNyala;
    final berhasil = await k.aturSenter(target);
    if (!mounted || !identical(_kontrol, k)) return;

    _penyaring.ulang();
    setState(() {
      _petunjuk = null;
      if (berhasil) {
        _senterNyala = target;
      } else {
        _senterNyala = false;
        _senterTersedia = k.senterTersedia;
      }
    });

    if (!berhasil && target) {
      _tampilkanPesan(AppLocalizations.of(context).lkKameraSenterTidakAda);
    }
  }

  void _tampilkanPesan(String teks) {
    setState(() => _pesan = teks);
    _timerPesan?.cancel();
    _timerPesan = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _pesan = null);
    });
  }

  void _ketukFokus(Offset lokal, Size ukuran) {
    final k = _kontrol;
    if (k == null || ukuran.isEmpty) return;

    final titik = Offset(
      (lokal.dx / ukuran.width).clamp(0.0, 1.0),
      (lokal.dy / ukuran.height).clamp(0.0, 1.0),
    );
    setState(() => _titikFokus = lokal);
    _timerFokus?.cancel();
    _timerFokus = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _titikFokus = null);
    });
    unawaited(k.fokusDi(titik));
  }

  Future<void> _jepret() async {
    final k = _kontrol;
    if (k == null || _memotret) return;

    setState(() => _memotret = true);
    _timerContoh?.cancel();
    // Contoh frame yang sedang jalan selesai dulu: kamera tidak boleh
    // diminta mengalirkan frame dan memotret bersamaan.
    try {
      await _contohBerjalan;
    } catch (_) {
      // Galatnya sudah ditangani di _ambilContoh.
    }

    File berkas;
    try {
      berkas = await k.jepret();
    } catch (e, st) {
      catatGalatPindai('kamera-jepret', e, st);
      if (!mounted) return;
      setState(() => _memotret = false);
      _tampilkanPesan(AppLocalizations.of(context).lkKameraJepretGagal);
      if (identical(_kontrol, k) && k.bisaContoh && !_contohMati) {
        _jadwalkanContoh();
      }
      return;
    }

    if (!mounted || _selesai) {
      // Layar sudah ditutup selagi memotret: foto lembar pelanggan tidak
      // boleh tertinggal di cache.
      try {
        await berkas.delete();
      } catch (_) {
        // Disapu `sapuBerkasPindaiLama` di pindai berikutnya.
      }
      return;
    }

    _tutup(KameraFoto(berkas));
  }

  // ---- Tampilan --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return PopScope(
      canPop: !_memotret,
      child: Scaffold(
        backgroundColor: m.kaca,
        body: LayoutBuilder(
          builder: (context, c) {
            final lanskap = c.maxWidth > c.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (_fase == _Fase.izinDitolak)
                  _PanelIzin(onCobaLagi: _cobaLagi)
                else ...[
                  _bangunPratinjau(context, m),
                  lanskap ? _bangunLanskap(context) : _bangunTegak(context),
                ],
                // Tombol tutup selalu ada, di pojok kiri atas.
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: _TombolBulat(
                        key: const ValueKey('kamera-tutup'),
                        ikon: Icons.close,
                        label: AppLocalizations.of(context).lkKameraTutup,
                        onPressed: () => _tutup(const KameraDibatalkan()),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bantuan penempatan lembar. Tanpa rasio halaman (foto satu tabel) kalimatnya
  /// tidak boleh menyebut "seluruh halaman".
  String _teksBantuan(AppLocalizations l10n) => widget.rasioKertas == null
      ? l10n.lkKameraBantuanAlasTabel
      : l10n.lkKameraBantuanAlas;

  void _cobaLagi() {
    setState(() => _fase = _Fase.memuat);
    unawaited(_mulai());
  }

  Widget _bangunPratinjau(BuildContext context, SidikMaterial m) {
    final k = _kontrol;
    if (k == null || _fase != _Fase.siap) {
      return Center(
        child: _fase == _Fase.memuat
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: m.lcdTeks),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppLocalizations.of(context).lkKameraMemuat,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: m.lcdTeks),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      );
    }

    return Center(
      child: k.bangunPratinjau(
        context,
        lapisan: LayoutBuilder(
          builder: (context, c) {
            final ukuran = c.biggest;

            return GestureDetector(
              key: const ValueKey('kamera-sentuh'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _ketukFokus(d.localPosition, ukuran),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    key: const ValueKey('kamera-bingkai'),
                    painter: _PelukisBingkai(
                      bingkai: hitungBingkaiPanduan(ukuran, widget.rasioKertas),
                      redaman: m.kaca.withValues(
                        alpha: TokenKamera.redamanBingkai,
                      ),
                      sudut: m.lcdTeks,
                      tepi: m.kaca,
                    ),
                  ),
                  if (_titikFokus case final t?)
                    Positioned(
                      left: t.dx - TokenKamera.cincinFokus / 2,
                      top: t.dy - TokenKamera.cincinFokus / 2,
                      child: IgnorePointer(
                        child: Container(
                          key: const ValueKey('kamera-cincin-fokus'),
                          width: TokenKamera.cincinFokus,
                          height: TokenKamera.cincinFokus,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: m.lcdAmber,
                              width: TokenKamera.garisFokus,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Senter + jepret, dalam satu baris (HP tegak) atau kolom (rel samping).
  /// Slot senter tetap ada walau kosong supaya tombol jepret tidak bergeser.
  List<Widget> _kontrolAksi({required bool baris}) {
    final l10n = AppLocalizations.of(context);
    final siap = _fase == _Fase.siap && !_memotret;
    final slot = SizedBox.square(dimension: TokenKamera.sasaranSentuh);
    const jarak = SizedBox.square(dimension: AppSpacing.lg);

    final senter = _fase == _Fase.siap && _senterTersedia
        ? _TombolBulat(
            key: const ValueKey('kamera-senter'),
            ikon: _senterNyala ? Icons.flashlight_on : Icons.flashlight_off,
            label: _senterNyala
                ? l10n.lkKameraSenterMatikan
                : l10n.lkKameraSenterNyalakan,
            sakelar: _senterNyala,
            onPressed: _memotret ? null : _gantiSenter,
          )
        : slot;

    final tombolJepret = _TombolJepret(
      key: const ValueKey('kamera-jepret'),
      label: l10n.lkKameraJepret,
      onPressed: siap ? _jepret : null,
    );

    return baris
        ? [senter, jarak, tombolJepret, jarak, slot]
        : [senter, jarak, tombolJepret];
  }

  /// Kartu pesan sesaat / saran petunjuk, atau tidak ada.
  Widget? _kartuUmpanBalik(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final pesan = _pesan;
    final saran = _petunjuk;

    if (pesan != null) {
      return _KartuKamera(
        key: const ValueKey('kamera-pesan'),
        ikon: Icons.error_outline,
        teks: pesan,
        dasar: m.kaca,
      );
    }
    if (saran != null) {
      return _KartuKamera(
        key: const ValueKey('kamera-petunjuk'),
        ikon: ikonPetunjukKamera(saran),
        teks: teksPetunjukKamera(
          l10n,
          saran,
          tabel: widget.rasioKertas == null,
        ),
        dasar: m.kaca,
      );
    }

    return null;
  }

  /// HP tegak: tutup di kiri atas, saran di atas bilah bawah; bilah bawah =
  /// bantuan + [senter][JEPRET] di tepi ibu jari.
  Widget _bangunTegak(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final kartu = _kartuUmpanBalik(context);
    final dasar = m.kaca.withValues(alpha: TokenKamera.dasarLapisan);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (kartu != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TokenKamera.lebarTeksMaks,
              ),
              child: kartu,
            ),
          ),
        // Flexible: pada layar sangat pendek bilah menyusut dan teks
        // bantuannya yang bergulir — tidak pernah meluap.
        Flexible(
          child: Container(
            width: double.infinity,
            color: dasar,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TokenKamera.lebarTeksMaks,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _teksBantuan(l10n),
                            key: const ValueKey('kamera-bantuan'),
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: m.lcdTeks),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _kontrolAksi(baris: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lanskap / tablet lebar: rel kontrol di sisi kanan (ibu jari kanan),
  /// saran + bantuan di kiri bawah.
  Widget _bangunLanskap(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final kartu = _kartuUmpanBalik(context);
    final dasar = m.kaca.withValues(alpha: TokenKamera.dasarLapisan);

    return Row(
      children: [
        Expanded(
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ruang tombol tutup (48 dp + jarak) di pojok kiri atas.
                  const SizedBox(
                    height: TokenKamera.sasaranSentuh + AppSpacing.sm,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TokenKamera.lebarTeksMaks,
                        ),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (kartu != null) ...[
                                kartu,
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: dasar,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                                child: Text(
                                  _teksBantuan(l10n),
                                  key: const ValueKey('kamera-bantuan'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: m.lcdTeks),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: TokenKamera.lebarRel,
          color: dasar,
          child: SafeArea(
            left: false,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _kontrolAksi(baris: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kalimat saran untuk teknisi. [tabel] = tanpa rasio halaman (foto satu tabel,
/// bukan seluruh halaman): "seluruh halaman" diganti "seluruh tabel".
@visibleForTesting
String teksPetunjukKamera(
  AppLocalizations l10n,
  PetunjukKamera p, {
  bool tabel = false,
}) => switch (p) {
  PetunjukKamera.gelapNyalakanSenter => l10n.lkKameraTipGelapNyalakanSenter,
  PetunjukKamera.gelapTambahCahaya => l10n.lkKameraTipGelapTambahCahaya,
  PetunjukKamera.silau => l10n.lkKameraTipSilau,
  PetunjukKamera.bayangan => l10n.lkKameraTipBayangan,
  PetunjukKamera.halamanTerpotong =>
    tabel ? l10n.lkKameraTipTerpotongTabel : l10n.lkKameraTipTerpotong,
  PetunjukKamera.buram => l10n.lkKameraTipBuram,
  PetunjukKamera.buramGerak => l10n.lkKameraTipBuramGerak,
  PetunjukKamera.agakGelap => l10n.lkKameraTipAgakGelap,
};

/// Ikon pendamping saran — saran SELALU ikon + kata, tidak hanya warna.
@visibleForTesting
IconData ikonPetunjukKamera(PetunjukKamera p) => switch (p) {
  PetunjukKamera.gelapNyalakanSenter => Icons.flashlight_on_outlined,
  PetunjukKamera.gelapTambahCahaya => Icons.brightness_low,
  PetunjukKamera.silau => Icons.wb_sunny_outlined,
  PetunjukKamera.bayangan => Icons.contrast,
  PetunjukKamera.halamanTerpotong => Icons.crop_free,
  PetunjukKamera.buram => Icons.blur_on,
  PetunjukKamera.buramGerak => Icons.vibration,
  PetunjukKamera.agakGelap => Icons.brightness_medium,
};

/// Kartu pesan/saran di atas pratinjau: SATU lapis dasar gelap (tidak
/// bersarang), ikon amber + teks terang. Dibacakan pembaca layar
/// (`liveRegion`) karena muncul sendiri tanpa disentuh.
class _KartuKamera extends StatelessWidget {
  const _KartuKamera({
    super.key,
    required this.ikon,
    required this.teks,
    required this.dasar,
  });

  final IconData ikon;
  final String teks;
  final Color dasar;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: dasar.withValues(alpha: TokenKamera.dasarLapisan),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, color: m.lcdAmber),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                teks,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: m.lcdTeks),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol ikon bulat di atas dasar gelap: sasaran sentuh ≥ 48 dp, [label]
/// jadi tooltip DAN label pembaca layar. [sakelar] (null = bukan sakelar)
/// menandai keadaan nyala/mati; tampilannya berubah lewat ikon DAN isian,
/// bukan warna saja.
class _TombolBulat extends StatelessWidget {
  const _TombolBulat({
    super.key,
    required this.ikon,
    required this.label,
    required this.onPressed,
    this.sakelar,
  });

  final IconData ikon;
  final String label;
  final VoidCallback? onPressed;
  final bool? sakelar;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final aktif = sakelar ?? false;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      toggled: sakelar,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(ikon),
        style: IconButton.styleFrom(
          backgroundColor: aktif
              ? m.lcdAmber
              : m.kaca.withValues(alpha: TokenKamera.dasarLapisan),
          foregroundColor: aktif ? m.kaca : m.lcdTeks,
          disabledForegroundColor: m.lcdTeks.withValues(
            alpha: TokenKamera.jepretMati,
          ),
          minimumSize: const Size.square(TokenKamera.sasaranSentuh),
          fixedSize: const Size.square(TokenKamera.sasaranSentuh),
        ),
      ),
    );
  }
}

/// Tombol jepret: SATU aksi utama layar. Cincin + cakram terang di atas dasar
/// gelap, jauh lebih besar dari sasaran sentuh minimum.
class _TombolJepret extends StatelessWidget {
  const _TombolJepret({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final nyala = onPressed != null;
    final warna = nyala
        ? m.lcdTeks
        : m.lcdTeks.withValues(alpha: TokenKamera.jepretMati);

    return Semantics(
      button: true,
      enabled: nyala,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: TokenKamera.tombolJepret,
          height: TokenKamera.tombolJepret,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: warna, width: TokenKamera.cincinJepret),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: warna),
          ),
        ),
      ),
    );
  }
}

/// Keadaan izin kamera ditolak: apa yang terjadi, langkah berikutnya (termasuk
/// jalur manual di Pengaturan) dan SATU aksi — "Coba lagi". Tidak ada jalan ke
/// kamera sistem: butuh izin yang sama.
class _PanelIzin extends StatelessWidget {
  const _PanelIzin({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TokenKamera.lebarTeksMaks,
            ),
            child: Column(
              key: const ValueKey('kamera-izin'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.no_photography_outlined, color: m.lcdAmber),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.lkKameraIzinJudul,
                        style: tema.titleLarge?.copyWith(color: m.lcdTeks),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.lkKameraIzinLangkah,
                  style: tema.bodyMedium?.copyWith(color: m.lcdTeks),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const ValueKey('kamera-coba-lagi'),
                  onPressed: onCobaLagi,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.lkKameraCobaLagi),
                  style: FilledButton.styleFrom(
                    backgroundColor: m.lcdTeks,
                    foregroundColor: m.kaca,
                    minimumSize: const Size(
                      TokenKamera.sasaranSentuh,
                      TokenKamera.sasaranSentuh,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Redupkan di luar bingkai + empat sudut terang. Bingkai hanya panduan letak —
/// tidak memotong foto (yang tersimpan adalah seluruh frame kamera).
class _PelukisBingkai extends CustomPainter {
  const _PelukisBingkai({
    required this.bingkai,
    required this.redaman,
    required this.sudut,
    required this.tepi,
  });

  final Rect bingkai;
  final Color redaman;
  final Color sudut;

  /// Garis gelap di bawah sudut terang: tampak di atas pratinjau yang terang
  /// maupun gelap (kontras komponen ≥ 3:1 tidak boleh bergantung isi kertas).
  final Color tepi;

  @override
  void paint(Canvas canvas, Size size) {
    final luar = Path()..addRect(Offset.zero & size);
    final dalam = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          bingkai,
          const Radius.circular(AppSpacing.radiusSm),
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, luar, dalam),
      Paint()..color = redaman,
    );

    final garis = Paint()
      ..color = sudut
      ..style = PaintingStyle.stroke
      ..strokeWidth = TokenKamera.garisSudut
      ..strokeCap = StrokeCap.round;
    final alas = Paint()
      ..color = tepi
      ..style = PaintingStyle.stroke
      ..strokeWidth = TokenKamera.garisSudut + 2 * TokenKamera.tepiSudut
      ..strokeCap = StrokeCap.round;
    final p = (bingkai.shortestSide * TokenKamera.porsiSudut).clamp(
      TokenKamera.sudutMin,
      TokenKamera.sudutMaks,
    );

    void ujung(Offset titik, double dx, double dy) {
      for (final cat in [alas, garis]) {
        canvas.drawLine(titik, titik.translate(dx * p, 0), cat);
        canvas.drawLine(titik, titik.translate(0, dy * p), cat);
      }
    }

    ujung(bingkai.topLeft, 1, 1);
    ujung(bingkai.topRight, -1, 1);
    ujung(bingkai.bottomLeft, 1, -1);
    ujung(bingkai.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_PelukisBingkai lama) =>
      lama.bingkai != bingkai ||
      lama.redaman != redaman ||
      lama.sudut != sudut ||
      lama.tepi != tepi;
}
