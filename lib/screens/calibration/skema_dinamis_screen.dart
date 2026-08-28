import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/skema_dokumen.dart';
import '../../services/vonis_sel_foto.dart';

/// Form yang bentuknya lahir dari DOKUMEN, bukan dari kode.
///
/// ## Kenapa layar ini ada
///
/// Sembilan belas lembar produksi digambar `LembarKerjaTabel` dkk dari schema
/// yang dikirim server — dan itu tidak diganggu. Yang di sini untuk lembar yang
/// **belum punya bentuk baku sama sekali**: baru difoto, belum ada profil,
/// belum ada geometri. Tanpa layar ini, seluruh rantai generik berhenti di
/// `SkemaDokumen` dan tidak pernah sampai ke tangan teknisi.
///
/// Tidak ada satu pun nama alat, daftar field, maupun daftar kolom di berkas
/// ini. Begitu ada, jalur generiknya mati dan yang tersisa parser dengan nama
/// lain.
///
/// ## Yang SENGAJA tidak dilakukan
///
/// Layar ini **tidak menghitung apa pun**. Dia membaca dan menyodorkan; angka
/// yang dikumpulkannya masuk sebagai bacaan mentah. Sertifikat tetap lahir dari
/// mesin GUM deterministik dengan profil alat yang sah — lembar yang belum
/// dikenal tidak boleh menerbitkan sertifikat lewat pintu belakang.
class SkemaDinamisScreen extends StatefulWidget {
  const SkemaDinamisScreen({super.key, required this.skema});

  final SkemaDokumen skema;

  @override
  State<SkemaDinamisScreen> createState() => _SkemaDinamisScreenState();
}

class _SkemaDinamisScreenState extends State<SkemaDinamisScreen> {
  late final List<TextEditingController> _kolom = [
    for (final k in widget.skema.kolom)
      TextEditingController(
        // Aturan yang sama dengan `FotoReviewScreen`: yang divonis nggak bisa
        // dipercaya mulai KOSONG, supaya teknisi mengetik — bukan menyetujui
        // angka yang kebetulan sudah terpampang.
        text: k.vonis.nilainyaDitampilkan ? k.nilai : '',
      ),
  ];

  late final List<List<List<TextEditingController>>> _tabel = [
    for (final t in widget.skema.tabel)
      [
        for (final b in t.baris)
          [for (final sel in b) TextEditingController(text: sel)],
      ],
  ];

  @override
  void dispose() {
    for (final c in _kolom) {
      c.dispose();
    }
    for (final t in _tabel) {
      for (final b in t) {
        for (final c in b) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  /// Kolom merah yang kotaknya masih kosong — penghalang tombol Simpan.
  ///
  /// Aturan yang SAMA dengan `FotoReviewScreen`, dan disamakan dengan sengaja.
  /// Layar ini mengosongkan nilai bervonis merah (lihat `_kolom`), jadi tanpa
  /// penghalang ini teknisi bisa menyimpan persis apa yang dikosongkannya —
  /// bacaan yang divonis tidak bisa dipercaya pulang sebagai isian KOSONG, dan
  /// yang membacanya nanti tidak punya cara membedakannya dari kolom yang
  /// dokumennya sendiri memang tidak mengisinya.
  ///
  /// Merah saja, sama seperti di sana: kuning & tidak-diketahui cukup DILIHAT.
  /// Menuntut teknisi mengetik ulang setiap sel yang bacaannya sudah benar
  /// bikin dia berhenti memakai fiturnya.
  List<int> get _belumDiisi => [
    for (var i = 0; i < widget.skema.kolom.length; i++)
      if (widget.skema.kolom[i].vonis == VonisFoto.merah &&
          _kolom[i].text.trim().isEmpty)
        i,
  ];

  void _simpan() {
    final skema = widget.skema;

    Navigator.of(context).pop<SkemaDokumen>((
      judul: skema.judul,
      kolom: [
        for (var i = 0; i < skema.kolom.length; i++)
          (
            label: skema.kolom[i].label,
            nilai: _kolom[i].text.trim(),
            jenis: skema.kolom[i].jenis,
            satuan: skema.kolom[i].satuan,
            // Keyakinan & vonis OCR ASLINYA dibawa apa adanya. Sel yang
            // diketik ulang teknisi memang nggak punya keyakinan mesin, dan
            // menaikkannya jadi 1.0 bikin jejaknya hilang — nggak ada lagi
            // cara membedakan mana yang dibaca mesin dan mana yang diketik
            // orang.
            keyakinan: skema.kolom[i].keyakinan,
            vonis: skema.kolom[i].vonis,
            kotak: skema.kolom[i].kotak,
          ),
      ],
      tabel: [
        for (var i = 0; i < skema.tabel.length; i++)
          (
            kepala: skema.tabel[i].kepala,
            baris: [
              for (final b in _tabel[i]) [for (final c in b) c.text.trim()],
            ],
            kotak: skema.tabel[i].kotak,
          ),
      ],
      peringatan: skema.peringatan,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.skema;
    final kosong = s.kolom.isEmpty && s.tabel.isEmpty;
    final belum = _belumDiisi;

    return Scaffold(
      appBar: AppBar(title: Text(s.judul ?? l10n.skemaDinamisJudul)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.skemaDinamisPengantar,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Peringatan dari penganalisis ditampilkan APA ADANYA. Yang
          // menyembunyikannya bikin teknisi mengira bacaannya utuh padahal
          // penganalisisnya sendiri ragu.
          for (final p in s.peringatan)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p)),
                ],
              ),
            ),

          if (kosong) Text(l10n.skemaDinamisKosong),

          for (var i = 0; i < s.kolom.length; i++) _isian(s.kolom[i], i, l10n),

          for (var i = 0; i < s.tabel.length; i++) ...[
            const SizedBox(height: 24),
            Text(
              l10n.skemaDinamisTabel(i + 1),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _tabelWidget(s.tabel[i], i),
          ],

          const SizedBox(height: 24),
          if (belum.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.skemaDinamisMasihKosong(belum.length),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: kosong || belum.isNotEmpty ? null : _simpan,
            child: Text(l10n.skemaDinamisSimpan),
          ),
        ],
      ),
    );
  }

  Widget _isian(KolomSkema k, int i, AppLocalizations l10n) {
    final warna = switch (k.vonis) {
      VonisFoto.merah => Theme.of(context).colorScheme.error,
      VonisFoto.kuning || VonisFoto.tidakDiketahui => Colors.orange.shade800,
      VonisFoto.hijau => Colors.green.shade700,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                // Satuannya dari DOKUMEN. Kolom tanpa satuan disebut begitu,
                // bukan dikasih satuan bawaan — menebak satuan di lembar
                // kalibrasi itu mengarang.
                k.satuan ?? l10n.skemaDinamisTanpaSatuan,
                style: TextStyle(fontSize: 12, color: warna),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _kolom[i],
            // Mengetik harus MENGGAMBAR ULANG layarnya: tanpa ini tombol
            // Simpan tetap mati sesudah kolom merah terakhir diisi, dan yang
            // kelihatan teknisi cuma tombol yang rusak.
            onChanged: (_) => setState(() {}),
            keyboardType: k.jenis == JenisIsi.angka
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabelWidget(TabelSkema t, int i) => SingleChildScrollView(
    // Tabel dari dokumen tak dikenal bisa selebar apa pun — jumlah kolomnya
    // ditentukan kertasnya, bukan kode ini. Digulung mendatar, bukan
    // dipaksa muat.
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: [
        for (var k = 0; k < (t.kepala.isEmpty ? _lebar(t) : t.kepala.length); k++)
          DataColumn(label: Text(t.kepala.isEmpty ? '${k + 1}' : t.kepala[k])),
      ],
      rows: [
        for (var b = 0; b < _tabel[i].length; b++)
          DataRow(
            cells: [
              for (final c in _tabel[i][b])
                DataCell(
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: c,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  int _lebar(TabelSkema t) =>
      t.baris.isEmpty ? 0 : t.baris.first.length;
}
