import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to monitor internet connectivity status.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity status changes.
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _connectivity.onConnectivityChanged;

  /// Checks the current connectivity status.
  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}

/// Provider for the ConnectivityService.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider for the current connectivity status.
final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return ref.watch(connectivityServiceProvider).onConnectivityChanged;
});

/// Provider for a simple boolean connection status.
final isConnectedProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).value ?? [ConnectivityResult.wifi];
  return !status.contains(ConnectivityResult.none);
});
