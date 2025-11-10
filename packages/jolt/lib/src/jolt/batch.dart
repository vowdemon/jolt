import 'dart:async';

import '../core/reactive.dart';

/// Batches multiple reactive updates into a single notification cycle.
///
/// When multiple signals are updated within a batch, their subscribers
/// will only be notified once at the end of the batch, rather than after
/// each individual update. This improves performance and prevents
/// intermediate inconsistent states.
///
/// Parameters:
/// - [fn]: Function containing the updates to batch
///
/// Example:
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// Effect(() => print(fullName.value)); // Prints once per batch
///
/// batch(() {
///   firstName.value = 'Jane';  // No immediate notification
///   lastName.value = 'Smith';  // No immediate notification
/// }); // Notification happens here: "Jane Smith"
/// ```
FutureOr<T> batch<T>(T Function() fn) async {
  startBatch();
  try {
    return fn();
  } finally {
    endBatch();
  }
}
