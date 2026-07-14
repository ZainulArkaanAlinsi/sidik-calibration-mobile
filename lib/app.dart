import 'package:flutter/material.dart';

import 'screens/shell/main_shell.dart';

class AsmoApp extends StatelessWidget {
  const AsmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASMO Mobile',
      debugShowCheckedModeBanner: false,
      // Tema sementara. Design system (palet, tipografi, komponen dasar)
      // dikerjakan Rabu 15 Jul dan bakal menggantikan ThemeData di bawah ini.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: const MainShell(),
    );
  }
}
