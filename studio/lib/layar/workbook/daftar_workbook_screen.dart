import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sidik_calibration/services/auth_service.dart';

import '../../data/workbook_model.dart';
import '../../data/workbook_provider.dart';
import '../../l10n/studio_l10n.dart';
import '../../tema/tema_studio.dart';
import '../../tema/warna_studio.dart';
import 'riwayat_workbook_screen.dart';
import 'unggah_master_screen.dart';
import 'workbook_screen.dart';

/// Satu kelompok daftar workbook. [judul] `null` = "Belum dipetakan".
typedef KelompokWorkbook = ({String? judul, List<WorkbookRingkas> isi});

/// Satu baris daftar: workbook yang ditampilkan + sumber lain untuk alat
/// yang sama (disembunyikan di bawah "Sumber lain").
typedef BarisWorkbook = ({WorkbookRingkas utama, List<WorkbookRingkas> lain});

/// Nama workbook dinormalkan seperti `PetaProfilWorkbook::normalkan` server:
/// tanpa `.xlsm/.xlsx`, huruf kecil, selain huruf/angka/titik jadi spasi.
/// Ekspor CSV (`Master_Olah_Data_Micrometer_0-25mm`) dan `.xlsm`-nya
/// (`Master Olah Data Micrometer 0-25mm.xlsm`) jatuh ke nama yang sama.
String normalkanNamaWorkbook(String nama) => nama
    .toLowerCase()
    .replaceAll(RegExp(r'\.(xlsm|xlsx)$'), '')
    .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
    .trim();

/// Bila satu alat punya `.xlsm` DAN ekspor CSV, yang tampil `.xlsm` (Excel
/// asli: rumus + tata letak); CSV-nya dipindah ke [BarisWorkbook.lain].
/// Alat tanpa `.xlsm` tetap tampil apa adanya (tiap workbook satu baris).
/// Urutan baris = urutan [isi].
List<BarisWorkbook> pasangkanSumberWorkbook(List<WorkbookRingkas> isi) {
  final kelompok = <String, List<WorkbookRingkas>>{};
  for (final w in isi) {
    kelompok.putIfAbsent(normalkanNamaWorkbook(w.nama), () => []).add(w);
  }
  final hasil = <BarisWorkbook>[];
  final sudah = <String>{};
  for (final w in isi) {
    final kunci = normalkanNamaWorkbook(w.nama);
    final anggota = kelompok[kunci]!;
    final xlsm = anggota.where((a) => a.sumber == SumberWorkbook.xlsm);
    if (xlsm.isEmpty) {
      hasil.add((utama: w, lain: const []));
      continue;
    }
    if (!sudah.add(kunci)) continue;
    final utama = xlsm.first;
    hasil.add((
      utama: utama,
      lain: [
        for (final a in anggota)
          if (!identical(a, utama)) a,
      ],
    ));
  }
  return hasil;
}

/// Kelompokkan per keluarga alat (cadangan: kode profil). Workbook TANPA
/// `kode_profil` masuk satu kelompok "Belum dipetakan" di paling bawah —
/// walau `keluarga`-nya terisi: yang menentukan "sudah tersambung ke alat"
/// adalah profilnya.
List<KelompokWorkbook> kelompokkanWorkbook(List<WorkbookRingkas> daftar) {
  final peta = <String, List<WorkbookRingkas>>{};
  final belum = <WorkbookRingkas>[];
  for (final w in daftar) {
    if (!w.dipetakan) {
      belum.add(w);
      continue;
    }
    peta.putIfAbsent(w.keluarga ?? w.kodeProfil!, () => []).add(w);
  }
  int urutNama(WorkbookRingkas a, WorkbookRingkas b) =>
      a.nama.toLowerCase().compareTo(b.nama.toLowerCase());

  final kunci = peta.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final k in kunci) (judul: k, isi: peta[k]!..sort(urutNama)),
    if (belum.isNotEmpty) (judul: null, isi: belum..sort(urutNama)),
  ];
}

/// Workbook Alat — daftar (S1b). Grid "Asli Excel" di [WorkbookScreen].
///
/// Gerbang izin `workbook.lihat` dipasang di seksi (`SeksiStudio.boleh`):
/// tanpa izin layar ini tidak pernah dibangun dan servernya tidak ditembak.
class DaftarWorkbookScreen extends ConsumerStatefulWidget {
  const DaftarWorkbookScreen({super.key});

  @override
  ConsumerState<DaftarWorkbookScreen> createState() =>
      _DaftarWorkbookScreenState();
}

class _DaftarWorkbookScreenState extends ConsumerState<DaftarWorkbookScreen> {
  final _cari = TextEditingController();
  Timer? _tunda;
  String _kueri = '';

  @override
  void dispose() {
    _tunda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _ketik(String teks) {
    _tunda?.cancel();
    _tunda = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _kueri = teks.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final KunciDaftarWorkbook kunci = (kodeProfil: null, cari: _kueri);
    final daftar = ref.watch(daftarWorkbookProvider(kunci));

    final kepala = Padding(
      padding: const EdgeInsets.fromLTRB(
        UkuranStudio.j6,
        UkuranStudio.j4,
        UkuranStudio.j6,
        UkuranStudio.j3,
      ),
      child: Wrap(
        spacing: UkuranStudio.j4,
        runSpacing: UkuranStudio.j3,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              l10n.workbookKet,
              style: teks.bodyMedium?.copyWith(color: w.teks2),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('tombol-unggah-master'),
            onPressed: () => bukaUnggahMaster(context),
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(l10n.unggahMasterTombol),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _cari,
              onChanged: _ketik,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.workbookCari,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget isi = switch (daftar) {
      AsyncData(:final value) when value.isEmpty => _Keadaan(
        ikon: Icons.grid_off_outlined,
        judul: _kueri.isEmpty
            ? l10n.workbookKosong
            : l10n.workbookTidakCocok(_kueri),
        keterangan: _kueri.isEmpty ? l10n.workbookKosongKet : null,
      ),
      AsyncData(:final value) => _DaftarKelompok(
        kelompok: kelompokkanWorkbook(value),
      ),
      AsyncError(:final error) => _Keadaan(
        ikon: Icons.cloud_off_outlined,
        judul: error is AuthException && error.message.isNotEmpty
            ? error.message
            : l10n.workbookGagalMuat,
        aksi: FilledButton.icon(
          onPressed: () => ref.invalidate(daftarWorkbookProvider(kunci)),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.cobaLagi),
        ),
      ),
      _ => Center(
        child: Semantics(
          label: l10n.memuat,
          child: const CircularProgressIndicator(),
        ),
      ),
    };

    return ColoredBox(
      color: w.latar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kepala,
          Expanded(child: isi),
        ],
      ),
    );
  }
}

class _DaftarKelompok extends StatelessWidget {
  const _DaftarKelompok({required this.kelompok});

  final List<KelompokWorkbook> kelompok;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        UkuranStudio.j6,
        0,
        UkuranStudio.j6,
        UkuranStudio.j6,
      ),
      children: [
        for (final k in kelompok)
          Padding(
            padding: const EdgeInsets.only(bottom: UkuranStudio.j4),
            child: Card(
              key: ValueKey('kelompok-${k.judul ?? '-'}'),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: w.permukaanRendah,
                    padding: const EdgeInsets.symmetric(
                      horizontal: UkuranStudio.j4,
                      vertical: UkuranStudio.j2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              k.judul ?? l10n.workbookBelumDipetakan,
                              style: teks.titleSmall,
                            ),
                          ),
                        ),
                        Text(
                          '${k.isi.length}',
                          style: TipografiStudio.angka(
                            ukuran: 12,
                            warna: w.teks2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (k.judul == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UkuranStudio.j4,
                        UkuranStudio.j2,
                        UkuranStudio.j4,
                        0,
                      ),
                      child: Text(
                        l10n.workbookBelumDipetakanKet,
                        style: teks.bodySmall,
                      ),
                    ),
                  for (final (i, baris) in pasangkanSumberWorkbook(
                    k.isi,
                  ).indexed) ...[
                    if (i > 0) Divider(color: w.garis),
                    _BarisDenganSumberLain(baris: baris),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Baris workbook utama + (bila ada) tombol "Riwayat (n)" (K-49-13: versi
/// lama master ini, layar sendiri) dan "Sumber lain (n)" (server lama: ekspor
/// CSV alat yang sama, dibuka di bawahnya).
class _BarisDenganSumberLain extends StatefulWidget {
  const _BarisDenganSumberLain({required this.baris});

  final BarisWorkbook baris;

  @override
  State<_BarisDenganSumberLain> createState() => _BarisDenganSumberLainState();
}

class _BarisDenganSumberLainState extends State<_BarisDenganSumberLain> {
  bool _buka = false;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final b = widget.baris;
    final jumlahRiwayat = b.utama.riwayat ? 0 : b.utama.jumlahRiwayat;
    if (b.lain.isEmpty && jumlahRiwayat == 0) {
      return _BarisWorkbook(workbook: b.utama);
    }
    final gayaTombol = TextButton.styleFrom(
      foregroundColor: w.teks2,
      visualDensity: VisualDensity.compact,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BarisWorkbook(workbook: b.utama),
        Padding(
          padding: const EdgeInsets.only(
            left: UkuranStudio.j8 + UkuranStudio.j3,
            bottom: UkuranStudio.j1,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: UkuranStudio.j2,
              children: [
                if (jumlahRiwayat > 0)
                  Tooltip(
                    message: l10n.workbookRiwayatKet,
                    child: TextButton.icon(
                      key: ValueKey('riwayat-${b.utama.id}'),
                      style: gayaTombol,
                      onPressed: () => bukaRiwayatWorkbook(context, b.utama),
                      icon: const Icon(Icons.history),
                      label: Text(l10n.workbookRiwayat(jumlahRiwayat)),
                    ),
                  ),
                if (b.lain.isNotEmpty)
                  Tooltip(
                    message: l10n.workbookSumberLainKet,
                    child: TextButton.icon(
                      key: ValueKey('sumber-lain-${b.utama.id}'),
                      style: gayaTombol,
                      onPressed: () => setState(() => _buka = !_buka),
                      icon: Icon(_buka ? Icons.expand_less : Icons.expand_more),
                      label: Text(l10n.workbookSumberLain(b.lain.length)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_buka)
          for (final lain in b.lain)
            Padding(
              padding: const EdgeInsets.only(left: UkuranStudio.j6),
              child: _BarisWorkbook(workbook: lain),
            ),
      ],
    );
  }
}

class _BarisWorkbook extends StatelessWidget {
  const _BarisWorkbook({required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final wb = workbook;
    final waktu = wb.diimporPada;

    return InkWell(
      key: ValueKey('workbook-${wb.id}'),
      onTap: () => bukaWorkbook(context, wb),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UkuranStudio.j4,
          vertical: UkuranStudio.j3,
        ),
        child: LayoutBuilder(
          builder: (context, batas) {
            final lebar = batas.maxWidth >= 640;
            return Row(
              children: [
                Icon(Icons.grid_on_outlined, size: 18, color: w.teks2),
                const SizedBox(width: UkuranStudio.j3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wb.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: teks.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wb.kodeProfil ?? l10n.workbookBelumDipetakan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: wb.kodeProfil == null
                            ? teks.bodySmall?.copyWith(color: w.teksRedup)
                            : TipografiStudio.angka(ukuran: 12, warna: w.teks2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: UkuranStudio.j3),
                if (wb.versi != null) ...[
                  LencanaImporWorkbook(workbook: wb),
                  const SizedBox(width: UkuranStudio.j2),
                ],
                LencanaSumberWorkbook(workbook: wb),
                const SizedBox(width: UkuranStudio.j3),
                SizedBox(
                  width: 84,
                  child: Text(
                    l10n.workbookJumlahLembar(wb.jumlahLembar),
                    textAlign: TextAlign.end,
                    style: teks.bodySmall,
                  ),
                ),
                if (lebar) ...[
                  const SizedBox(width: UkuranStudio.j3),
                  SizedBox(
                    width: 150,
                    child: Text(
                      waktu == null
                          ? ''
                          : l10n.workbookDiimpor(
                              DateFormat.yMMMd(locale).format(waktu.toLocal()),
                            ),
                      textAlign: TextAlign.end,
                      style: teks.bodySmall?.copyWith(color: w.teksRedup),
                    ),
                  ),
                ],
                const SizedBox(width: UkuranStudio.j1),
                Icon(Icons.chevron_right, size: 18, color: w.teksRedup),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lencana `Excel asli` / `CSV` — sumber menentukan apa yang BISA
/// ditampilkan (CSV: nilai saja; xlsm: + rumus & tata letak), jadi selalu
/// terlihat.
class LencanaSumberWorkbook extends StatelessWidget {
  const LencanaSumberWorkbook({super.key, required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final (label, latar, tinta, ket) = switch (workbook.sumber) {
      SumberWorkbook.xlsm => (
        l10n.workbookLencanaExcelAsli,
        w.aksenTipis,
        w.aksenTeks,
        l10n.workbookSumberXlsm,
      ),
      SumberWorkbook.csv => (
        'CSV',
        w.infoTipis,
        w.info,
        l10n.workbookSumberCsv,
      ),
      SumberWorkbook.lain => (
        workbook.sumberMentah.toUpperCase(),
        w.permukaanRendah,
        w.teks2,
        workbook.sumberMentah,
      ),
    };
    return Tooltip(
      message: ket,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: latar,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: tinta,
          ),
        ),
      ),
    );
  }
}

/// "Impor #n" — `versi` (K-49-13) = urutan impor master di jenisnya, BUKAN
/// penanda kebaruan (riwayat bisa bernomor lebih besar dari master aktif).
/// Tidak tampil bila server tidak mengirimnya.
class LencanaImporWorkbook extends StatelessWidget {
  const LencanaImporWorkbook({super.key, required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final versi = workbook.versi;
    if (versi == null) return const SizedBox.shrink();
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    return Tooltip(
      message: l10n.workbookImporKet(versi),
      child: Text(
        l10n.workbookImpor(versi),
        key: ValueKey('impor-${workbook.id}'),
        maxLines: 1,
        style: TipografiStudio.angka(ukuran: 11, warna: w.teks2),
      ),
    );
  }
}

/// "Master aktif" / "Riwayat" — status jenis (K-49-13), diambil dari
/// `status`/`digantikan_oleh_id`, tidak pernah dari nomor impor.
class LencanaStatusWorkbook extends StatelessWidget {
  const LencanaStatusWorkbook({super.key, required this.workbook});

  final WorkbookRingkas workbook;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioL10n.of(context);
    final w = WarnaStudio.of(context);
    final riwayat = workbook.riwayat;
    return Container(
      key: ValueKey('status-${workbook.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: riwayat ? w.awasTipis : w.lulusTipis,
        borderRadius: BorderRadius.circular(UkuranStudio.sudut),
      ),
      child: Text(
        riwayat ? l10n.workbookStatusRiwayat : l10n.workbookStatusAktif,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: riwayat ? w.awas : w.lulus,
        ),
      ),
    );
  }
}

class _Keadaan extends StatelessWidget {
  const _Keadaan({
    required this.ikon,
    required this.judul,
    this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String? keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaStudio.of(context);
    final teks = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UkuranStudio.j6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 36, color: w.teksRedup),
              const SizedBox(height: UkuranStudio.j3),
              Text(judul, textAlign: TextAlign.center, style: teks.titleMedium),
              if (keterangan != null) ...[
                const SizedBox(height: UkuranStudio.j2),
                Text(
                  keterangan!,
                  textAlign: TextAlign.center,
                  style: teks.bodySmall,
                ),
              ],
              if (aksi != null) ...[
                const SizedBox(height: UkuranStudio.j4),
                aksi!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
