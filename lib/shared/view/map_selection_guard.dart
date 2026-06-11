class MapSelectionGuard {
  MapSelectionGuard({
    this.cooldown = const Duration(milliseconds: 400),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration cooldown;
  final DateTime Function() _now;

  int _activeModalCount = 0;
  DateTime? _blockedUntil;

  bool get acceptsSelection {
    if (_activeModalCount > 0) {
      return false;
    }
    final blockedUntil = _blockedUntil;
    return blockedUntil == null || !_now().isBefore(blockedUntil);
  }

  Future<T> runWithSelectionBlocked<T>(Future<T> Function() action) async {
    _activeModalCount++;
    try {
      return await action();
    } finally {
      _activeModalCount--;
      _blockedUntil = _now().add(cooldown);
    }
  }
}
