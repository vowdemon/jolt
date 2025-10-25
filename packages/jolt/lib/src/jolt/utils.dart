import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

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
