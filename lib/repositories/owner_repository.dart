import 'package:sqflite/sqflite.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/core/network/result.dart';

/// Interface for managing the application owner's profile.
abstract class OwnerRepository {
  /// Saves the owner profile locally.
  ///
  /// Pass [txn] to wrap the write inside an active SQLite transaction so
  /// Business + OwnerProfile inserts can be atomic.
  Future<Result<void>> saveProfile(OwnerProfile profile, {Transaction? txn});

  /// Retrieves the owner profile from local storage.
  Future<Result<OwnerProfile?>> getProfile();

  /// Updates the verification status of the owner.
  Future<Result<void>> updateVerificationStatus(bool isVerified);

  /// Updates the locally-stored password hash for offline login.
  Future<Result<void>> updatePasswordHash(String passwordHash);

  /// Deletes the local owner profile.
  Future<Result<void>> deleteProfile();
}
