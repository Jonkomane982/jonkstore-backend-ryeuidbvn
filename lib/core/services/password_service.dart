import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:jonkstore/core/config/app_owner.dart';
import 'package:jonkstore/firebase_options.dart';

/// Service responsible for:
///   1. Password hashing (salted SHA-256) for offline SQLite storage.
///   2. Firestore "owner_passwords" collection read/write for cloud backup.
class PasswordService {
  final FirebaseFirestore? _firestore;
  static const String kCollection = 'owner_passwords';
  static const int _saltBytes = 16;

  PasswordService([FirebaseFirestore? firestore])
    : _firestore = _firebaseConfigIsPlaceholder
          ? null
          : (firestore ?? FirebaseFirestore.instance);

  static bool get _firebaseConfigIsPlaceholder {
    final opts = DefaultFirebaseOptions.currentPlatform;
    return opts.apiKey == 'placeholder' ||
        opts.appId == 'placeholder' ||
        opts.messagingSenderId == 'placeholder';
  }

  bool get isFirestoreAvailable => _firestore != null;

  String generateSalt() {
    final rng = Random.secure();
    final bytes = Uint8List(_saltBytes);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  String hashPassword(String password, {String? salt}) {
    final effectiveSalt = salt ?? generateSalt();
    final bytes = utf8.encode('$effectiveSalt\$jonkstore::owner\$$password');
    final digest = sha256.convert(bytes);
    return '$effectiveSalt.${digest.toString()}';
  }

  bool verifyPassword(String password, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    final parts = storedHash.split('.');
    if (parts.length != 2) return false;
    final salt = parts.first;
    final newHash = hashPassword(password, salt: salt);
    return constantTimeEquals(newHash, storedHash);
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int r = 0;
    for (int i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  String _docId(String uid) => uid.isEmpty ? AppOwner.ownerEmail : uid;

  Future<void> upsertOwnerPasswordRecord({
    required String firebaseUid,
    required String passwordHash,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      final docId = _docId(firebaseUid);
      final docRef = firestore.collection(kCollection).doc(docId);
      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await docRef.get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'unavailable') {
          return;
        }
        rethrow;
      }

      final Map<String, dynamic> data = {
        'email': AppOwner.ownerEmail,
        'password_hash': passwordHash,
        'updated_at': now,
        if (!snapshot.exists) 'created_at': now,
      };

      try {
        if (snapshot.exists) {
          await docRef.update(data);
        } else {
          await docRef.set(data);
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'unavailable') {
          return;
        }
        rethrow;
      }
    } catch (_) {}
  }

  Future<String?> fetchLatestPasswordHash(String firebaseUid) async {
    final firestore = _firestore;
    if (firestore == null) return null;
    try {
      final doc = await firestore
          .collection(kCollection)
          .doc(_docId(firebaseUid))
          .get();
      return doc.data()?['password_hash'] as String?;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unavailable') {
        return null;
      }
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
