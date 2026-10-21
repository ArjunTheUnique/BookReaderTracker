// ============================================================
// PLATFORM EDGE — M2 Book Intake adapters
// Version Stamp : v1.0
// Pairs with    : src/modules/m2_book_intake.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M2's logic must not touch file_picker, dart:io, pdfx or epubx
//   directly — that keeps the module testable with fakes. This file
//   is the "edge": the only place those platform packages appear.
//   The module declares the ports (FileAccess, PageExtractor); this
//   file implements them for a real device.
//
//   It is NOT imported by the module or by the test suite, so the
//   tests stay free of platform plugins. The app shell wires these
//   adapters in at startup.
//
// DO NOT put business rules here — only transport. All decisions
// live in m2_book_intake.dart.
// ============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import 'm1_library_store.dart';
import 'm2_book_intake.dart';

/// Adapts the frozen M1 module to the [LibraryStorePort] interface M2
/// depends on. Dart is nominally typed, so M1LibraryStore does not
/// automatically satisfy the port; this one-line wrapper is the wiring
/// the app shell uses at startup.
class M1LibraryStorePort implements LibraryStorePort {
  M1LibraryStorePort(this.store);
  final M1LibraryStore store;

  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope) =>
      store.handle(envelope);

  @override
  Future<String> healthCheck() => store.healthCheck();
}

/// The real file edge: uses file_picker to choose, dart:io to store.
class FilePickerFileAccess implements FileAccess {
  @override
  Future<PickedFile> pickAndRead() async {
    // file_picker 13: a STATIC pickFile() returns one PlatformFile, and
    // the bytes are read with readAsBytes() (there is no .bytes field).
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'epub'],
    );
    if (picked == null) {
      // A cancelled picker is treated as a refused permission (C7).
      throw FileAccessDenied('no file selected');
    }
    try {
      final Uint8List bytes = await picked.readAsBytes();
      return PickedFile(name: picked.name, bytes: bytes);
    } catch (e) {
      throw FileAccessDenied('file bytes unavailable (permission?): $e');
    }
  }

  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final File target = File('${dir.path}/$name');
      // Write then flush, so a crash cannot leave a half-written file
      // that later looks "corrupt" to the extractor.
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (e) {
      throw StorageCopyFailed('$e');
    }
  }

  @override
  Future<int> freeBytes() async {
    // Dart has no portable "free space" API on mobile. The copy above
    // still guards with try/catch → E7, so this reports "assume room".
    // A platform-specific implementation can replace this later.
    return 1 << 40;
  }
}

/// The real extraction edge: pdfx for PDF, epubx for EPUB.
class PdfEpubPageExtractor implements PageExtractor {
  @override
  Future<int> pageCount(String name, List<int> bytes) async {
    final String lower = name.toLowerCase();
    try {
      if (lower.endsWith('.pdf')) {
        // PDF has a real, fixed page count.
        final pdfx.PdfDocument doc =
            await pdfx.PdfDocument.openData(Uint8List.fromList(bytes));
        final int n = doc.pagesCount;
        await doc.close();
        return n;
      }
      if (lower.endsWith('.epub')) {
        // EPUB is reflowable — no fixed pages. Per the order's ruling,
        // total_pages = the spine item count (epubx exposes it as
        // Chapters, which is built from the spine).
        final epubx.EpubBook book = await epubx.EpubReader.readBook(bytes);
        return book.Chapters?.length ?? 0;
      }
    } catch (e) {
      throw ExtractionFailed('$e');
    }
    throw ExtractionFailed('unsupported extension for $name');
  }
}
