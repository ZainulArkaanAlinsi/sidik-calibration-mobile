import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/beku_lembar_kerja.dart';
import '../../l10n/app_localizations.dart';
import '../../models/review_foto.dart';
import '../../services/peta_tabel_foto.dart';
import '../../services/vonis_sel_foto.dart';
import 'widgets/keypad_angka.dart';

/// Layar review hasil **FOTO TABEL INI**, sebelum angkanya mendarat di form.
///
/// ## Kenapa layar ini ada
///
/// Sampai 28 Agt 2026 hasil OCR jalur foto ditulis LANGSUNG ke form: nggak ada
/// review, nggak ada satu pun angka keyakinan. Teknisi nggak punya cara tahu
/// sel mana yang dibaca ragu-ragu, dan sel yang salah baca cuma ketahuan kalau
/// dia kebetulan memeriksanya sendiri — di lembar yang baru saja kelihatan
/// "otomatis terisi", yaitu saat dia paling nggak curiga.
///
/// ## Tiga aturan yang nggak boleh dilanggar
///
/// Disalin dari `PindaiReviewScreen` (jalur lembar bermarker) karena alasannya
/// sama persis di sini:
///
///  1. **Nggak ada tombol "terima semua".** Angka di tabel ini tulisan tangan,
///     dan pengenal teks tetap percaya diri waktu salah membacanya. Satu tombol
///     yang melewati pemeriksaan menghapus seluruh guna layar ini.
///  2. **Tiap sel bisa diadu ke potongan citranya di layar yang sama.** Kalau
///     teknisi mesti membuka kertasnya lagi, dia bakal memilih mengetik dari
///     awal.
///  3. **Sel merah mulai KOSONG** walau OCR sempat membaca angkanya. Vonis
///     merah artinya bacaannya nggak bisa dipercaya, dan menampilkan angkanya
///     duluan bikin teknisi cuma menyetujui apa yang sudah ada.
///
/// ## Isi cepat (12 Nov 2026)
///
/// Sel tampil dalam URUTAN KERTAS (baris demi baris, kolom demi kolom). Mengetuk
/// kotak sebuah sel (atau "Isi cepat") membuka keypad angka dengan koma dan
/// minus; **"Konfirmasi dan lanjut"** memeriksa sel yang aktif lalu pindah ke
/// sel berikutnya yang belum beres. Tetap satu ketukan per sel: tidak ada
/// tombol yang memeriksa banyak sel sekaligus, sel kosong tidak ikut (tidak ada
/// barisnya), sel merah wajib diketik, dan tidak ada nilai yang disalin dari
/// sel lain.
///
/// Yang dipulangkan: `null` kalau teknisi membatalkan, atau daftar sel yang
/// dia setujui — teksnya sudah yang final, termasuk hasil koreksinya.
class FotoReviewScreen extends StatefulWidget {
  const FotoReviewScreen({
    super.key,
    required this.baris,
    this.catatan = const {},
    this.kunciSkorMentah = const {},
  });

  final List<BarisReviewFoto> baris;

  /// Alasan (sudah dilokalkan) kenapa sel diturunkan aturan nalar formulir,
  /// berkunci `kunciSelFoto`. Hanya penjelasan: tidak mengubah vonis, tidak
  /// mengubah kewajiban cek/ketik, dan tidak membuka "terima semua".
  final Map<String, List<String>> catatan;

  /// Baris (kunci [kunciSelFoto]) yang keyakinannya BUKAN peluang yang boleh
  /// dibaca sebagai persen — skor mentah mesin angka (`jalur`) terlalu yakin
  /// (ECE 0,44–0,57). Baris ini menampilkan "usulan mesin", tanpa angka; baris
  /// lain (mis. hasil ML Kit di lembar yang sama) tidak terpengaruh.
  final Set<String> kunciSkorMentah;

  @override
  State<FotoReviewScreen> createState() => _FotoReviewScreenState();
}

class _FotoReviewScreenState extends State<FotoReviewScreen> {
  late final Map<String, TextEditingController> _isian = {
    for (final b in widget.baris)
      kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId): TextEditingController(
        // Aturan 3: merah mulai kosong.
        text: b.vonis.nilainyaDitampilkan ? b.teks : '',
      ),
  };

  /// Sel kuning/tidak-diketahui yang sudah disentuh teknisi (ketuk tanda cek
  /// atau mengubah angkanya). Tulisan tangan tidak pernah hijau: tiap sel
  /// kuning WAJIB dicek satu per satu sebelum masuk lembar.
  final Set<String> _dicek = {};

  /// Sel yang sedang dipegang keypad (kunci [kunciSelFoto]), atau `null`.
  String? _aktif;
  final Map<String, GlobalKey> _kunciBaris = {};
  final Map<String, FocusNode> _fokus = {};
  final ScrollController _gulir = ScrollController();

  FocusNode _node(String kunci) => _fokus.putIfAbsent(kunci, FocusNode.new);

  /// Keypad layar (bukan papan ketik sistem) dipakai di perangkat ini?
  bool get _keypadLayar => bolehKeypadLayar(MediaQuery.of(context));

  bool _wajibCek(BarisReviewFoto b) =>
      b.vonis == VonisFoto.kuning || b.vonis == VonisFoto.tidakDiketahui;

  List<BarisReviewFoto> get _belumDicek => [
    for (final b in widget.baris)
      if (_wajibCek(b) && !_dicek.contains(_kunci(b))) b,
  ];

  @override
  void dispose() {
    for (final c in _isian.values) {
      c.dispose();
    }
    for (final f in _fokus.values) {
      f.dispose();
    }
    _gulir.dispose();
    super.dispose();
  }

  String _kunci(BarisReviewFoto b) =>
      kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId);

  /// Sel merah yang kotaknya masih kosong — penghalang tombol Masukkan.
  List<BarisReviewFoto> get _belumDiisi => [
    for (final b in widget.baris)
      if (wajibDiisi(b) && _isian[_kunci(b)]!.text.trim().isEmpty) b,
  ];

  /// Sel ini masih butuh perhatian teknisi? Kuning/tidak-diketahui yang belum
  /// dicek, atau merah yang kotaknya masih kosong.
  bool _butuh(BarisReviewFoto b) =>
      (_wajibCek(b) && !_dicek.contains(_kunci(b))) ||
      (wajibDiisi(b) && _isian[_kunci(b)]!.text.trim().isEmpty);

  /// Sel berikutnya (urutan kertas) sesudah [setelah] yang masih [_butuh],
  /// memutar ke awal bila perlu. `null` = semua sudah beres.
  String? _berikutnya(String? setelah) {
    final n = widget.baris.length;
    final mulai = setelah == null
        ? 0
        : widget.baris.indexWhere((b) => _kunci(b) == setelah) + 1;

    for (var i = 0; i < n; i++) {
      final b = widget.baris[(mulai + i) % n];
      if (_kunci(b) != setelah && _butuh(b)) return _kunci(b);
    }

    return null;
  }

  void _aktifkan(String kunci) {
    setState(() => _aktif = kunci);
    _gulirKe(kunci);
  }

  void _mulaiIsiCepat() {
    final k = _berikutnya(null) ?? _kunci(widget.baris.first);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _aktif = k);
    // Tanpa keypad layar, papan ketik sistem yang mengetik: fokuskan kotaknya.
    _gulirKe(k, fokus: !_keypadLayar);
  }

  void _ketik(TombolKeypad t) {
    final k = _aktif;
    if (k == null) return;

    final c = _isian[k]!;
    final baru = terapkanTombolKeypad(c.text, t);
    c.value = TextEditingValue(
      text: baru,
      selection: TextSelection.collapsed(offset: baru.length),
    );
    // Sama dengan mengetik di kotak: mengubah angka = sudah dilihat.
    setState(() => _dicek.add(k));
  }

  bool get _bisaKonfirmasi {
    final k = _aktif;
    if (k == null) return false;
    final b = widget.baris.firstWhere((b) => _kunci(b) == k);

    return !(wajibDiisi(b) && _isian[k]!.text.trim().isEmpty);
  }

  /// Satu ketukan: periksa sel aktif, pindah ke sel berikutnya yang belum beres.
  void _konfirmasiLanjut() {
    final k = _aktif;
    if (k == null || !_bisaKonfirmasi) return;

    final keypad = _keypadLayar;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _dicek.add(k));
    final berikut = _berikutnya(k);
    setState(() => _aktif = berikut);
    // Papan ketik sistem tetap terbuka untuk sel berikutnya (fokus pindah).
    if (berikut != null) _gulirKe(berikut, fokus: !keypad);
  }

  /// Gulir sel [kunci] ke tengah layar. Daftar dibangun malas: bila barisnya
  /// belum ada di pohon, loncat ke perkiraan letaknya dulu lalu coba lagi.
  void _gulirKe(String kunci, {bool ulang = true, bool fokus = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final ctx = _kunciBaris[kunci]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.15,
          duration: const Duration(milliseconds: 180),
        );
        if (fokus) _node(kunci).requestFocus();
        return;
      }

      if (ulang && _gulir.hasClients) {
        final i = widget.baris.indexWhere((b) => _kunci(b) == kunci);
        final p = _gulir.position;
        final per = p.maxScrollExtent / math.max(1, widget.baris.length - 1);
        _gulir.jumpTo((i * per).clamp(0.0, p.maxScrollExtent));
        _gulirKe(kunci, ulang: false, fokus: fokus);
      }
    });
  }

  void _selesai() {
    // SEMUA sel dipulangkan, termasuk yang teknisi kosongkan — bukan cuma yang
    // ada isinya.
    //
    // Menyaringnya di sini bikin sel yang dikosongkan HILANG tanpa jejak, dan
    // yang membaca kode ini nanti harus menebak kenapa. Keputusan "teks kosong
    // = nggak usah ditaruh" cuma boleh ada di SATU tempat, dan tempatnya
    // `terapkanHasilFotoTabel` — di situ dia tertulis, teruji, dan sejalan
    // dengan aturannya sendiri bahwa sel yang sudah ada isinya nggak pernah
    // ditimpa. Ini juga menyamakan kontraknya dengan `PindaiReviewScreen`,
    // yang memang memulangkan semua sel.
    final hasil = <SelTabelFoto>[
      for (final b in widget.baris)
        (
          titikUkur: b.titikUkur,
          repeatNo: b.repeatNo,
          fieldId: b.fieldId,
          teks: _isian[_kunci(b)]!.text.trim(),
          // Yang dipulangkan keyakinan OCR ASLINYA, bukan keyakinan sesudah
          // dikoreksi. Sel yang diketik ulang teknisi memang nggak punya
          // keyakinan OCR — dan menaikkannya jadi 1.0 di sini bikin
          // pengumpul data latih nggak bisa lagi membedakan mana yang
          // dibaca mesin dan mana yang diketik orang.
          keyakinan: b.keyakinan,
        ),
    ];

    Navigator.of(context).pop(hasil);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final belum = _belumDiisi;
    final belumDicek = _belumDicek;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fotoReviewJudul(widget.baris.length))),
      body: LayoutBuilder(
        builder: (context, tempat) => Column(
          children: [
            // "Isi cepat" dan pengantar ikut menggulir bersama daftar: di layar
            // sempit bagian tetapnya cuma panel bawah, jadi daftar tidak pernah
            // tertindih dan tidak ada overflow. Tombolnya di ATAS pengantar
            // supaya tidak terdorong keluar layar oleh teks yang panjang.
            Expanded(
              child: CustomScrollView(
                controller: _gulir,
                slivers: [
                  if (_aktif == null && widget.baris.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: TextButton.icon(
                            key: const ValueKey('mulai-isi-cepat'),
                            onPressed: _mulaiIsiCepat,
                            icon: const Icon(Icons.dialpad),
                            label: Text(l10n.fotoReviewIsiCepat),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.fotoReviewPengantar,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: widget.baris.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (_, i) => _baris(widget.baris[i], l10n),
                    ),
                  ),
                ],
              ),
            ),
            if (_aktif != null)
              _panel(l10n, tempat.maxHeight)
            else
              _aksiBawah(l10n, belum, belumDicek, tempat.maxHeight < 420),
          ],
        ),
      ),
    );
  }

  /// Tombol Masukkan beserta penghitungnya (panel tertutup). Di tinggi sisa
  /// kurang dari 420 dp (HP lanskap, papan ketik sistem terbuka) penghitungnya
  /// diringkas jadi satu baris bersama tombol, supaya tombol tidak mendesak
  /// daftar sampai overflow. Aturannya sama: Masukkan mati selama ada merah
  /// kosong atau kuning belum dicek.
  Widget _aksiBawah(
    AppLocalizations l10n,
    List<BarisReviewFoto> belum,
    List<BarisReviewFoto> belumDicek,
    bool ringkas,
  ) {
    // Sengaja TIDAK ada tombol "terima semua" — lihat aturan 1 di docblock
    // kelas ini.
    final masukkan = FilledButton(
      onPressed: belum.isEmpty && belumDicek.isEmpty ? _selesai : null,
      child: Text(l10n.fotoReviewMasukkan, maxLines: 1),
    );
    final gaya = TextStyle(color: Theme.of(context).colorScheme.error);

    if (ringkas) {
      final sisa = belum.length + belumDicek.length;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              if (sisa > 0)
                Flexible(
                  child: Text(
                    l10n.fotoReviewSisaSel(sisa),
                    key: const ValueKey('sisa-bawah'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: gaya,
                  ),
                ),
              if (sisa > 0) const SizedBox(width: 12),
              Expanded(child: masukkan),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (belum.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.fotoReviewMasihKosong(belum.length),
                  style: gaya,
                ),
              ),
            if (belumDicek.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.fotoReviewBelumDicek(belumDicek.length),
                  style: gaya,
                ),
              ),
            masukkan,
          ],
        ),
      ),
    );
  }

  /// Panel isian cepat di bawah daftar, selama ada sel aktif: keypad layar di
  /// layar lega, panel ringkas (papan ketik sistem yang mengetik) di layar
  /// sempit / huruf besar / HP lanskap. Keduanya memuat kepala sel aktif dan
  /// SISA sel — penghitung yang ada di bawah daftar saat panel tertutup.
  ///
  /// [tinggiTersedia] = tinggi badan layar sesudah papan ketik sistem; di bawah
  /// 360 dp panel ringkas jadi satu baris saja (sisa + konfirmasi).
  Widget _panel(AppLocalizations l10n, double tinggiTersedia) {
    final k = _aktif!;
    final b = widget.baris.firstWhere((b) => _kunci(b) == k);
    final sisa = l10n.fotoReviewSisaSel(
      _belumDiisi.length + _belumDicek.length,
    );
    final kepala = KepalaSelAktif(
      judul: b.judul,
      sisa: sisa,
      teks: _isian[k]!.text,
      potongan: b.potongan,
    );

    if (_keypadLayar) {
      return SafeArea(
        top: false,
        child: BekuLembarKerja(
          child: KeypadAngka(
            kepala: kepala,
            tinggiTombol: (tinggiTersedia * 0.06).clamp(36.0, 48.0),
            onTombol: _ketik,
            onKonfirmasi: _konfirmasiLanjut,
            onTutup: () => setState(() => _aktif = null),
            labelKonfirmasi: l10n.fotoReviewKonfirmasiLanjut,
            labelTutup: l10n.fotoReviewTutupKeypad,
            labelHapus: l10n.fotoReviewKeypadHapus,
            labelMinus: l10n.fotoReviewKeypadMinus,
            bisaKonfirmasi: _bisaKonfirmasi,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: PanelIsiCepatRingkas(
        kepala: tinggiTersedia < 360 ? null : kepala,
        sisaMini: sisa,
        onKonfirmasi: _konfirmasiLanjut,
        onTutup: () => setState(() => _aktif = null),
        labelKonfirmasi: l10n.fotoReviewKonfirmasiLanjut,
        labelTutup: l10n.fotoReviewTutupKeypad,
        bisaKonfirmasi: _bisaKonfirmasi,
      ),
    );
  }

  /// Baris + bingkai bila sedang dipegang keypad, dan kunci untuk digulir ke layar.
  Widget _baris(BarisReviewFoto b, AppLocalizations l10n) {
    final aktif = _aktif == _kunci(b);

    return Container(
      key: _kunciBaris.putIfAbsent(_kunci(b), GlobalKey.new),
      padding: aktif ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: aktif
          ? BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: _isiBaris(b, l10n),
    );
  }

  Widget _isiBaris(BarisReviewFoto b, AppLocalizations l10n) {
    final warna = switch (b.vonis) {
      VonisFoto.merah => Theme.of(context).colorScheme.error,
      VonisFoto.kuning || VonisFoto.tidakDiketahui => Colors.orange.shade800,
      VonisFoto.hijau => Colors.green.shade700,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(b.judul, style: Theme.of(context).textTheme.labelLarge),
        for (final c in widget.catatan[_kunci(b)] ?? const <String>[])
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              c,
              key: ValueKey('alasan-${_kunci(b)}'),
              style: TextStyle(color: warna, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),

        // Aturan 2: potongan citranya diadu ke bacaannya, di layar yang sama.
        if (b.potongan != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Image.memory(
              b.potongan!,
              height: 48,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              // Potongan gagal didekode bukan alasan menjatuhkan barisnya —
              // yang hilang alat bantunya, selnya tetap harus bisa diisi.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _isian[_kunci(b)],
                focusNode: _node(_kunci(b)),
                // Keypad layar aktif = papan ketik sistem tidak perlu muncul.
                // Di layar sempit keypad tidak dipakai: papan ketik sistem.
                keyboardType: _aktif != null && _keypadLayar
                    ? TextInputType.none
                    : const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                onTap: () => _aktifkan(_kunci(b)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                onChanged: (_) => setState(() => _dicek.add(_kunci(b))),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: b.vonis == VonisFoto.merah
                      ? l10n.fotoReviewKetikSendiri
                      : null,
                ),
              ),
            ),
            if (_wajibCek(b))
              IconButton(
                key: ValueKey('cek-${_kunci(b)}'),
                tooltip: _dicek.contains(_kunci(b))
                    ? l10n.fotoReviewSudahDicek
                    : l10n.fotoReviewTandaiDicek,
                icon: Icon(
                  _dicek.contains(_kunci(b))
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: _dicek.contains(_kunci(b))
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
                onPressed: () => setState(() {
                  final k = _kunci(b);
                  if (!_dicek.remove(k)) _dicek.add(k);
                }),
              ),
            const SizedBox(width: 12),
            SizedBox(
              width: 108,
              child: Text(
                // Keyakinan yang TIDAK dilaporkan disebut apa adanya, bukan
                // ditulis "0%" — nol berarti "yakin banget salah", dan itu
                // klaim yang nggak pernah dibuat siapa pun.
                //
                // Skor mentah mesin angka bukan persen (ECE 0,44–0,57): baris
                // dari mesin angka ([kunciSkorMentah]) tanpa angka, hanya
                // "usulan mesin"; sel yang ditahan (merah) tanpa keterangan
                // karena tidak ada usulan. Baris ML Kit tidak ikut label ini.
                b.keyakinan == null
                    ? l10n.fotoReviewKeyakinanTakAda
                    : !widget.kunciSkorMentah.contains(_kunci(b))
                    ? l10n.fotoReviewKeyakinan((b.keyakinan! * 100).round())
                    : b.vonis == VonisFoto.merah
                    ? ''
                    : l10n.fotoReviewUsulanMesin,
                maxLines: 3,
                style: TextStyle(color: warna, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
