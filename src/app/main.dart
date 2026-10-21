// ============================================================
// INTEGRATION FILE — INT-1 src/main.dart  (app entry point)
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   Boots the app: builds the composition root (wiring), which opens
//   M1 and injects every module through its port, then hands the
//   shell the assembled app.
// ============================================================

import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/wiring.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppWiring wiring = await AppWiring.production();
  runApp(ShelfApp(wiring: wiring));
}
