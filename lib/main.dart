import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'services/mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cuma di build mock: pulihin riwayat sesi yang dibikin di pemakaian
  // sebelumnya. Tanpa ini semua lembar kerja yang diisi waktu ngetes ilang
  // begitu app ditutup — kelihatannya kayak data kehapus, padahal memang nggak
  // pernah disimpan. Lihat [MockStore].
  //
  // Di build asli nggak dipanggil sama sekali: riwayatnya datang dari backend,
  // dan nyimpen salinan lokal di sini cuma bikin dua sumber kebenaran.
  if (AppConfig.useMock) {
    await MockStore.instance.pulihkan(PenyimpanPrefs());
  }

  runApp(const ProviderScope(child: SidikApp()));
}
