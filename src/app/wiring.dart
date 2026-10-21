// ============================================================
// INTEGRATION FILE — INT-1 src/app/wiring.dart  (COMPOSITION ROOT)
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   This is the ONLY place that knows the concrete adapters. Every
//   module is built here and injected through its port. No module
//   imports another module; they meet only here.
//
// PORTS WIRED HERE (INT-1 section 2)
//   LibraryStorePort  -> M1LibraryStorePort        (M1 -> M2/M6)
//   FileAccess        -> FilePickerFileAccess      (M2)
//   PageExtractor     -> PdfEpubPageExtractor      (M2)
//   Clock             -> SystemClock               (M3, M4, M7)
//   DailySourcePort   -> _M1DailySource            (M4 over M1)
//   WidgetHost        -> HomeWidgetHost            (M5)
//   FileVault/Cipher  -> IoFileVault/Cryptography  (M6)
//   CatalogPort       -> _M1Catalog                (M7 over M1)
//   DailyViewPort     -> _M4DailyView              (M7 over M4)
//   ProgressLoggerPort-> M3ProgressLoggerAdapter   (M3)
//   ProgressStorePort -> M1ProgressStorePort       (M3 over M1)
//
// M3 NOTE (v1.0.2): M3 Progress Logger was delivered at v1.0, so the
//   temporary M1-backed stand-in is gone. The shell's progress path now
//   runs through the real module.
//
// DO NOT TOUCH the wiring table, the goal_pages source, or the rule
//   that the UI reads view-models from M7 only.
// ============================================================

import 'dart:async';

// M4 and M7 each declare their own Clock / socket ports (separate
// types), so this file uses import prefixes to keep them apart.
import '../modules/m1_library_store.dart';
import '../modules/m2_book_intake.dart';
import '../modules/m2_book_intake_adapters.dart';
import '../modules/m3_progress_logger.dart' as m3;
import '../modules/m4_daily_engine.dart' as engine;
import '../modules/m5_widget_bridge.dart';
import '../modules/m5_widget_bridge_adapters.dart';
import '../modules/m6_backup_vault.dart';
import '../modules/m6_backup_vault_adapters.dart';
import '../modules/m7_grid_presenter.dart' as m7grid;
import 'routes.dart';

// ---------------------------------------------------------------
// The M3 seam
// ---------------------------------------------------------------

/// The slice of M3 (Progress Logger) the shell needs.
abstract class ProgressLoggerPort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input);
  Future<String> healthCheck();
}

/// M3 behind INT-1's progress seam. The real module (v1.0) replaced the
/// temporary M1-backed stand-in at INT-1 v1.0.2; this adapter is the one
/// line Dart's nominal typing needs.
class M3ProgressLoggerAdapter implements ProgressLoggerPort {
  M3ProgressLoggerAdapter(this._m3);
  final m3.M3ProgressLogger _m3;

  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) =>
      _m3.handle(input);

  @override
  Future<String> healthCheck() => _m3.healthCheck();
}

/// M3's own M1 seam. M3 declares `ProgressStorePort`; Dart is nominally
/// typed, so it needs this one-line bridge to the frozen M1.
class M1ProgressStorePort implements m3.ProgressStorePort {
  M1ProgressStorePort(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

// ---------------------------------------------------------------
// Pure-Dart adapters (no platform code)
// ---------------------------------------------------------------

/// M4's DailySourcePort over M1.
class _M1DailySource implements engine.DailySourcePort {
  _M1DailySource(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

/// M7's CatalogPort over M1.
class _M1Catalog implements m7grid.CatalogPort {
  _M1Catalog(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

/// M7's DailyViewPort over M4.
class _M4DailyView implements m7grid.DailyViewPort {
  _M4DailyView(this._engine);
  final engine.M4DailyEngine _engine;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _engine.handle(e);
  @override
  Future<String> healthCheck() => _engine.healthCheck();
}

/// The one clock handed to M3, M4 and M7. It implements ALL THREE
/// modules' Clock interfaces, which are separate types (INT-1 finding F3
/// and M3 finding F5).
class SystemClock implements engine.Clock, m7grid.Clock, m3.Clock {
  @override
  DateTime now() => DateTime.now();
}

// ---------------------------------------------------------------
// The wiring
// ---------------------------------------------------------------

/// The assembled app: every module, ready, reached only through ports.
class AppWiring {
  AppWiring({
    required this.store,
    required this.intake,
    required this.progress,
    required this.daily,
    required this.widget,
    required this.backup,
    required this.grid,
    required this.routes,
    required this.clock,
    this.timezoneOffsetMin = 330,
  });

  final M1LibraryStore store;
  final M2BookIntake intake;
  final ProgressLoggerPort progress;
  final engine.M4DailyEngine daily;
  final M5WidgetBridge widget;
  final M6BackupVault backup;
  final m7grid.M7GridPresenter grid;
  final AppRoutes routes;
  final SystemClock clock;
  final int timezoneOffsetMin;

  /// Boot health (C1): seed if empty, then probe every seam.
  /// Returns 'ok' only when the whole chain answers.
  Future<String> bootHealth() async {
    await store.seedIfEmpty();
    final String m1 = await store.healthCheck();
    if (m1 != 'ok') return 'degraded: m1=$m1';
    final String m4 = await daily.healthCheck();
    if (m4 != 'ok') return 'degraded: m4=$m4';
    final String m7 = await grid.healthCheck();
    if (m7 != 'ok') return 'degraded: m7=$m7';
    return 'ok';
  }

  /// PRODUCTION: build the real adapters and open the app-private DB.
  static Future<AppWiring> production() async {
    final M1LibraryStore store = await M1LibraryStore.openDefault();
    final SystemClock clock = SystemClock();
    final engine.M4DailyEngine daily =
        engine.M4DailyEngine(m1: _M1DailySource(store), clock: clock);
    return AppWiring(
      store: store,
      intake: M2BookIntake(
        fileAccess: FilePickerFileAccess(),
        extractor: PdfEpubPageExtractor(),
        m1: M1LibraryStorePort(store),
      ),
      progress: M3ProgressLoggerAdapter(
        m3.M3ProgressLogger(store: M1ProgressStorePort(store), clock: clock),
      ),
      daily: daily,
      widget: M5WidgetBridge(host: HomeWidgetHost()),
      backup: M6BackupVault(
        files: IoFileVault(),
        cipher: CryptographyCipher(),
        library: M1LibraryVault(store),
      ),
      grid: m7grid.M7GridPresenter(
        catalog: _M1Catalog(store),
        daily: _M4DailyView(daily),
        clock: clock,
      ),
      routes: const AppRoutes(),
      clock: clock,
    );
  }

  /// TEST: same wiring, but every platform edge is injected. Used by the
  /// end-to-end suite so no plugin is called.
  static AppWiring forTest({
    required M1LibraryStore store,
    required WidgetHost widgetHost,
    FileAccess? fileAccess,
    PageExtractor? extractor,
    FileVault? files,
    Cipher? cipher,
    LibraryVaultPort? library,
    SystemClock? clock,
    int timezoneOffsetMin = 330,
  }) {
    final SystemClock theClock = clock ?? SystemClock();
    final engine.M4DailyEngine daily =
        engine.M4DailyEngine(m1: _M1DailySource(store), clock: theClock);
    return AppWiring(
      store: store,
      intake: M2BookIntake(
        fileAccess: fileAccess ?? _NoFileAccess(),
        extractor: extractor ?? _NoExtractor(),
        m1: M1LibraryStorePort(store),
      ),
      progress: M3ProgressLoggerAdapter(
        m3.M3ProgressLogger(store: M1ProgressStorePort(store), clock: theClock),
      ),
      daily: daily,
      widget: M5WidgetBridge(host: widgetHost),
      backup: M6BackupVault(
        files: files ?? _MemoryVault(),
        cipher: cipher ?? _PassthroughCipher(),
        library: library ?? M1LibraryVault(store),
      ),
      grid: m7grid.M7GridPresenter(
        catalog: _M1Catalog(store),
        daily: _M4DailyView(daily),
        clock: theClock,
        timezoneOffsetMin: timezoneOffsetMin,
      ),
      routes: const AppRoutes(),
      clock: theClock,
      timezoneOffsetMin: timezoneOffsetMin,
    );
  }
}

// ---------------------------------------------------------------
// Harmless defaults for forTest when a port is not overridden.
// ---------------------------------------------------------------

class _NoFileAccess implements FileAccess {
  @override
  Future<PickedFile> pickAndRead() async =>
      throw FileAccessDenied('no file access in test');
  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async =>
      throw StorageCopyFailed('no file access in test');
  @override
  Future<int> freeBytes() async => 1 << 40;
}

class _NoExtractor implements PageExtractor {
  @override
  Future<int> pageCount(String name, List<int> bytes) async =>
      throw ExtractionFailed('no extractor in test');
}

class _MemoryVault implements FileVault {
  final Map<String, List<int>> store = <String, List<int>>{};
  @override
  Future<void> write(String uri, List<int> bytes) async =>
      store[uri] = List<int>.from(bytes);
  @override
  Future<List<int>> read(String uri) async {
    final List<int>? b = store[uri];
    if (b == null) throw VaultIoError('missing');
    return b;
  }
}

class _PassthroughCipher implements Cipher {
  @override
  Future<List<int>> encrypt(List<int> plain, String passphrase) async =>
      List<int>.from(plain);
  @override
  Future<List<int>> decrypt(List<int> cipher, String passphrase) async =>
      List<int>.from(cipher);
}
