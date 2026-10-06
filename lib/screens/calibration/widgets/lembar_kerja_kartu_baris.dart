import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/lembar_kerja.dart';
import '../lembar_kerja_state.dart';

/// Tabel-tabel sebaris digambar SATU KARTU PER BARIS — susunan kertas.
///
/// Dipakai bagian yang backend-nya menandai `tampilan: kartu_per_baris`.
/// Asalnya Anak Timbangan (SIDIK-FM-CAL-0541): kertasnya satu blok per keping
/// berisi Nominal AT, lalu Standard / UUT / UUT / Standard × X1 X2 X3. Digambar
/// sebagai empat tabel peran terpisah, teknisi harus menggulir naik-turun empat
/// kali untuk satu keping (laporan lapangan 5 Okt 2026). Pola yang sama berlaku
/// ke lembar lain yang barisnya dipakai bersama beberapa tabel: UP/DOWN
/// Tekanan & Proving Ring, empat posisi UTM/Load Cell, Standard/UUT
/// Thermohygro.
///
/// **Cuma tampilan.** Tiap kotak di sini controller yang SAMA dengan yang
/// dipakai tabel biasa ([LembarKerjaState.titikUntukBaris] → `kotak`,
/// `titikCtl`, `kotakBarisCtl`), jadi payload, draft, dan olah datanya tidak
/// tahu kartu ini ada.
class LembarKerjaKartuBaris extends StatelessWidget {
  const LembarKerjaKartuBaris({
    super.key,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
    this.sejajar = false,
    this.berbintang = true,
    this.vertikal = false,
  });

  /// Tabel sebaris, urut seperti di kertas. Yang PERTAMA jadi acuan: nominal
  /// dan kotak per barisnya dibaca payload dari situ.
  final List<TabelHasil> tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;

  /// Di layar lebar, tabel-tabel digambar berdampingan (`UP 1-3 | DOWN 1-3`),
  /// seperti satu baris kertas. Lihat [BagianLembarKerja.kartuSejajar].
  final bool sejajar;

  /// Tombol ★ di kotak nominal. Lihat [BagianLembarKerja.nominalBerbintang].
  final bool berbintang;

  /// Bacaan menurun, satu baris per pengulangan berlabel (`z`, `m`, `m'`,
  /// `z'`). Lihat [BagianLembarKerja.kartuVertikal].
  final bool vertikal;

  /// Lebar layar minimum untuk menggambar tabel berdampingan.
  static const lebarSejajar = 700.0;

  /// `Standard (S1) — penimbangan standar, pertama` → `Standard` — persis
  /// tulisan kertas (Standard / UUT / UUT / Standard). Urutan barisnya yang
  /// membedakan S1 dari S2, sama seperti di kertas.
  static String labelPendek(String judul) {
    final i = judul.indexOf(' —');
    final awal = (i < 0 ? judul : judul.substring(0, i)).trim();

    return awal.replaceFirst(RegExp(r'\s*\([^)]*\)$'), '').trim();
  }

  /// Tambah atau cabut bintang di akhir nominal (`20` ↔ `20*`).
  ///
  /// Tombol, bukan ketikan: keyboard angka di banyak HP tidak punya `*`, dan
  /// laporan lapangan 5 Okt 2026 memintanya bisa dari HP mana pun.
  static String alihBintang(String nominal) {
    final t = nominal.trim();
    return t.endsWith('*') ? t.replaceFirst(RegExp(r'\*+$'), '') : '$t*';
  }

  @override
  Widget build(BuildContext context) {
    if (tabel.isEmpty) return const SizedBox.shrink();

    final acuan = tabel.first;
    final barisAcuan = isian.barisTabel(acuan);

    return LayoutBuilder(
      builder: (context, ukuran) {
        final berdampingan = sejajar && ukuran.maxWidth >= lebarSejajar;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < barisAcuan.length; i++) ...[
              _Kartu(
                nomor: i + 1,
                indeks: i,
                tabel: tabel,
                isian: isian,
                onBerubah: onBerubah,
                berdampingan: berdampingan,
                berbintang: berbintang,
                vertikal: vertikal,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (isian.bisaTambahBaris(tabel.last))
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('tambah-baris'),
                  onPressed: () {
                    isian.tambahBaris();
                    onBerubah();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah baris'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({
    required this.nomor,
    required this.indeks,
    required this.tabel,
    required this.isian,
    required this.onBerubah,
    required this.berdampingan,
    required this.berbintang,
    required this.vertikal,
  });

  final int nomor;
  final int indeks;
  final List<TabelHasil> tabel;
  final LembarKerjaState isian;
  final VoidCallback onBerubah;
  final bool berdampingan;
  final bool berbintang;
  final bool vertikal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acuan = tabel.first;
    final barisAcuan = isian.barisTabel(acuan);
    final tsAcuan = isian.titikUntukBaris(barisAcuan, indeks, acuan);
    final satuan = isian.bentuk.satuan;
    final jumlahUlang = acuan.pengulangan.length;

    if (tsAcuan == null) return const SizedBox.shrink();

    // Set point tercetak (Thermohygro 15/25/35 °C) = label, bukan isian —
    // sama seperti kolom kiri tabel biasa.
    final ditentukan = barisAcuan[indeks].titikDitentukan;

    Widget kotakAngka(TextEditingController ctl, {Key? key}) => TextField(
      key: key,
      controller: ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      onChanged: (_) => onBerubah(),
    );

    final judulNominal = () {
      final judul = acuan.judulNilai ?? 'Nominal';
      return satuan.isEmpty ? judul : '$judul ($satuan)';
    }();

    // Kotak X1..Xn satu tabel. Indeks tabel dipakai di kunci, bukan
    // `kunciTabel`: keempat tabel ABBA berbagi kunci tabel yang sama
    // (dibedakan offset barisnya).
    Widget kotakTabel(int k, TabelHasil t, TitikState ts) {
      if (t.kolom.length == 1) {
        return Row(
          children: [
            for (var r = 0; r < t.pengulangan.length; r++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: kotakAngka(
                    ts.kotak(t.kunciTabel, t.kolom.first.kode, r),
                    key: ValueKey('kartu-t$k-$nomor-$r'),
                  ),
                ),
              ),
          ],
        );
      }

      // Tabel berkolom ganda (Flowrate: tiap ulangan dibaca di tiga durasi)
      // digambar sub-grid ulangan × kolom — susunan kertas 0538.A, satu set
      // point per kartu. Kuncinya ikut indeks kolom.
      final judulUlang = t.judulPengulangan ?? 'Ulangan';
      return Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 72),
              for (final c in t.kolom)
                Expanded(
                  child: Text(
                    c.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          for (var r = 0; r < t.pengulangan.length; r++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text('$judulUlang ${r + 1}', style: theme.textTheme.bodySmall),
                  ),
                  for (var c = 0; c < t.kolom.length; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: kotakAngka(
                          ts.kotak(t.kunciTabel, t.kolom[c].kode, r),
                          key: ValueKey('kartu-t$k-$nomor-$r-$c'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    Widget kepalaUlang(int jumlah) => Row(
      children: [
        for (var r = 0; r < jumlah; r++)
          Expanded(
            child: Text(
              'X${r + 1}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium,
            ),
          ),
      ],
    );

    final barisTabel = <Widget>[];
    final blokSejajar = <Widget>[];
    for (var k = 0; k < tabel.length; k++) {
      final t = tabel[k];
      final baris = isian.barisTabel(t);
      final ts = indeks < baris.length ? isian.titikUntukBaris(baris, indeks, t) : null;
      if (ts == null || t.kolom.isEmpty) continue;

      // Apa yang diketik dan satuannya — "Pembacaan Dial (Div)", "°C". Tanpa
      // ini teknisi Proving Ring pernah mengetik kgf ke kotak divisi
      // (tinjauan 6 Okt 2026). Tabel berkolom ganda menulis kolomnya di
      // sub-grid, jadi di sini cukup satuannya.
      final kolom = t.kolom.first;
      final satuanKotak = kolom.satuan ?? isian.bentuk.satuanUntuk(baris[indeks]);
      final keterangan = [
        if (t.kolom.length == 1 && kolom.label.isNotEmpty) kolom.label,
        if (satuanKotak.isNotEmpty) '($satuanKotak)',
      ].join(' ');
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LembarKerjaKartuBaris.labelPendek(t.judul),
            style: theme.textTheme.bodySmall,
          ),
          if (keterangan.isNotEmpty)
            Text(
              keterangan,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );

      if (vertikal && t.kolom.length == 1) {
        // Susunan kertas Timbangan: bacaan menurun, label dari
        // `pengulangan_arah` (`z`, `m`, `m'`, `z'`).
        barisTabel.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                for (var r = 0; r < t.pengulangan.length; r++)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 104,
                          child: Text(
                            t.pengulanganArah[r + 1] ?? 'X${r + 1}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: kotakAngka(
                            ts.kotak(t.kunciTabel, t.kolom.first.kode, r),
                            key: ValueKey('kartu-t$k-$nomor-$r'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      } else if (berdampingan) {
        blokSejajar.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label,
                  const SizedBox(height: AppSpacing.xs),
                  kepalaUlang(t.pengulangan.length),
                  kotakTabel(k, t, ts),
                ],
              ),
            ),
          ),
        );
      } else {
        barisTabel.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(width: 104, child: label),
                Expanded(child: kotakTabel(k, t, ts)),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      key: ValueKey('kartu-baris-$nomor'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kepala blok: nomor, nominal, dan kotak per baris (No. Seri keping)
          // — di kertas tempatnya `Nominal AT` dan `( )` di atas X1–X3.
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('$nomor.', style: theme.textTheme.titleSmall),
              ),
              Expanded(
                child: ditentukan
                    ? Text(
                        'Set point ${barisAcuan[indeks].label}',
                        key: ValueKey('kartu-nominal-$nomor'),
                        style: theme.textTheme.titleSmall,
                      )
                    : TextField(
                        key: ValueKey('kartu-nominal-$nomor'),
                        controller: tsAcuan.titikCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          labelText: judulNominal,
                          // Bintang keping kedua (`20*`) — seperti di kertas.
                          suffixIcon: berbintang
                              ? IconButton(
                                  key: ValueKey('kartu-bintang-$nomor'),
                                  tooltip: 'Bintang: keping kedua bernominal sama',
                                  icon: Icon(
                                    tsAcuan.berbintang ? Icons.star : Icons.star_border,
                                  ),
                                  onPressed: () {
                                    tsAcuan.titikCtl.text =
                                        LembarKerjaKartuBaris.alihBintang(tsAcuan.titikCtl.text);
                                    onBerubah();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => onBerubah(),
                      ),
              ),
              for (final f in acuan.kolomBaris)
                if (f.kode != 'no_probe') ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      // `kb` = kotak per baris. Tanpa awalan ini kolom `nominal`
                      // Timbangan bertabrakan dengan kunci kepala nominal.
                      key: ValueKey('kartu-kb-${f.kode}-$nomor'),
                      controller: tsAcuan.kotakBarisCtl(acuan.kunciTabel, f.kode),
                      // `daftar_angka` (susunan keping `20+20+10`) butuh
                      // tombol `+`, yang tidak ada di keyboard angka.
                      keyboardType: f.tipe == TipeField.teks || f.tipe == TipeField.daftarAngka
                          ? TextInputType.text
                          : const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText: f.label,
                      ),
                      onChanged: (_) => onBerubah(),
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (berdampingan)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: blokSejajar)
          else ...[
            // Kepala kolom X1..Xn — tidak dipakai di mode vertikal (label
            // bacaannya ada di tiap baris).
            if (!vertikal) Row(
              children: [
                const SizedBox(width: 104),
                Expanded(child: kepalaUlang(jumlahUlang)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ...barisTabel,
          ],
        ],
      ),
    );
  }
}
