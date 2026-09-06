import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/business.dart';
import 'package:jonkstore/providers/repository_providers.dart';

/// Provider to fetch the primary business for the current user/installation.
/// 
/// In a production scenario, this would likely be determined by the 
/// authenticated user's session.
final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final repository = ref.watch(businessRepositoryProvider);
  final result = await repository.findAll();
  
  return result.fold(
    (businesses) => businesses.isNotEmpty ? businesses.first : null,
    (failure) => null,
  );
});
