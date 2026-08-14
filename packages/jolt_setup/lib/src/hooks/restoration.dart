import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart' show RawNodeProvider;
import 'package:jolt_flutter/jolt_flutter.dart';

import '../setup/framework.dart';
import 'annotation.dart';

final Expando<SetupRestoration> _restorationSessions =
    Expando<SetupRestoration>('Jolt setup restoration sessions');

/// Called after a setup restoration scope has applied its current bucket.
typedef SetupRestorationCallback = void Function(
  RestorationBucket? oldBucket,
  bool initialRestore,
);

/// Declares a restoration namespace for state owned by this setup runtime.
///
/// This may follow unrelated hooks, but it must be called before the first
/// restoration binding. It is shared by [SetupBuilder], [SetupWidget], and
/// [SetupMixin]. Descendants continue to see the ancestor restoration scope.
@defineHook
SetupRestoration useRestorationScope(String restorationId) {
  final setupContext = SetupContext.current;
  if (setupContext == null) {
    throw StateError('useRestorationScope must be called during setup.');
  }

  final restoration = useHook(
    _RestorationScopeHook(restorationId, setupContext),
  );
  restoration._beginDeclarations(setupContext);
  return restoration;
}

final class _RestorationScopeHook extends SetupHook<SetupRestoration> {
  _RestorationScopeHook(this.restorationId, this.owner);

  final String restorationId;
  final SetupContext owner;

  @override
  SetupRestoration build() {
    if (_restorationSessions[owner] != null) {
      throw FlutterError.fromParts([
        ErrorSummary('A setup can declare only one restoration scope.'),
        ErrorDescription(
          'Reuse the SetupRestoration returned by the first '
          'useRestorationScope call.',
        ),
      ]);
    }
    final session = SetupRestoration._(restorationId);
    _restorationSessions[owner] = session;
    session._updateParent(RestorationScope.maybeOf(context));
    session._scheduleRestore(null, initialRestore: true);
    return session;
  }

  @override
  void mount() => state._endDeclarations();

  @override
  void didChangeDependencies() =>
      state._updateParent(RestorationScope.maybeOf(context));

  @override
  void unmount() {
    _restorationSessions[owner] = null;
    state._dispose();
  }

  @override
  void reassemble(covariant _RestorationScopeHook newHook) {
    if (restorationId != newHook.restorationId) {
      throw FlutterError.fromParts([
        ErrorSummary('The setup restoration scope ID changed during reload.'),
        ErrorDescription(
          'Existing ID: $restorationId; requested ID: '
          '${newHook.restorationId}.',
        ),
      ]);
    }
    state._updateParent(RestorationScope.maybeOf(context));
    state._endDeclarations();
  }
}

final class _RestorationBinding {
  _RestorationBinding(this.property, this.id, this.generation, {this.target});

  final RestorableProperty<Object?> property;
  final String id;
  final Object? target;
  int generation;
}

/// A setup-owned restoration namespace.
final class SetupRestoration {
  SetupRestoration._(this._restorationId);

  final String _restorationId;
  final Map<String, _RestorationBinding> _bindingsById = {};
  final Map<Object, _RestorationBinding> _writablesByTarget = Map.identity();
  final Map<RestorableProperty<Object?>, _RestorationBinding> _properties =
      Map.identity();
  final List<SetupRestorationCallback> _restoreCallbacks = [];

  RestorationBucket? _parent;
  RestorationBucket? _bucket;
  _SetupRestorationHostState? _host;
  SetupContext? _declarationOwner;
  ({RestorationBucket? oldBucket, bool initialRestore})? _pendingRestore;
  int _generation = 0;
  bool _hostValidationScheduled = false;
  bool _isDisposed = false;

  /// Binds [writable] to [id] in this restoration namespace.
  void bind<T>(
    Writable<T> writable, {
    required String id,
    JoltRestorationEncoder<T>? encode,
    JoltRestorationDecoder<T>? decode,
  }) {
    _ensureUsable();
    final target = _targetOf(writable);
    final existing = _writablesByTarget[target];
    if (existing != null) {
      if (existing.generation == _generation) {
        if (existing.id != id) {
          throw FlutterError.fromParts([
            ErrorSummary('Writable is already bound for restoration.'),
            ErrorDescription(
              'Existing ID: ${existing.id}; requested ID: $id.',
            ),
          ]);
        }
        return;
      }
      if (existing.id != id) {
        _removeRestorationData(existing.id);
      }
      _removeBinding(existing);
    }

    final existingId = _bindingsById[id];
    if (existingId != null) {
      if (existingId.generation == _generation) {
        throw _duplicateIdError(id);
      }
      _removeBinding(existingId);
    }

    final property = writable.toRestorationProperty(
      encode: encode,
      decode: decode,
    );
    final binding = _RestorationBinding(
      property,
      id,
      _generation,
      target: target,
    );
    _bindingsById[id] = binding;
    _writablesByTarget[target] = binding;
    _registerWritable(binding);
    property.addListener(() {
      final bucket = _bucket;
      if (bucket == null) return;
      bucket.write(id, property.toPrimitives());
      _flushRestorationData();
    });
  }

  /// Releases the active restoration binding for [writable].
  void unbind(Writable<dynamic> writable) {
    final binding = _writablesByTarget[_targetOf(writable)];
    if (binding != null) {
      _removeRestorationData(binding.id);
      _removeBinding(binding);
    }
  }

  /// Binds and takes ownership of a Flutter [RestorableProperty].
  P bindProperty<P extends RestorableProperty<Object?>>(
    P property, {
    required String id,
  }) {
    _ensureUsable();

    final existingProperty = _properties[property];
    if (existingProperty != null) {
      if (existingProperty.id != id) {
        throw FlutterError.fromParts([
          ErrorSummary('RestorableProperty is already bound.'),
          ErrorDescription(
            'Existing ID: ${existingProperty.id}; requested ID: $id.',
          ),
        ]);
      }
      existingProperty.generation = _generation;
      return property;
    }

    final existingId = _bindingsById[id];
    if (existingId != null) {
      if (existingId.generation == _generation) {
        throw _duplicateIdError(id);
      }
      if (existingId.target == null) {
        if (existingId.property.runtimeType != property.runtimeType) {
          throw FlutterError.fromParts([
            ErrorSummary('A RestorableProperty binding changed its type.'),
            ErrorDescription(
              'Restoration ID "$id" was bound to '
              '${existingId.property.runtimeType} and cannot be rebound to '
              '${property.runtimeType}.',
            ),
            ErrorHint(
              'Use a new restoration ID when the data format changes.',
            ),
          ]);
        }
        property.dispose();
        existingId.generation = _generation;
        return existingId.property as P;
      }
      _removeRestorationData(id);
      _removeBinding(existingId);
    }

    final binding = _RestorationBinding(property, id, _generation);
    _bindingsById[id] = binding;
    _properties[property] = binding;
    if (_host == null) {
      _scheduleHostValidation();
    } else {
      _host!.syncBindings();
    }
    return property;
  }

  /// Releases and disposes a bound Flutter [RestorableProperty].
  void unbindProperty(RestorableProperty<Object?> property) {
    final binding = _properties[property];
    if (binding != null) {
      _removeBinding(binding);
    }
  }

  /// Registers a callback for completed restoration passes.
  void onRestore(SetupRestorationCallback callback) {
    if (!identical(SetupContext.current, _declarationOwner)) {
      throw StateError(
        'SetupRestoration.onRestore must be called during the setup that '
        'created this restoration scope.',
      );
    }
    _restoreCallbacks.add(callback);
  }

  /// Builds [builder] after ordinary properties are registered by Flutter.
  Widget call(Widget Function() builder) => UnmanagedRestorationScope(
        bucket: _bucket,
        child: _SetupRestorationHost(this, builder),
      );

  void _beginDeclarations(SetupContext owner) {
    _declarationOwner = owner;
    _generation++;
    _restoreCallbacks.clear();
  }

  void _endDeclarations() {
    for (final binding in _bindingsById.values.toList(growable: false)) {
      if (binding.generation != _generation) {
        if (binding.target != null) {
          _removeRestorationData(binding.id);
        }
        _removeBinding(binding);
      }
    }
    _declarationOwner = null;
    if (_host == null) {
      _scheduleHostValidation();
    }
  }

  Object _targetOf(Writable<dynamic> writable) {
    if (writable is RawNodeProvider) {
      return (writable as RawNodeProvider).raw;
    }
    throw UnsupportedError(
      'Restoration requires a Writable backed by a Jolt raw node.',
    );
  }

  void _ensureUsable() {
    if (_isDisposed) {
      throw StateError('The setup restoration scope is disposed.');
    }
  }

  FlutterError _duplicateIdError(String id) {
    return FlutterError.fromParts([
      ErrorSummary('Restoration ID is already bound.'),
      ErrorDescription(
        'Writables and RestorableProperties in a setup restoration scope '
        'share one ID namespace.',
      ),
      ErrorDescription('Duplicate ID: $id.'),
    ]);
  }

  void _removeBinding(_RestorationBinding binding) {
    _bindingsById.remove(binding.id);
    if (binding.target != null) {
      _writablesByTarget.remove(binding.target);
    } else {
      _properties.remove(binding.property);
      _host?.syncBindings();
    }
    binding.property.dispose();
  }

  void _registerWritable(_RestorationBinding binding) {
    final property = binding.property;
    final bucket = _bucket;
    final hasSerializedValue = bucket?.contains(binding.id) ?? false;
    property.initWithValue(
      hasSerializedValue
          ? property.fromPrimitives(bucket!.read<Object?>(binding.id))
          : property.createDefaultValue(),
    );
    if (!hasSerializedValue && bucket != null) {
      bucket.write(binding.id, property.toPrimitives());
      _flushRestorationData();
    }
  }

  void _removeRestorationData(String id) {
    final bucket = _bucket;
    if (bucket == null) return;
    bucket.remove<Object?>(id);
    _flushRestorationData();
  }

  void _flushRestorationData() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      ServicesBinding.instance.restorationManager.flushData();
    } else if (phase == SchedulerPhase.postFrameCallbacks) {
      scheduleMicrotask(
        ServicesBinding.instance.restorationManager.flushData,
      );
    }
  }

  void _attachHost(_SetupRestorationHostState host) {
    if (_host != null) {
      throw FlutterError.fromParts([
        ErrorSummary('A restoration scope has multiple widget hosts.'),
        ErrorDescription(
          'Build a SetupRestoration only once in its setup widget tree.',
        ),
      ]);
    }
    _host = host;
  }

  void _detachHost(_SetupRestorationHostState host) {
    if (identical(_host, host)) {
      _host = null;
      _scheduleHostValidation();
    }
  }

  void _scheduleHostValidation() {
    if (_declarationOwner != null ||
        _properties.isEmpty ||
        _hostValidationScheduled) {
      return;
    }
    _hostValidationScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _hostValidationScheduled = false;
        if (_isDisposed || _host != null || _properties.isEmpty) {
          return;
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts([
              ErrorSummary('A RestorableProperty has no restoration host.'),
              ErrorDescription(
                'SetupRestoration.bindProperty requires the returned widget '
                'to be built through restoration(() => ...).',
              ),
            ]),
            library: 'jolt_setup',
            context: ErrorDescription(
              'while validating a setup restoration property binding',
            ),
          ),
        );
      })
      ..ensureVisualUpdate();
  }

  void _updateParent(RestorationBucket? parent) {
    if (identical(_parent, parent)) return;

    final oldBucket = _bucket;
    _parent = parent;
    if (parent == null) {
      _bucket = null;
      oldBucket?.dispose();
      return;
    }

    if (oldBucket != null && !parent.isReplacing) {
      oldBucket.rename(_restorationId);
      parent.adoptChild(oldBucket);
      _bucket = oldBucket;
      return;
    }

    _bucket = parent.claimChild(_restorationId, debugOwner: this);
    if (parent.isReplacing) {
      batch(() {
        for (final binding in _writablesByTarget.values) {
          _registerWritable(binding);
        }
      });
      _scheduleRestore(oldBucket, initialRestore: false);
      return;
    }

    final bucket = _bucket!;
    for (final binding in _writablesByTarget.values) {
      bucket.write(binding.id, binding.property.toPrimitives());
    }
  }

  void _scheduleRestore(
    RestorationBucket? oldBucket, {
    required bool initialRestore,
  }) {
    final previous = _pendingRestore;
    if (previous != null &&
        !identical(previous.oldBucket, oldBucket) &&
        !identical(previous.oldBucket, _bucket)) {
      previous.oldBucket?.dispose();
    }

    _pendingRestore = (
      oldBucket: oldBucket,
      initialRestore: initialRestore,
    );
    if (previous != null) return;
    scheduleMicrotask(() {
      final restore = _pendingRestore;
      if (restore == null) return;
      _pendingRestore = null;
      try {
        for (final callback in _restoreCallbacks) {
          callback(restore.oldBucket, restore.initialRestore);
        }
      } finally {
        restore.oldBucket?.dispose();
      }
    });
  }

  void _dispose() {
    _isDisposed = true;
    final pendingRestore = _pendingRestore;
    _pendingRestore = null;
    if (!identical(pendingRestore?.oldBucket, _bucket)) {
      pendingRestore?.oldBucket?.dispose();
    }
    _restoreCallbacks.clear();
    _host = null;
    for (final binding in _bindingsById.values) {
      binding.property.dispose();
    }
    _bindingsById.clear();
    _writablesByTarget.clear();
    _properties.clear();
    _bucket?.dispose();
    _bucket = null;
    _parent = null;
  }
}

final class _SetupRestorationHost extends StatefulWidget {
  _SetupRestorationHost(this.session, this.builder)
      : super(key: ObjectKey(session));

  final SetupRestoration session;
  final Widget Function() builder;

  @override
  State<_SetupRestorationHost> createState() => _SetupRestorationHostState();
}

final class _SetupRestorationHostState extends State<_SetupRestorationHost>
    with RestorationMixin<_SetupRestorationHost> {
  static const _propertiesRestorationId = 'jolt_setup.properties';

  final Set<RestorableProperty<Object?>> _registeredProperties = Set.identity();

  @override
  String get restorationId => _propertiesRestorationId;

  @override
  void initState() {
    super.initState();
    widget.session._attachHost(this);
  }

  void _handlePropertyChanged() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  void _syncProperties({required bool restore}) {
    for (final property in _registeredProperties.toList(growable: false)) {
      if (!widget.session._properties.containsKey(property)) {
        unregisterFromRestoration(property);
        property.removeListener(_handlePropertyChanged);
        _registeredProperties.remove(property);
      }
    }

    for (final binding in widget.session._properties.values) {
      final isRegistered = _registeredProperties.contains(binding.property);
      if (restore || !isRegistered) {
        registerForRestoration(binding.property, binding.id);
      }
      if (!isRegistered) {
        binding.property.addListener(_handlePropertyChanged);
        _registeredProperties.add(binding.property);
      }
    }
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) =>
      _syncProperties(restore: true);

  void syncBindings() {
    if (restorePending && _registeredProperties.isEmpty) return;
    _syncProperties(restore: false);
    _handlePropertyChanged();
  }

  @override
  Widget build(BuildContext context) => UnmanagedRestorationScope(
        bucket: widget.session._parent,
        child: JoltBuilder(builder: (_) => widget.builder()),
      );

  @override
  void dispose() {
    widget.session._detachHost(this);
    for (final property in _registeredProperties) {
      property.removeListener(_handlePropertyChanged);
    }
    _registeredProperties.clear();
    super.dispose();
  }
}
