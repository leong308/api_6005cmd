import 'dart:async';

import 'package:api_6005cmd/shared/view/map_selection_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks map selection during modal and cooldown', () async {
    var now = DateTime(2026, 6, 11, 12);
    final guard = MapSelectionGuard(
      cooldown: const Duration(milliseconds: 400),
      now: () => now,
    );
    final modalCompleter = Completer<void>();

    expect(guard.acceptsSelection, isTrue);

    final modalFuture = guard.runWithSelectionBlocked(
      () => modalCompleter.future,
    );
    expect(guard.acceptsSelection, isFalse);

    modalCompleter.complete();
    await modalFuture;
    expect(guard.acceptsSelection, isFalse);

    now = now.add(const Duration(milliseconds: 399));
    expect(guard.acceptsSelection, isFalse);

    now = now.add(const Duration(milliseconds: 1));
    expect(guard.acceptsSelection, isTrue);
  });
}
