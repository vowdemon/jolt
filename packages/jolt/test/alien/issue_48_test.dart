import 'package:test/test.dart';

import 'common.dart';

class ReactionOptions<T> {
  final bool? fireImmediately;
  final bool Function(T?, T?)? equals;
  final void Function(Object error)? onError;
  final void Function(void Function() fn)? scheduler;
  final bool? once;

  const ReactionOptions({
    this.fireImmediately,
    this.equals,
    this.onError,
    this.scheduler,
    this.once,
  });
}

const defaultOptions = ReactionOptions();

T untracked<T>(T Function() callback) {
  final currentSub = setCurrentSub(null);
  try {
    return callback();
  } finally {
    setCurrentSub(currentSub);
  }
}

void Function() reaction<T>({
  required T Function() dataFn,
  required void Function(T?, T?) effectFn,
  ReactionOptions<T>? options,
}) {
  final scheduler = options?.scheduler ?? (fn) => fn();
  final equals = options?.equals ?? (a, b) => a == b;
  final onError = options?.onError;
  final once = options?.once ?? false;
  final fireImmediately = options?.fireImmediately ?? false;

  T? prevValue;
  int version = 0;

  final tracked = computed<T?>(() {
    try {
      return dataFn();
    } catch (error) {
      untracked(() => onError?.call(error));
      return prevValue;
    }
  });

  void Function()? dispose;
  dispose = effect(() {
    final current = tracked();
    if (!fireImmediately && version == 0) {
      prevValue = current;
    }
    version++;
    if (equals(current, prevValue as T)) return;
    final oldValue = prevValue;
    prevValue = current;
    untracked(
      () => scheduler(() {
        try {
          effectFn(current, oldValue);
        } catch (error) {
          onError?.call(error);
        } finally {
          if (once) {
            if (fireImmediately && version > 1) {
              dispose?.call();
            } else if (!fireImmediately && version > 0) {
              dispose?.call();
            }
          }
        }
      }),
    );
  });

  return dispose;
}

void main() {
  group('issue48', () {
    test('#48', () {
      final source = signal(0);
      void Function()? disposeInner;

      reaction(
        dataFn: () => source(),
        effectFn: (val, _) {
          if (val == 1) {
            disposeInner = reaction(
              dataFn: () => source(),
              effectFn: (_, __) {},
            );
          } else if (val == 2) {
            disposeInner?.call();
          }
        },
      );

      source(1, true);
      source(2, true);
      source(3, true);
    });
  });
}
