import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Tombol keypad angka layar review.
sealed class TombolKeypad {
  const TombolKeypad();
}

class TombolDigit extends TombolKeypad {
  const TombolDigit(this.digit);
  final String digit;
}

class TombolKoma extends TombolKeypad {
  const TombolKoma();
}

class TombolMinus extends TombolKeypad {
  const TombolMinus();
}

class TombolHapus extends TombolKeypad {
  const TombolHapus();
}

/// Panjang isian paling banyak (nilai di lembar paling panjang ±9 karakter).
const panjangMaksKeypad = 12;

/// Hasil menekan [tombol] pada isian [teks]. Murni, supaya bisa diuji.
///
///  - digit: ditambahkan di belakang;
///  - koma: ditambahkan bila belum ada pemisah (`,` atau `.`); tidak ada nol
///    yang disisipkan sendiri;
///  - minus: membalik tanda di depan (tekan lagi = hilang);
///  - hapus: membuang satu karakter terakhir.
///
/// Tidak menyalin apa pun dari sel lain.
String terapkanTombolKeypad(String teks, TombolKeypad tombol) {
  switch (tombol) {
    case TombolDigit(:final digit):
      return teks.length >= panjangMaksKeypad ? teks : '$teks$digit';
    case TombolKoma():
      if (teks.contains(',') ||
          teks.contains('.') ||
          teks.length >= panjangMaksKeypad) {
        return teks;
      }
      return '$teks,';
    case TombolMinus():
      return teks.startsWith('-') ? teks.substring(1) : '-$teks';
    case TombolHapus():
      return teks.isEmpty ? teks : teks.substring(0, teks.length - 1);
  }
}

/// Keypad layar boleh dipakai di perangkat ini? Hanya di layar yang lega:
/// tinggi ≥ 700 dp, skala huruf ≤ 1,15, dan bukan HP lanskap. Di luar itu
/// keypad ±330 dp menelan daftar sel (di 320×568 sisanya 8 dp), jadi review
/// memakai papan ketik sistem ditambah panel ringkas.
bool bolehKeypadLayar(MediaQueryData mq) {
  final skala = mq.textScaler.scale(10) / 10;
  final lanskapHp =
      mq.orientation == Orientation.landscape && mq.size.shortestSide < 600;

  return mq.size.height >= 700 && skala <= 1.15 && !lanskapHp;
}

/// Kepala panel isian cepat: sel yang sedang dipegang (judul, crop, angka yang
/// sedang tertulis di kotaknya) dan SISA sel yang masih harus beres. Penghitung
/// ada di sini karena panel menggantikan tombol Masukkan beserta penghitungnya
/// selama terbuka.
///
/// [teks] adalah isi kotak sel sekarang (usulan mesin atau ketikan teknisi),
/// BUKAN bacaan mentah mesin: sel merah mulai kosong dan tidak boleh
/// menampilkan bacaan yang ditahan.
class KepalaSelAktif extends StatelessWidget {
  const KepalaSelAktif({
    super.key,
    required this.judul,
    required this.sisa,
    required this.teks,
    this.potongan,
  });

  final String judul;
  final String sisa;
  final String teks;
  final Uint8List? potongan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Row(
      children: [
        if (potongan != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96, maxHeight: 36),
              child: Image.memory(
                potongan!,
                key: const ValueKey('keypad-crop'),
                fit: BoxFit.contain,
                // Potongan gagal didekode bukan alasan menjatuhkan panelnya.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                judul,
                key: const ValueKey('keypad-judul'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.labelMedium,
              ),
              Text(
                sisa,
                key: const ValueKey('keypad-sisa'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          teks.isEmpty ? '—' : teks,
          key: const ValueKey('keypad-teks'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.titleMedium,
        ),
      ],
    );
  }
}

/// Keypad angka di layar: digit, koma desimal, tombol minus, hapus, dan satu
/// tombol "konfirmasi dan lanjut" untuk sel yang sedang aktif.
///
/// Dipakai menggantikan papan ketik sistem supaya tombol minus dan koma pasti
/// ada (beberapa papan ketik angka tidak menyediakannya) dan supaya satu sel
/// selesai dengan satu ketukan. Hanya di layar lega ([bolehKeypadLayar]).
class KeypadAngka extends StatelessWidget {
  const KeypadAngka({
    super.key,
    required this.kepala,
    required this.onTombol,
    required this.onKonfirmasi,
    required this.onTutup,
    required this.labelKonfirmasi,
    required this.labelTutup,
    required this.labelHapus,
    required this.labelMinus,
    required this.bisaKonfirmasi,
    this.tinggiTombol = 44,
  });

  final Widget kepala;
  final void Function(TombolKeypad tombol) onTombol;
  final VoidCallback onKonfirmasi;
  final VoidCallback onTutup;
  final String labelKonfirmasi;
  final String labelTutup;
  final String labelHapus;
  final String labelMinus;
  final bool bisaKonfirmasi;

  /// Tinggi tiap tombol angka; disesuaikan pemanggil dengan tinggi layar.
  final double tinggiTombol;

  @override
  Widget build(BuildContext context) {
    Widget tombol(String isi, TombolKeypad t, {String? kunci, String? tip}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Tooltip(
              message: tip ?? isi,
              child: OutlinedButton(
                key: ValueKey('keypad-${kunci ?? isi}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, tinggiTombol),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => onTombol(t),
                child: Text(isi, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );

    Widget baris(List<Widget> isi) => Row(children: isi);

    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: kepala),
                IconButton(
                  key: const ValueKey('keypad-tutup'),
                  tooltip: labelTutup,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.keyboard_hide_outlined),
                  onPressed: onTutup,
                ),
              ],
            ),
            baris([
              tombol('7', const TombolDigit('7')),
              tombol('8', const TombolDigit('8')),
              tombol('9', const TombolDigit('9')),
            ]),
            baris([
              tombol('4', const TombolDigit('4')),
              tombol('5', const TombolDigit('5')),
              tombol('6', const TombolDigit('6')),
            ]),
            baris([
              tombol('1', const TombolDigit('1')),
              tombol('2', const TombolDigit('2')),
              tombol('3', const TombolDigit('3')),
            ]),
            baris([
              tombol(',', const TombolKoma(), kunci: 'koma'),
              tombol('0', const TombolDigit('0')),
              tombol('−', const TombolMinus(), kunci: 'minus', tip: labelMinus),
              tombol('⌫', const TombolHapus(), kunci: 'hapus', tip: labelHapus),
            ]),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                key: const ValueKey('konfirmasi-lanjut'),
                onPressed: bisaKonfirmasi ? onKonfirmasi : null,
                child: Text(labelKonfirmasi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel isian cepat TANPA tombol angka: dipakai di layar sempit / huruf besar
/// / HP lanskap, tempat papan ketik sistem yang mengetik. Isinya kepala sel
/// aktif dan tombol "konfirmasi dan lanjut" — keduanya tetap terlihat.
///
/// [kepala] `null` = mode mini (papan ketik sistem terbuka atau tinggi sisa
/// kecil): hanya sisa sel dan tombol konfirmasi dalam satu baris.
class PanelIsiCepatRingkas extends StatelessWidget {
  const PanelIsiCepatRingkas({
    super.key,
    required this.kepala,
    required this.sisaMini,
    required this.onKonfirmasi,
    required this.onTutup,
    required this.labelKonfirmasi,
    required this.labelTutup,
    required this.bisaKonfirmasi,
  });

  final Widget? kepala;

  /// Teks sisa sel untuk mode mini (kepala `null`).
  final String sisaMini;
  final VoidCallback onKonfirmasi;
  final VoidCallback onTutup;
  final String labelKonfirmasi;
  final String labelTutup;
  final bool bisaKonfirmasi;

  @override
  Widget build(BuildContext context) {
    final konfirmasi = FilledButton.tonal(
      key: const ValueKey('konfirmasi-lanjut'),
      onPressed: bisaKonfirmasi ? onKonfirmasi : null,
      child: Text(
        labelKonfirmasi,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final tutup = IconButton(
      key: const ValueKey('keypad-tutup'),
      tooltip: labelTutup,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.keyboard_hide_outlined),
      onPressed: onTutup,
    );

    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: kepala == null
            ? Row(
                children: [
                  Flexible(
                    child: Text(
                      sisaMini,
                      key: const ValueKey('keypad-sisa'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: konfirmasi),
                  tutup,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: kepala!),
                      tutup,
                    ],
                  ),
                  SizedBox(width: double.infinity, child: konfirmasi),
                ],
              ),
      ),
    );
  }
}
