import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sakelar_ocr_provider.dart';
import '../../services/ocr_angka/muat_mesin_bawaan.dart';
import '../../services/ocr_angka/ukur_ocr.dart';
import '../../services/ocr_angka/ukur_ocr_jalankan.dart';
import '../../services/pembaca_sel.dart';
import '../../services/pembaca_sel_onnx.dart';

/// Layar diagnostik PENGEMBANG `Ukur OCR` — tidak tampil di rilis (lihat
/// [tampilkanUkurOcrAktif]); teksnya sengaja tidak dilokalkan.
///
/// Membaca folder crop + `labels.csv` dari penyimpanan perangkat (dititipkan
/// lewat `adb push`), menjalankan ML Kit atau mesin angka pada TIAP crop, lalu
/// menampilkan akurasi, cakupan, isi-palsu, dan latensi per sel, dan menyimpan
/// `hasil.csv` (`file,teks,keyakinan` + `status,ms`) di folder yang sama —
/// format kolom pertama sama dengan CSV yang dibaca `muat_foto_nyata.py
/// --mlkit`, jadi ML Kit dan mesin angka bisa dibandingkan pada data yang SAMA.
///
/// Tidak ada yang dikirim keluar HP: tidak ada jaringan di berkas ini.
class UkurOcrScreen extends ConsumerStatefulWidget {
  const UkurOcrScreen({super.key});

  @override
  ConsumerState<UkurOcrScreen> createState() => _UkurOcrScreenState();
}

enum _Mesin { mlKit, mesinAngka }

class _UkurOcrScreenState extends ConsumerState<UkurOcrScreen> {
  final _folder = TextEditingController();
  final _batas = TextEditingController(text: '300');
  final _ambang = TextEditingController(text: '0.990');
  final _desimalKosong = TextEditingController(text: '2');

  _Mesin _mesin = _Mesin.mlKit;
  bool _bertandaKosong = false;
  bool _jalan = false;
  bool _batal = false;
  int _selesai = 0;
  int _total = 0;
  String? _pesan;
  String? _ringkas;

  @override
  void initState() {
    super.initState();
    // Folder bawaan hanya kemudahan; gagal mencarinya (mis. test tanpa plugin)
    // berarti kotak folder diisi manual.
    folderOcrUkur().then((d) {
      if (mounted && _folder.text.isEmpty) _folder.text = d.path;
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _batal = true;
    _folder.dispose();
    _batas.dispose();
    _ambang.dispose();
    _desimalKosong.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    setState(() {
      _jalan = true;
      _batal = false;
      _selesai = 0;
      _pesan = null;
      _ringkas = null;
    });

    final folder = Directory(_folder.text.trim());
    PembacaSel? mlKit;
    PembacaSelOnnx? onnx;

    try {
      final berkasLabel = File('${folder.path}/labels.csv');
      if (!await berkasLabel.exists()) {
        throw StateError('labels.csv tidak ada di ${folder.path}');
      }
      final labels = bacaLabelsCsv(await berkasLabel.readAsString());
      if (labels.isEmpty) throw StateError('labels.csv kosong');

      final PembacaUkur baca;
      if (_mesin == _Mesin.mlKit) {
        baca = pembacaUkurMlKit(mlKit = MlKitPembacaSel());
      } else {
        final buatSesi = ref.read(buatSesiOcrAngkaProvider);
        onnx = PembacaSelOnnx(
          cadangan: MlKitPembacaSel(),
          muatMesin: () => muatMesinAngkaBawaan(
            buatSesi,
            // Layar ini hanya terjangkau di debug / dengan flag developer.
            izinkanSintetis: tampilkanUkurOcrAktif,
          ),
        );
        baca = pembacaUkurMesinAngka(
          onnx,
          ambang: double.tryParse(_ambang.text.trim()),
          desimalSelKosong: int.tryParse(_desimalKosong.text.trim()) ?? 2,
          bertandaSelKosong: _bertandaKosong,
        );
      }

      final hasil = await jalankanUkurFolder(
        folder: folder,
        labels: labels,
        baca: baca,
        batas: int.tryParse(_batas.text.trim()),
        progres: (s, t) {
          if (mounted && (s % 10 == 0 || s == t)) {
            setState(() {
              _selesai = s;
              _total = t;
            });
          }
        },
        dibatalkan: () => _batal,
      );

      final nama = _mesin == _Mesin.mlKit ? 'mlkit' : 'mesin_angka';
      final csv = hasilCsv(hasil);
      await File('${folder.path}/hasil.csv').writeAsString(csv);
      await File('${folder.path}/hasil_$nama.csv').writeAsString(csv);

      if (mounted) {
        setState(() {
          _ringkas = _tulisRingkasan(ringkasUkur(hasil), nama);
        });
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _pesan = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _pesan = e.message);
    } catch (e) {
      if (mounted) setState(() => _pesan = 'Gagal: $e');
    } finally {
      // `PembacaSelOnnx.tutup` menutup ML Kit cadangannya juga. Gagal menutup
      // tidak boleh menimpa hasil pengukuran.
      try {
        await (onnx ?? mlKit)?.tutup();
      } catch (_) {}
      if (mounted) setState(() => _jalan = false);
    }
  }

  String _tulisRingkasan(RingkasanUkur r, String nama) => [
    'Mesin: $nama',
    'Sel: ${r.jumlah} (berisi ${r.berisi}, kosong ${r.kosong})',
    'Cakupan (berisi yang dijawab): ${persenAtauStrip(r.cakupan)}',
    'Akurasi terjawab: ${persenAtauStrip(r.akurasiTerjawab)}',
    'Exact semua sel berisi: ${persenAtauStrip(r.exact)}',
    'Isi-palsu (kosong yang dijawab): ${persenAtauStrip(r.isiPalsuPersen)}',
    'Latensi per sel: median ${r.latensiMedian.toStringAsFixed(1)} ms, p95 ${r.latensiP95.toStringAsFixed(1)} ms',
    'Tersimpan: hasil.csv dan hasil_$nama.csv di folder yang sama.',
    'Catatan: angka ini hanya berlaku untuk data yang diukur; data SINTETIS '
        'bukan klaim akurasi lapangan.',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ukur OCR (pengembang)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Folder berisi labels.csv (kolom file,teks[,desimal,bertanda]) dan '
            'crop sel. Titipkan lewat adb push. Tidak ada yang dikirim keluar HP.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _folder,
            decoration: const InputDecoration(
              labelText: 'Folder',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Mesin>(
            segments: const [
              ButtonSegment(value: _Mesin.mlKit, label: Text('ML Kit')),
              ButtonSegment(
                value: _Mesin.mesinAngka,
                label: Text('Mesin angka'),
              ),
            ],
            selected: {_mesin},
            onSelectionChanged: _jalan
                ? null
                : (s) => setState(() => _mesin = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _batas,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Batas sel',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ambang,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ambang jalur',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _desimalKosong,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Desimal sel kosong',
                    helperText: 'bila kolom desimal kosong',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sel kosong boleh minus'),
                  value: _bertandaKosong,
                  onChanged: (v) =>
                      setState(() => _bertandaKosong = v ?? false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('ukur-ocr-mulai'),
            onPressed: _jalan ? null : _mulai,
            child: Text(_jalan ? 'Mengukur…' : 'Mulai ukur'),
          ),
          if (_jalan)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _total == 0 ? null : _selesai / _total,
                  ),
                  const SizedBox(height: 4),
                  Text('$_selesai / $_total'),
                  TextButton(
                    onPressed: () => setState(() => _batal = true),
                    child: const Text('Batalkan'),
                  ),
                ],
              ),
            ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _pesan!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_ringkas != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SelectableText(
                _ringkas!,
                key: const ValueKey('ukur-ocr-ringkasan'),
              ),
            ),
        ],
      ),
    );
  }
}
