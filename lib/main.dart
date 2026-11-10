import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
// Dihasilkan otomatis oleh `flutterfire configure` — lihat catatan
// setup di README. Jangan commit file ini ke repo publik karena
// berisi konfigurasi project Firebase kalian.
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DifaPlusApp());
}
