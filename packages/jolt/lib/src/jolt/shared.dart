import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'base.dart';
import 'effect.dart';

@internal
final joltFinalizer = Finalizer<Set<Disposer>>((disposers) {
  for (final disposer in disposers) {
    disposer();
  }
});

@internal
final joltAttachments = Expando<Set<Disposer>>();

@internal
Disposer attachToJoltAttachments(Object target, Disposer disposer) {
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

@internal
void detachFromJoltAttachments(Object target, Disposer disposer) {
  final disposers = joltAttachments[target];
  if (disposers != null) {
    disposers.remove(disposer);
  }
}

@internal
void manuallyDisposeJoltAttachments(Object target) {
  final disposers = joltAttachments[target];
  if (disposers != null) {
    for (final disposer in disposers) {
      disposer();
    }
    joltFinalizer.detach(disposers);
    disposers.clear();
    joltAttachments[target] = null;
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
