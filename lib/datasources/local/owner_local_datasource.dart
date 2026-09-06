import 'package:sqflite/sqflite.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/database/database_constants.dart';
import 'package:jonkstore/database/database_service.dart';

/// Local data source for managing the application owner's profile.
class OwnerLocalDataSource {
  final DatabaseService _databaseService;

  OwnerLocalDataSource(this._databaseService);

  /// Saves the owner's profile to SQLite.
  ///
  /// Pass [txn] to participate in an existing SQLite transaction (e.g. together
  /// with a Business row insert) so both writes are atomic.
  Future<void> saveProfile(OwnerProfile profile, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableOwnerProfile,
      profile.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves the owner's profile from SQLite.
  Future<OwnerProfile?> getProfile() async {
    final db = await _databaseService.database;
    final results = await db.query(DatabaseConstants.tableOwnerProfile, limit: 1);
    if (results.isNotEmpty) {
      return OwnerProfile.fromJson(results.first);
    }
    return null;
  }

  /// Updates the verification status in the local profile.
  Future<void> updateVerificationStatus(bool isVerified) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableOwnerProfile,
      {
        DatabaseConstants.columnIsVerified: isVerified ? 1 : 0,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
      },
    );
  }

  /// Updates the locally-stored password hash.
  Future<void> updatePasswordHash(String passwordHash) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableOwnerProfile,
      {
        DatabaseConstants.columnPasswordHash: passwordHash,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
      },
    );
  }

  /// Deletes the local owner profile (useful for hard logout/reset).
  Future<void> deleteProfile() async {
    final db = await _databaseService.database;
    await db.delete(DatabaseConstants.tableOwnerProfile);
  }
}
