import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/contoh_sel_provider.dart';
import '../../../services/potong_sel_foto.dart';
import '../../../services/ambil_foto_tabel.dart';
import '../../../services/peta_tabel_foto.dart';
import '../grid_sensor_state.dart';
import '../lembar_kerja_state.dart' show kuningPerluDicek;

/// Layar isian GRID SENSOR: satu set point = banyak termokopel × banyak
/// pembacaan, plus baris Indikator & Suhu Ruang.
///
/// Susunannya SEBARIS-SEBARIS ngikut kertas, sama alasannya dengan
/// [LembarKerjaMatriks]: teknisi mengisi layar ini sambil memegang kertas yang
/// barusan dia tulis di chamber, dan matanya lompat baris per baris.
///
/// Yang beda dari matriks — dan ini yang bikin dia butuh widget sendiri —
/// **barisnya nggak dipatok backend**. Berapa termokopel dipasang dan nomor
/// berapa saja baru ketahuan di lapangan, jadi barisnya bisa ditambah,
/// dikurangi, dan dinomori bebas. Nomor itu pula yang menentukan koreksi mana
/// yang dipakai dan sensor mana jadi Sensor Acuan — bukan urutan barisnya di
/// layar.
class LembarKerjaGrid extends StatefulWidget {
  const LembarKerjaGrid({
    super.key,
    required this.state,
    required this.satuanSuhu,
    required this.onBerubah,
    required this.pemilik,
    this.merkKalibrator,
    this.pindaiAktif = AppConfig.pindaiLembarAktif,
  });

  final GridSensorState state;

  /// `°C` — dari `satuan_suhu` lembar.
  final String satuanSuhu;

  final VoidCallback onBerubah;

  /// Penanda sesi lembar ini — `LembarKerjaState.clientRequestId`.
  ///
  /// Diteruskan ke [PenampungContohSel] supaya tampungan contoh latihnya bisa
  /// dibuang waktu lembarnya ditutup, tanpa ikut membuang milik layar lain.
  final String pemilik;

  /// Merk standar yang dicentang teknisi. Menentukan kolom Channel muncul atau
  /// nggak: koreksi Recorder (GL840) dibaca per kanal, Constant & Yokogawa
  /// nggak. Null = belum milih standar.
  final String? merkKalibrator;

  /// Tombol `FOTO TABEL INI` di tiap blok set point.
  ///
  /// **Sengaja TIDAK membaca `pindai_foto.didukung` dari server.** Penanda itu
  /// menjawab pertanyaan lain: "kertas alat ini muat di bentuk titik × Repeat
  /// yang bisa dituturkan ke pembaca foto?" — dan buat lembar grid jawabannya
  /// memang `false`, karena kertasnya bersumbu TIGA (set point × sensor ×
  /// pengulangan). Yang dipakai di sini bukan bentuk dua-penanda itu: sumbu
  /// ketiganya datang dari BLOK MANA tombolnya ditekan, bukan dari citra. Jadi
  /// yang menggerbanginya keberadaan gridnya sendiri, plus saklar fitur.
  final bool pindaiAktif;

  @override
  State<LembarKerjaGrid> createState() => _LembarKerjaGridState();
}

class _LembarKerjaGridState extends State<LembarKerjaGrid> {
  static const _lebarNo = 62.0;
  static const _lebarKanal = 62.0;
  static const _lebarKolom = 78.0;

  bool get _pakaiKanal =>
      widget.state.bentuk.butuhChannel(widget.merkKalibrator);

  /// Sekali sentuh = hitung ulang Sensor Acuan, nomor kembar, dan peringatan.
  ///
  /// Harus setState di sini, bukan cuma memanggil [widget.onBerubah]: yang
  /// berubah bukan cuma payload di luar, tapi apa yang digambar baris ini —
  /// lencana "Acuan" pindah begitu nomor terkecil diketik atau dikosongkan.
  void _berubah() {
    widget.state.bacaUlang();
    setState(() {});
    widget.onBerubah();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bentuk = widget.state.bentuk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bentuk.catatanSensorAcuan.isNotEmpty)
          _Catatan(teks: bentuk.catatanSensorAcuan),

        for (var i = 0; i < widget.state.setPoint.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          _KartuSetPoint(
            nomor: i + 1,
            sp: widget.state.setPoint[i],
            satuanSuhu: widget.satuanSuhu,
            pakaiKanal: _pakaiKanal,
            merkKalibrator: widget.merkKalibrator,
            lebarNo: _lebarNo,
            lebarKanal: _lebarKanal,
            lebarKolom: _lebarKolom,
            pemilik: widget.pemilik,
            onBerubah: _berubah,
            pindaiAktif: widget.pindaiAktif,
            bisaDihapus: widget.state.setPoint.length > 1,
            onHapus: () {
              setState(() => widget.state.hapusSetPoint(i));
              widget.onBerubah();
            },
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('grid_tambah_set_point'),
            onPressed: () {
              setState(widget.state.tambahSetPoint);
              widget.onBerubah();
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Set Point'),
          ),
        ),

        // Peringatan dikumpulkan di BAWAH, sesudah semua set point — bukan
        // dilempar sebagai error waktu kirim. Tombol kirim nggak pernah
        // dikunci di lembar kerja; ini pemberitahuan supaya teknisi sempat
        // melengkapi, bukan penjagaan.
        Builder(
          builder: (context) {
            final pesan = widget.state.peringatan(widget.merkKalibrator);
            if (pesan.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: _PanelPeringatan(pesan: pesan, theme: theme),
            );
          },
        ),
      ],
    );
  }
}

class _KartuSetPoint extends StatelessWidget {
  const _KartuSetPoint({
    required this.nomor,
    required this.sp,
    required this.satuanSuhu,
    required this.pakaiKanal,
    required this.merkKalibrator,
    required this.lebarNo,
    required this.lebarKanal,
    required this.lebarKolom,
    required this.onBerubah,
    required this.pindaiAktif,
    required this.bisaDihapus,
    required this.onHapus,
    required this.pemilik,
  });

  final int nomor;
  final SetPointGridState sp;
  final String satuanSuhu;
  final bool pakaiKanal;
  final String? merkKalibrator;
  final double lebarNo;
  final double lebarKanal;
  final double lebarKolom;
  final VoidCallback onBerubah;
  final bool pindaiAktif;
  final bool bisaDihapus;
  final VoidCallback onHapus;
  final String pemilik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acuan = sp.nomorAcuan;
    final kembar = sp.nomorKembar.toSet();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Set Point $nomor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 92,
                  child: _KotakAngka(
                    key: Key('grid_titik_$nomor'),
                    controller: sp.titikCtl,
                    onBerubah: onBerubah,
                    hint: satuanSuhu,
                  ),
                ),
                const Spacer(),
                if (bisaDihapus)
                  IconButton(
                    tooltip: 'Hapus set point ini',
                    onPressed: onHapus,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Tombolnya di dalam kartu set point, bukan satu buat seluruh
            // lembar — dan letaknya itu yang membawa sumbu ketiga. Kertas grid
            // bersumbu TIGA (set point × sensor × pengulangan), sementara foto
            // cuma sanggup memberi dua. Sumbu yang ketiga karena itu diambil
            // dari BLOK MANA tombolnya ditekan, bukan ditebak dari citra.
            //
            // Aturan yang sama sudah dipakai lembar Conductivity: slot yang
            // bersatuan dobel menunjuk titik yang lagi dicentang teknisi,
            // bukan ditebak dari angka yang kebaca.
            if (pindaiAktif) ...[
              SizedBox(
                width: double.infinity,
                child: _TombolFotoGrid(
                  nomor: nomor,
                  sp: sp,
                  onBerubah: onBerubah,
                  pemilik: pemilik,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kepala(theme),
                  for (var i = 0; i < sp.sensor.length; i++)
                    _barisSensor(
                      context,
                      theme,
                      sp.sensor[i],
                      i,
                      acuan: acuan,
                      kembar: kembar,
                    ),
                  if (sp.bentuk.barisIndikator)
                    _barisDeret(
                      theme,
                      'Indikator',
                      sp.indikator,
                      kunci: 'grid_indikator_$nomor',
                    ),
                  if (sp.bentuk.barisSuhuRuang)
                    _barisDeret(
                      theme,
                      'Suhu Ruang',
                      sp.suhuRuang,
                      kunci: 'grid_suhu_ruang_$nomor',
                      redup: true,
                    ),
                ],
              ),
            ),

            if (sp.bentuk.barisSuhuRuang)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Baris Suhu Ruang dicatat di lembar, tapi belum dikirim ke '
                  'server — backend belum punya tempat menampungnya.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('grid_tambah_sensor_$nomor'),
                onPressed: () {
                  sp.tambahSensor();
                  onBerubah();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah termokopel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sel(
    ThemeData theme,
    String teks,
    double lebar, {
    bool tebal = false,
  }) => Container(
    width: lebar,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    alignment: Alignment.center,
    color: theme.colorScheme.surfaceContainerHighest,
    child: Text(
      teks,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: tebal ? FontWeight.w600 : null,
      ),
    ),
  );

  Widget _kepala(ThemeData theme) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sel(theme, 'No. TC', lebarNo, tebal: true),
        if (pakaiKanal) _sel(theme, 'CH', lebarKanal, tebal: true),
        for (final n in sp.bentuk.pengulangan)
          _sel(theme, '$n', lebarKolom, tebal: true),
        _sel(theme, '', 48),
      ],
    ),
  );

  Widget _barisSensor(
    BuildContext context,
    ThemeData theme,
    BarisSensorState s,
    int index, {
    required int? acuan,
    required Set<int> kembar,
  }) {
    final no = s.no;
    final iniAcuan = no != null && no == acuan;
    final iniKembar = no != null && kembar.contains(no);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: lebarNo,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _KotakAngka(
                key: Key('grid_no_${nomor}_$index'),
                controller: s.noCtl,
                onBerubah: onBerubah,
                bulat: true,
                galat: iniKembar,
                // Nomor yang dibaca dari foto ditandai sama seperti
                // pembacaannya. Ini kotak yang paling penting diadu ke kertas:
                // salah baca di sini memindahkan SELURUH barisnya.
                dariFoto: s.noDariFoto,
              ),
            ),
          ),
          if (pakaiKanal)
            SizedBox(
              width: lebarKanal,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('grid_ch_${nomor}_$index'),
                  controller: s.channelCtl,
                  onBerubah: onBerubah,
                  bulat: true,
                  // Kanal kosong padahal kalibratornya Recorder = set point-nya
                  // nggak dihitung. Ditandai di selnya, bukan cuma di panel
                  // peringatan jauh di bawah.
                  galat: s.jumlahTerisi > 0 && s.channel == null,
                ),
              ),
            ),
          for (var k = 0; k < s.pembacaanCtl.length; k++)
            SizedBox(
              width: lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('grid_baca_${nomor}_${index}_$k'),
                  controller: s.pembacaanCtl[k],
                  onBerubah: onBerubah,
                  dariFoto: s.dariFoto.contains(k),
                ),
              ),
            ),
          SizedBox(
            width: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iniAcuan)
                  Tooltip(
                    message: 'Sensor Acuan — nomor terkecil yang terisi',
                    child: Icon(
                      Icons.star,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else if (s.pembacaanKurang)
                  Tooltip(
                    message:
                        'Baru ${s.jumlahTerisi} pembacaan — minimal 4 supaya '
                        'set point ini ikut dihitung',
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  IconButton(
                    key: Key('grid_hapus_sensor_${nomor}_$index'),
                    tooltip: 'Hapus baris',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      sp.hapusSensor(index);
                      onBerubah();
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisDeret(
    ThemeData theme,
    String label,
    BarisDeretState b, {
    required String kunci,
    bool redup = false,
  }) {
    final lebarKiri = lebarNo + (pakaiKanal ? lebarKanal : 0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: lebarKiri,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            alignment: Alignment.centerLeft,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: redup ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          for (var k = 0; k < b.ctl.length; k++)
            SizedBox(
              width: lebarKolom,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _KotakAngka(
                  key: Key('${kunci}_$k'),
                  controller: b.ctl[k],
                  onBerubah: onBerubah,
                  dariFoto: b.dariFoto.contains(k),
                ),
              ),
            ),
          SizedBox(width: 48, child: Container()),
        ],
      ),
    );
  }
}

/// `FOTO TABEL INI` buat SATU blok set point grid.
///
/// ## Jangkarnya apa
///
/// Sama aturannya dengan jalur tabel: tiap angka wajib punya DUA jangkar
/// sebelum ditaruh, dan yang cuma punya satu dibuang.
///
///  - **baris** dari kolom `No.` — nomor termokopel, **dibaca dari fotonya**.
///    Bukan dicocokkan ke nomor yang ada di layar: teknisi motret dulu,
///    nomornya belakangan (keputusan pemilik lab, 27 Agt 2026), jadi waktu
///    tombolnya ditekan layarnya memang masih kosong. Nomornya ikut ditaruh di
///    kotaknya sendiri dan ikut ditandai kuning — lihat
///    `PetaTabelFoto.nomorBarisTerbaca` soal kenapa itu yang bikin risikonya
///    bisa ditanggung.
///  - **kolom** dari kepala kolom pengulangan yang tercetak.
///  - **set point** dari kartu tempat tombol ini duduk, bukan dari citra.
///
/// Dua baris deret (`Indikator`, `Suhu Ruang`) dijangkar TULISANNYA, lewat
/// `labelTercetak` — jalur yang sama yang dipakai lembar Viscometer buat baris
/// yang label kertasnya beda dari nilai hitungannya.
class _TombolFotoGrid extends ConsumerStatefulWidget {
  const _TombolFotoGrid({
    required this.nomor,
    required this.sp,
    required this.onBerubah,
    required this.pemilik,
  });

  final int nomor;
  final SetPointGridState sp;
  final VoidCallback onBerubah;
  final String pemilik;

  @override
  ConsumerState<_TombolFotoGrid> createState() => _TombolFotoGridState();
}

class _TombolFotoGridState extends ConsumerState<_TombolFotoGrid> {
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

      // Nomor termokopelnya dibaca DARI FOTO, bukan dicocokkan ke layar —
      // teknisi motret dulu, nomornya belakangan. Lihat
      // `PetaTabelFoto.nomorBarisTerbaca` soal kenapa itu bisa ditanggung.
      const peta = PetaTabelFoto();
      final nomor = peta.nomorBarisTerbaca(foto.terbaca!);

      final kembar = <int>{
        for (final n in nomor)
          if (nomor.where((x) => x == n).length > 1) n,
      }.toList()..sort();

      if (kembar.isNotEmpty) {
        // Dua baris bernomor sama bikin pembacaannya nggak bisa dipastikan
        // masuk termokopel yang mana — dan menggabungnya diam-diam justru
        // membuang separuhnya. Ditolak utuh, sebabnya disebut.
        pesan(l10n.lkGridFotoNomorKembar(kembar.join(', ')));

        return;
      }

      final penanda = widget.sp.penandaBarisFoto(nomor);

      final hasil = peta.petakan(
        terbaca: foto.terbaca!,
        titikUkur: penanda.penanda,
        pengulangan: widget.sp.bentuk.pengulangan,
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
      // Penandanya dibangun unik di `GridSensorState.penandaBarisFoto`,
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
              // Jangkarnya ketemu semua, badan tabelnya yang nggak ada
              // angkanya — kertas yang difoto memang belum diisi. Menyuruh
              // teknisi membetulkan framing di sini bikin dia menjepret ulang
              // lembar yang sama berkali-kali.
              ? l10n.lkFotoTabelKosong
              : l10n.lkGridFotoTanpaJangkar,
        );

        return;
      }

      // Potongan selnya DITAHAN sampai teknisi menekan Simpan — labelnya angka
      // final, bukan yang dibaca OCR sekarang. Lihat [PenampungContohSel].
      //
      // Penandanya memuat nomor sensor: satu lembar Enclosure punya beberapa
      // grid dengan penanda baris yang sama persis, dan tanpa nomornya contoh
      // dari sensor berbeda saling menimpa.
      //
      // Kegagalannya sengaja DIAM: ini pengumpul data latih, bukan bagian
      // kalibrasinya.
      final citra = foto.citra;

      if (citra != null && hasil.kotakSel.isNotEmpty) {
        // Disalin ke lokal — closure-nya hidup sampai Simpan, dan `widget`
        // ditukar tiap rebuild.
        final sp = widget.sp;

        try {
          (await ref.read(penampungContohSelProvider.future)).tampung(
            potongan: const PotongSelFoto()
                .potong(citra: citra, kotak: hasil.kotakSel)
                .potongan,
            penanda: (k) => 'grid|$nomor|${k.titikUkur}|${k.repeatNo}',
            pemilik: widget.pemilik,
            labelAkhir: (k) => sp.labelSelFoto(k.titikUkur, k.repeatNo),
          );
        } catch (_) {
          // Sengaja ditelan — lihat di atas.
        }
      }

      final terisi = widget.sp.terapkanHasilFoto(hasil.sel);

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
      key: Key('grid_foto_${widget.nomor}'),
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

/// Kuning penanda "diisi mesin, belum diadu ke kertas" — nilainya disamakan
/// dengan `TandaSel.keyakinanRendah` di `lembar_kerja_tabel.dart`.

class _KotakAngka extends StatelessWidget {
  const _KotakAngka({
    super.key,
    required this.controller,
    required this.onBerubah,
    this.bulat = false,
    this.galat = false,
    this.dariFoto = false,
    this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onBerubah;

  /// Kotak nomor (No. TC / CH) — bilangan bulat, tanpa koma & tanpa minus.
  final bool bulat;

  final bool galat;

  /// Isinya datang dari FOTO, belum diadu ke kertas. Ditandai kuning — warna
  /// yang sama dipakai `TandaSel.keyakinanRendah` di jalur tabel, dan artinya
  /// sama: saran mesin, bukan keputusan orang.
  final bool dariFoto;

  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      keyboardType: bulat
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          bulat ? RegExp(r'[0-9]') : RegExp(r'[0-9.,\-]'),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: const OutlineInputBorder(),
        // Galat menang atas penanda foto: kotak yang salah harus kelihatan
        // salah, bukan cuma "belum dicek".
        enabledBorder: galat
            ? OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.error),
              )
            : dariFoto
            ? const OutlineInputBorder(
                borderSide: BorderSide(color: kuningPerluDicek, width: 2),
              )
            : null,
      ),
      onChanged: (_) => onBerubah(),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(teks, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _PanelPeringatan extends StatelessWidget {
  const _PanelPeringatan({required this.pesan, required this.theme});

  final List<String> pesan;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Kalau dikirim sekarang, ini nggak ikut dihitung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final p in pesan)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $p',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set point-nya tetap TERSIMPAN — pembacaannya nggak hilang, dan '
            'set point lain di sesi ini tetap dihitung.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
