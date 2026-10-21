// ============================================================
// MODULE PASSPORT — M6 Backup Vault
// Version Stamp : v1.0
// Module File   : src/modules/m6_backup_vault.dart
// Test File     : tests/test_m6_backup_vault.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M6)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Export the whole library as one encrypted .rtbk file and restore
//   it — validating schema version and checksum BEFORE any current
//   data is replaced.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT export  : { destination_uri, passphrase }
//   INPUT restore : { source_uri, passphrase }
//   OUTPUT success : { ok:true, data:{bytes, schema_version, checksum},
//                      schema_version:1 }
//   OUTPUT failure : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E7 STORAGE_ERROR ·
//                  E9 BACKUP_INVALID
//
// CONTROL PATH SUMMARY
//   No standalone switch; the source branch is export vs restore,
//   chosen by which uri key the request carries.
//
// DATA PATH SUMMARY (the D-pipe inside this file)
//   D6 backup pipe — export: snapshot → serialise → checksum →
//      encrypt → write. restore: read → decrypt → validate → replace.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: kPassphraseMinLength, kBackupCipher,
//   the checksum algorithm (keep it consistent), log messages.
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes, the
//   rule that a restore is VALIDATED BEFORE any overwrite, and the
//   rule that the passphrase is NEVER stored or logged.
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and prints
//   "[M6] <CODE>: <detail>". E9 means the backup was refused (wrong
//   passphrase, damaged file, or unknown schema) and your CURRENT data
//   was left untouched. E7 means the file could not be read or written.
// ============================================================

import 'dart:async';
import 'dart:convert';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// ============================================================

/// The contract version this module speaks, and the schema version it
/// writes into every backup file.
const int kSchemaVersion = 1;

/// Shortest passphrase M6 will accept.
const int kPassphraseMinLength = 8;

/// The cipher named in the backup metadata (informational).
const String kBackupCipher =
    String.fromEnvironment('BACKUP_CIPHER', defaultValue: 'AES-256-GCM');

/// Log verbosity label.
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// ============================================================

/// Raised by the platform edge when the .rtbk file cannot be read/written.
class VaultIoError implements Exception {
  VaultIoError([this.message = 'vault io failed']);
  final String message;
  @override
  String toString() => message;
}

/// Raised by the cipher when decryption fails (wrong passphrase or a
/// tampered file).
class CipherError implements Exception {
  CipherError([this.message = 'cipher failed']);
  final String message;
  @override
  String toString() => message;
}

/// The ONLY place M6 touches the filesystem. The real implementation
/// (dart:io) lives in the adapter file.
abstract class FileVault {
  Future<void> write(String uri, List<int> bytes);
  Future<List<int>> read(String uri);
}

/// The ONLY place M6 touches crypto. The real implementation
/// (cryptography, AES-256-GCM) lives in the adapter file.
abstract class Cipher {
  Future<List<int>> encrypt(List<int> plain, String passphrase);
  Future<List<int>> decrypt(List<int> cipher, String passphrase);
}

/// The M1 seam: snapshot the library, and replace it atomically.
abstract class LibraryVaultPort {
  Future<Map<String, dynamic>> snapshot();
  Future<void> atomicReplace(Map<String, dynamic> snapshot);
  Future<String> healthCheck();
}

/// The Backup Vault. Takes an export or a restore request and returns
/// a success or failure map.
class M6BackupVault {
  M6BackupVault({
    required this.files,
    required this.cipher,
    required this.library,
  });

  final FileVault files;
  final Cipher cipher;
  final LibraryVaultPort library;

  static const Set<String> _exportKeys = <String>{'destination_uri', 'passphrase'};
  static const Set<String> _restoreKeys = <String>{'source_uri', 'passphrase'};

  /// Route a request to export or restore by its shape.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    if (input.containsKey('destination_uri')) return export(input);
    if (input.containsKey('source_uri')) return restore(input);
    return _fail('E1', 'A request must be an export or a restore.');
  }

  /// export — snapshot, serialise, checksum, encrypt, write.
  Future<Map<String, dynamic>> export(Map<String, dynamic> input) async {
    final Map<String, dynamic>? bad =
        _checkCommon(input, _exportKeys, 'destination_uri');
    if (bad != null) return bad;
    final String uri = input['destination_uri'] as String;
    final String pass = input['passphrase'] as String;

    Map<String, dynamic> snap;
    try {
      snap = await library.snapshot();
    } catch (e) {
      return _fail('E7', 'Could not snapshot the library: $e');
    }

    // Plaintext = the serialised snapshot. The checksum is taken over
    // the PLAINTEXT (stated explicitly so restore can re-check it).
    final List<int> plain = utf8.encode(jsonEncode(snap));
    final String sum = _checksum(plain);

    List<int> cipherBytes;
    try {
      cipherBytes = await cipher.encrypt(plain, pass);
    } on CipherError catch (e) {
      return _fail('E9', 'Could not encrypt the backup: ${e.message}');
    } catch (e) {
      return _fail('E9', 'Could not encrypt the backup: $e');
    }

    final Map<String, dynamic> fileObj = <String, dynamic>{
      'schema_version': kSchemaVersion,
      'cipher': kBackupCipher,
      'checksum': sum,
      'payload': base64Encode(cipherBytes),
    };
    final List<int> fileBytes = utf8.encode(jsonEncode(fileObj));

    try {
      await files.write(uri, fileBytes);
    } on VaultIoError catch (e) {
      return _fail('E7', 'Could not write the backup file: ${e.message}');
    } catch (e) {
      return _fail('E7', 'Could not write the backup file: $e');
    }

    return _ok(<String, dynamic>{
      'bytes': fileBytes.length,
      'schema_version': kSchemaVersion,
      'checksum': sum,
    });
  }

  /// restore — read, decrypt, VALIDATE, and only then replace.
  Future<Map<String, dynamic>> restore(Map<String, dynamic> input) async {
    final Map<String, dynamic>? bad =
        _checkCommon(input, _restoreKeys, 'source_uri');
    if (bad != null) return bad;
    final String uri = input['source_uri'] as String;
    final String pass = input['passphrase'] as String;

    List<int> fileBytes;
    try {
      fileBytes = await files.read(uri);
    } on VaultIoError catch (e) {
      return _fail('E7', 'Could not read the backup file: ${e.message}');
    } catch (e) {
      return _fail('E7', 'Could not read the backup file: $e');
    }

    // --- parse + validate the header (nothing is overwritten yet) ----
    Map<String, dynamic> header;
    try {
      header = (jsonDecode(utf8.decode(fileBytes)) as Map).cast<String, dynamic>();
    } catch (e) {
      return _fail('E9', 'The backup file is not readable.');
    }
    final Object? sv = header['schema_version'];
    if (sv is! int || sv != kSchemaVersion) {
      return _fail('E9', 'Unknown backup schema version.');
    }
    final Object? sum = header['checksum'];
    if (sum is! String) {
      return _fail('E9', 'The backup file is missing its checksum.');
    }
    final Object? payloadB64 = header['payload'];
    if (payloadB64 is! String) {
      return _fail('E9', 'The backup file is missing its payload.');
    }

    // --- decrypt (wrong passphrase / tamper -> E9) ------------------
    List<int> plain;
    try {
      plain = await cipher.decrypt(base64Decode(payloadB64), pass);
    } on CipherError catch (e) {
      return _fail('E9', 'Wrong passphrase or the file is damaged: ${e.message}');
    } catch (e) {
      return _fail('E9', 'Wrong passphrase or the file is damaged.');
    }

    // --- checksum (tamper -> E9) ------------------------------------
    if (_checksum(plain) != sum) {
      return _fail('E9', 'Checksum mismatch — the backup file is damaged.');
    }

    Map<String, dynamic> snap;
    try {
      snap = (jsonDecode(utf8.decode(plain)) as Map).cast<String, dynamic>();
    } catch (e) {
      return _fail('E9', 'The backup contents are not readable.');
    }

    // --- ONLY NOW do we touch the live data (S8) --------------------
    try {
      await library.atomicReplace(snap);
    } catch (e) {
      return _fail('E7', 'The library could not be replaced: $e');
    }

    return _ok(<String, dynamic>{
      'bytes': fileBytes.length,
      'schema_version': kSchemaVersion,
      'checksum': sum,
    });
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS ===
  // ============================================================

  /// Shared boundary checks for both requests: key discipline, a
  /// non-empty uri, and a passphrase at least the minimum length.
  Map<String, dynamic>? _checkCommon(
      Map<String, dynamic> input, Set<String> allowed, String uriKey) {
    for (final String k in input.keys) {
      if (!allowed.contains(k)) {
        return _fail('E1', 'Unexpected field "$k".', k);
      }
    }
    for (final String k in allowed) {
      if (!input.containsKey(k)) {
        return _fail('E1', 'Missing required field "$k".', k);
      }
    }
    final Object? uri = input[uriKey];
    if (uri is! String || uri.isEmpty) {
      return _fail('E1', '$uriKey must be a non-empty string.', uriKey);
    }
    final Object? pass = input['passphrase'];
    if (pass is! String || pass.length < kPassphraseMinLength) {
      return _fail('E1',
          'passphrase must be at least $kPassphraseMinLength characters.', 'passphrase');
    }
    return null;
  }

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // ============================================================

  /// A hex checksum over the plaintext. Two independent FNV-1a 32-bit
  /// passes give a 64-bit fingerprint without importing a crypto lib.
  String _checksum(List<int> bytes) {
    final int a = _fnv1a32(bytes, 0x811c9dc5);
    final int b = _fnv1a32(bytes, 0x01000193);
    return a.toRadixString(16).padLeft(8, '0') +
        b.toRadixString(16).padLeft(8, '0');
  }

  static int _fnv1a32(List<int> bytes, int seed) {
    int h = seed & 0xFFFFFFFF;
    for (final int byte in bytes) {
      h ^= (byte & 0xFF);
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Health probe. Confirms the M1 seam answers.
  Future<String> healthCheck() async {
    try {
      final String h = await library.healthCheck();
      if (h != 'ok') return 'degraded: m1=$h';
      return 'ok';
    } catch (e) {
      return 'degraded: $e';
    }
  }

  Map<String, dynamic> _ok(Map<String, dynamic> data) => <String, dynamic>{
        'ok': true,
        'data': data,
        'schema_version': kSchemaVersion,
      };

  Map<String, dynamic> _fail(String code, String message, [String? field]) {
    // ignore: avoid_print
    print('[M6] $code: $message');
    return <String, dynamic>{
      'ok': false,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        if (field != null) 'field': field,
      },
    };
  }
}
