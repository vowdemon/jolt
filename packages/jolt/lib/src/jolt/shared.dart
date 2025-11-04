import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'base.dart';
import 'effect.dart';

abstract final class JFinalizer {
  static final joltFinalizer = Finalizer<Set<Disposer>>((disposers) {
    for (final disposer in disposers) {
      disposer();
    }
  });

  static final joltAttachments = Expando<Set<Disposer>>();

  static Disposer attachToJoltAttachments(Object target, Disposer disposer) {
    assert(
        (target is JReadonlyValue || target is JEffect)
            ? !((target as dynamic).isDisposed)
            : true,
        'Jolt value is disposed');

    Set<Disposer>? disposers = joltAttachments[target];
    if (disposers == null) {
      joltAttachments[target] = disposers = {};
      joltFinalizer.attach(target, disposers);
    }

    disposers.add(disposer);
    return () {
      disposers!.remove(disposer);
    };
  }

  static void detachFromJoltAttachments(Object target, Disposer disposer) {
    final disposers = joltAttachments[target];
    if (disposers != null) {
      disposers.remove(disposer);
    }
  }

  @visibleForTesting
  static Set<Disposer> getJoltAttachments(Object target) {
    return joltAttachments[target] ?? {};
  }

  static void disposeObject(Object target) {
    final originalDisposers = joltAttachments[target];
    if (originalDisposers == null) return;
    joltAttachments[target] = null;

    final disposers = {...originalDisposers};

    for (final disposer in disposers) {
      disposer();
    }
    joltFinalizer.detach(originalDisposers);
    disposers.clear();
  }
}

final streamHolders = Expando<StreamHolder<Object?>>();

@internal
class StreamHolder<T> implements Disposable {
  StreamHolder({
    void Function()? onListen,
    void Function()? onCancel,
  }) : sc = StreamController<T>.broadcast(
          onListen: onListen,
          onCancel: onCancel,
        );
  final StreamController<T> sc;
  Watcher? watcher;

  Stream<T> get stream => sc.stream;
  StreamSink<T> get sink => sc.sink;

  void setWatcher(Watcher watcher) {
    this.watcher = watcher;
  }

  void clearWatcher() {
    watcher?.dispose();
    watcher = null;
  }

  @override
  void dispose() {
    clearWatcher();
    sc.close();
  }
}

@internal
@visibleForTesting
StreamHolder<T>? getStreamHolder<T>(JReadonlyValue<T> value) {
  return streamHolders[value] as StreamHolder<T>?;
}
