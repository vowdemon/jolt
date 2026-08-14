import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart' show RawNodeProvider;
import 'package:jolt/jolt.dart';

/// Converts a writable value into data supported by [StandardMessageCodec].
typedef JoltRestorationEncoder<T> = Object? Function(T value);

/// Recreates a writable value from restoration data.
typedef JoltRestorationDecoder<T> = T Function(Object? data);

/// Creates Flutter restoration properties for Jolt-backed writable values.
extension JoltWritableRestorationProperty<T> on Writable<T> {
  /// Creates a [RestorableProperty] that persists this writable's value.
  ///
  /// Keep the returned property in a stable field, register it from
  /// [RestorationMixin.restoreState], and dispose it with its owning [State].
  WritableRestorationProperty<T> toRestorationProperty({
    JoltRestorationEncoder<T>? encode,
    JoltRestorationDecoder<T>? decode,
  }) =>
      WritableRestorationProperty(this, encode: encode, decode: decode);
}

final Expando<WritableRestorationProperty<dynamic>>
    _writableRestorationProperties =
    Expando<WritableRestorationProperty<dynamic>>(
  'Jolt writable restoration properties',
);

Object _restorationTargetOf(Writable<dynamic> writable) {
  if (writable is RawNodeProvider) {
    return (writable as RawNodeProvider).raw;
  }
  throw UnsupportedError(
    'Restoration requires a Writable backed by a Jolt raw node.',
  );
}

/// A Flutter [RestorableProperty] adapter for an existing Jolt [Writable].
///
/// This object owns only the restoration subscription. It does not own or
/// replace the writable. Keep one stable instance for each raw node and
/// dispose the property before disposing its owning [State].
final class WritableRestorationProperty<T> extends RestorableProperty<T> {
  /// Creates a restoration adapter for [writable].
  ///
  /// Supply both [encode] and [decode] for values that are not directly
  /// supported by [StandardMessageCodec]. A raw node may have only one
  /// active restoration property.
  factory WritableRestorationProperty(
    Writable<T> writable, {
    JoltRestorationEncoder<T>? encode,
    JoltRestorationDecoder<T>? decode,
  }) {
    if ((encode == null) != (decode == null)) {
      throw ArgumentError(
        'encode and decode must either both be provided or both be omitted.',
      );
    }

    final target = _restorationTargetOf(writable);
    final previous = _writableRestorationProperties[target];
    if (previous != null &&
        !ServicesBinding.instance.restorationManager.isReplacing) {
      throw FlutterError.fromParts([
        ErrorSummary('Writable already has a restoration property.'),
        ErrorDescription(
          'A raw node can have only one active restoration property.',
        ),
        ErrorHint('Dispose the existing property before creating another.'),
      ]);
    }

    final property = WritableRestorationProperty<T>._(
      writable,
      target: target,
      encode: encode ?? _identityEncode,
      decode: decode ?? _identityDecode,
    );
    _writableRestorationProperties[target] = property;

    if (previous != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (previous._isDisposed) return;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts([
              ErrorSummary(
                'The previous writable restoration owner was not disposed.',
              ),
              ErrorDescription(
                'Flutter replaced restoration data, but two owners for the '
                'same raw node remained alive after the replacement frame.',
              ),
              ErrorHint(
                'Dispose the old restoration property with its owning State.',
              ),
            ]),
            library: 'jolt_flutter',
            context: ErrorDescription(
              'while validating a writable restoration owner handoff',
            ),
          ),
        );
      });
    }
    return property;
  }

  WritableRestorationProperty._(
    this._writable, {
    required Object target,
    required JoltRestorationEncoder<T> encode,
    required JoltRestorationDecoder<T> decode,
  })  : _target = target,
        _encode = encode,
        _decode = decode,
        _defaultData = _messageCodec.encodeMessage(encode(_writable.peek)) {
    _effect = Effect(
      _handleWritableChange,
      detach: true,
      debug: const JoltDebugOption.type('WritableRestorationProperty'),
    );
  }

  static const StandardMessageCodec _messageCodec = StandardMessageCodec();

  final Writable<T> _writable;
  final Object _target;
  final JoltRestorationEncoder<T> _encode;
  final JoltRestorationDecoder<T> _decode;

  final ByteData? _defaultData;
  late final Effect _effect;
  bool _isRestoring = false;
  bool _isDisposed = false;

  static Object? _identityEncode<T>(T value) => value;

  static T _identityDecode<T>(Object? data) => data as T;

  void _handleWritableChange() {
    _writable.value;
    if (identical(_writableRestorationProperties[_target], this) &&
        !_isRestoring) {
      notifyListeners();
    }
  }

  @override
  T createDefaultValue() => _decode(_messageCodec.decodeMessage(_defaultData));

  @override
  T fromPrimitives(Object? data) => _decode(data);

  @override
  void initWithValue(T value) {
    if (!identical(_writableRestorationProperties[_target], this)) return;
    _isRestoring = true;
    try {
      _writable.value = value;
    } finally {
      _isRestoring = false;
    }
  }

  @override
  Object? toPrimitives() {
    final primitives = _encode(_writable.peek);
    if (primitives == null ||
        primitives is bool ||
        primitives is num ||
        primitives is String) {
      return primitives;
    }
    // Flutter requires returned collections to remain unchanged. Round-tripping
    // also snapshots in-place ListSignal and MapSignal edits.
    return _messageCodec.decodeMessage(
      _messageCodec.encodeMessage(primitives),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (identical(_writableRestorationProperties[_target], this)) {
      _writableRestorationProperties[_target] = null;
    }
    _effect.dispose();
    super.dispose();
  }
}
