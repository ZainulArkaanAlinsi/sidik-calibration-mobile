import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab yang lagi aktif di bottom nav.
///
/// Ditaruh di provider (bukan `setState`) supaya nanti bisa dipindah dari
/// mana aja — mis. tombol "Lihat semua alat" di Dashboard yang mestinya
/// lompat ke tab Alat, atau notifikasi jatuh tempo yang buka tab Riwayat.
final selectedTabProvider = NotifierProvider<SelectedTab, int>(SelectedTab.new);

class SelectedTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
