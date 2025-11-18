import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  
  bool _isOnline = true;
  bool _hasCheckedInitial = false;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    _hasCheckedInitial = true;

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    // User is online if ANY connection type is available (not none)
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    // Only notify if status changed and we've done initial check
    if (_hasCheckedInitial && wasOnline != _isOnline) {
      if (kDebugMode) {
        print('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
