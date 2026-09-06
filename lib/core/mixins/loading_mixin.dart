import 'package:flutter/foundation.dart';

/// A mixin to add loading state management to any class (usually controllers or ViewModels).
mixin LoadingMixin on ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
