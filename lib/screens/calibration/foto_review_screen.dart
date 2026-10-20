import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/review_foto.dart';
import '../../services/peta_tabel_foto.dart';
import '../../services/vonis_sel_foto.dart';

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
/// Yang dipulangkan: `null` kalau teknisi membatalkan, atau daftar sel yang
/// dia setujui — teksnya sudah yang final, termasuk hasil koreksinya.
class FotoReviewScreen extends StatefulWidget {
  const FotoReviewScreen({
    super.key,
    required this.baris,
    this.catatan = const {},
  });

  final List<BarisReviewFoto> baris;

  /// Alasan (sudah dilokalkan) kenapa sel diturunkan aturan nalar formulir,
  /// berkunci `kunciSelFoto`. Hanya penjelasan: tidak mengubah vonis, tidak
  /// mengubah kewajiban cek/ketik, dan tidak membuka "terima semua".
  final Map<String, List<String>> catatan;

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
    super.dispose();
  }

  String _kunci(BarisReviewFoto b) =>
      kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId);

  /// Sel merah yang kotaknya masih kosong — penghalang tombol Masukkan.
  List<BarisReviewFoto> get _belumDiisi => [
    for (final b in widget.baris)
      if (wajibDiisi(b) && _isian[_kunci(b)]!.text.trim().isEmpty) b,
  ];

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.fotoReviewPengantar,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.baris.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (_, i) => _baris(widget.baris[i], l10n),
            ),
          ),
          SafeArea(
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (belumDicek.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.fotoReviewBelumDicek(belumDicek.length),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    // Sengaja TIDAK ada tombol "terima semua" di sebelahnya —
                    // lihat aturan 1 di docblock kelas ini.
                    onPressed: belum.isEmpty && belumDicek.isEmpty
                        ? _selesai
                        : null,
                    child: Text(l10n.fotoReviewMasukkan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baris(BarisReviewFoto b, AppLocalizations l10n) {
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
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
                b.keyakinan == null
                    ? l10n.fotoReviewKeyakinanTakAda
                    : l10n.fotoReviewKeyakinan((b.keyakinan! * 100).round()),
                style: TextStyle(color: warna, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
