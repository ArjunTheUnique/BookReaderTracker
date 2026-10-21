// ============================================================
// INTEGRATION FILE — INT-1 src/app/main.dart  (app entry point)
// Version Stamp : v1.0.2
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE LIVES HERE
//   `src/` is outside the folders Dart's tooling scans by default, so the
//   build names this file explicitly:
//       flutter build apk --release -t src/app/main.dart
//   There is no lib/ entry point: a file under lib/ cannot reach src/ by
//   either a relative import or a package: import, so the entry lives with
//   the app it boots.
//
// WHY THIS FILE EXISTS
//   Boots the app: builds the composition root (wiring), which opens M1 and
//   injects every module through its port, then hands the shell the
//   assembled app.
// ============================================================

import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'wiring.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppWiring wiring = await AppWiring.production();
  runApp(ShelfApp(wiring: wiring));
}
