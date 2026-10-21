// ============================================================
// PLATFORM EDGE — M6 Backup Vault adapters
// Version Stamp : v1.0.1  (compile fix: crypto import is prefixed)
// Pairs with    : src/modules/m6_backup_vault.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M6's logic must not import dart:io or the crypto package directly.
//   This is the edge: the only place those appear. The module declares
//   the FileVault, Cipher and LibraryVaultPort ports; this file
//   implements them for a real device.
//
//   It is NOT imported by the module or by the module's test. It IS
//   imported by INT-1's wiring, which is where the compile errors this
//   version fixes were first seen.
//
// NOTE: the `cryptography` package also exports a class named `Cipher`,
//   which collided with M6's own `Cipher`. The crypto import is therefore
//   prefixed `crypto.` so M6's port name wins.
//
// DO NOT put business rules here — only transport.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;

import 'm1_library_store.dart';
import 'm6_backup_vault.dart';

/// The real file edge: reads and writes the .rtbk file with dart:io.
class IoFileVault implements FileVault {
  @override
  Future<void> write(String uri, List<int> bytes) async {
    try {
      await File(uri).writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw VaultIoError('$e');
    }
  }

  @override
  Future<List<int>> read(String uri) async {
    try {
      return await File(uri).readAsBytes();
    } catch (e) {
      throw VaultIoError('$e');
    }
  }
}

/// The real crypto edge: AES-256-GCM via `cryptography`. The 256-bit key
/// is derived from the passphrase with SHA-256; the file layout is
/// nonce || mac || ciphertext. A wrong passphrase or a tampered file
/// fails the GCM tag and becomes E9.
class CryptographyCipher implements Cipher {
  final crypto.AesGcm _algorithm = crypto.AesGcm.with256bits();

  Future<crypto.SecretKey> _key(String passphrase) async {
    final crypto.Hash hash =
        await crypto.Sha256().hash(utf8.encode(passphrase));
    return crypto.SecretKey(hash.bytes);
  }

  @override
  Future<List<int>> encrypt(List<int> plain, String passphrase) async {
    final crypto.SecretKey key = await _key(passphrase);
    final List<int> nonce = _algorithm.newNonce();
    final crypto.SecretBox box =
        await _algorithm.encrypt(plain, secretKey: key, nonce: nonce);
    return <int>[...nonce, ...box.mac.bytes, ...box.cipherText];
  }

  @override
  Future<List<int>> decrypt(List<int> cipher, String passphrase) async {
    try {
      final int nonceLen = _algorithm.nonceLength;
      const int macLen = 16;
      final List<int> nonce = cipher.sublist(0, nonceLen);
      final crypto.Mac mac =
          crypto.Mac(cipher.sublist(nonceLen, nonceLen + macLen));
      final List<int> text = cipher.sublist(nonceLen + macLen);
      final crypto.SecretKey key = await _key(passphrase);
      return await _algorithm.decrypt(
          crypto.SecretBox(text, nonce: nonce, mac: mac),
          secretKey: key);
    } catch (e) {
      throw CipherError('$e');
    }
  }
}

/// The M1 seam for M6.
///
/// NOTE: `snapshot()` works today (M1 read_catalog). `atomicReplace()`
/// CANNOT be implemented, because M1 v1.0.2 exposes no restore/replace
/// API. This is M6 finding F1 — an M1 fix order is required to add an
/// atomic `restore_all` operation before M6 can restore into real data.
class M1LibraryVault implements LibraryVaultPort {
  M1LibraryVault(this.store);
  final M1LibraryStore store;

  @override
  Future<Map<String, dynamic>> snapshot() async {
    final Map<String, dynamic> r = await store.handle(<String, dynamic>{
      'op': 'read_catalog',
      'payload': <String, dynamic>{},
      'idempotency_key': null,
      'schema_version': 1,
    });
    return (r['data'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> atomicReplace(Map<String, dynamic> snapshot) async {
    throw UnimplementedError(
        'M1 v1.0.2 has no atomic-replace API (M6 finding F1). '
        'Add an M1 restore_all operation first.');
  }

  @override
  Future<String> healthCheck() => store.healthCheck();
}
