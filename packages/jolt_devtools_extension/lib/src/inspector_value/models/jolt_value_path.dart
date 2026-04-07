import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';

enum JoltPathSegmentKind {
  field,
  listIndex,
  mapKey,
  mapValue,
  range,
}

enum JoltMapEntryIdentityKind {
  primitive,
  object,
}

class JoltMapEntryIdentity {
  const JoltMapEntryIdentity.primitive(this.primitiveKey)
      : kind = JoltMapEntryIdentityKind.primitive,
        objectId = null,
        fallbackLabel = null;

  const JoltMapEntryIdentity.object({
    required this.objectId,
    required this.fallbackLabel,
  })  : kind = JoltMapEntryIdentityKind.object,
        primitiveKey = null;

  final JoltMapEntryIdentityKind kind;
  final String? primitiveKey;
  final String? objectId;
  final String? fallbackLabel;

  @override
  bool operator ==(Object other) {
    return other is JoltMapEntryIdentity &&
        other.kind == kind &&
        other.primitiveKey == primitiveKey &&
        other.objectId == objectId &&
        other.fallbackLabel == fallbackLabel;
  }

  @override
  int get hashCode => Object.hash(kind, primitiveKey, objectId, fallbackLabel);
}

class JoltPathSegment {
  const JoltPathSegment.field({
    required this.name,
    required this.ownerName,
    required this.ownerUri,
  })  : kind = JoltPathSegmentKind.field,
        index = null,
        identity = null,
        start = null,
        end = null;

  const JoltPathSegment.index(this.index)
      : kind = JoltPathSegmentKind.listIndex,
        name = null,
        ownerName = null,
        ownerUri = null,
        identity = null,
        start = null,
        end = null;

  const JoltPathSegment.mapKey({
    required this.identity,
  })  : kind = JoltPathSegmentKind.mapKey,
        index = null,
        name = null,
        ownerName = null,
        ownerUri = null,
        start = null,
        end = null;

  const JoltPathSegment.mapValue({
    required this.identity,
  })  : kind = JoltPathSegmentKind.mapValue,
        index = null,
        name = null,
        ownerName = null,
        ownerUri = null,
        start = null,
        end = null;

  const JoltPathSegment.range({
    required this.start,
    required this.end,
  })  : kind = JoltPathSegmentKind.range,
        index = null,
        name = null,
        ownerName = null,
        ownerUri = null,
        identity = null;

  final JoltPathSegmentKind kind;
  final String? name;
  final String? ownerName;
  final String? ownerUri;
  final int? index;
  final JoltMapEntryIdentity? identity;
  final int? start;
  final int? end;

  @override
  bool operator ==(Object other) {
    return other is JoltPathSegment &&
        other.kind == kind &&
        other.name == name &&
        other.ownerName == ownerName &&
        other.ownerUri == ownerUri &&
        other.index == index &&
        other.identity == identity &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        name,
        ownerName,
        ownerUri,
        index,
        identity,
        start,
        end,
      );
}

class JoltValuePath {
  const JoltValuePath({
    required this.nodeId,
    this.segments = const <JoltPathSegment>[],
  });

  const JoltValuePath.root({
    required this.nodeId,
  }) : segments = const <JoltPathSegment>[];

  final int nodeId;
  final List<JoltPathSegment> segments;

  JoltValuePath childField(JoltObjectField field) {
    return JoltValuePath(
      nodeId: nodeId,
      segments: [
        ...segments,
        JoltPathSegment.field(
          name: field.name,
          ownerName: field.ownerName,
          ownerUri: field.ownerUri,
        ),
      ],
    );
  }

  JoltValuePath childIndex(int index) {
    return JoltValuePath(
      nodeId: nodeId,
      segments: [...segments, JoltPathSegment.index(index)],
    );
  }

  JoltValuePath childMapKey(JoltMapEntryIdentity identity) {
    return JoltValuePath(
      nodeId: nodeId,
      segments: [...segments, JoltPathSegment.mapKey(identity: identity)],
    );
  }

  JoltValuePath childMapValue(JoltMapEntryIdentity identity) {
    return JoltValuePath(
      nodeId: nodeId,
      segments: [...segments, JoltPathSegment.mapValue(identity: identity)],
    );
  }

  JoltValuePath childRange(int start, int end) {
    return JoltValuePath(
      nodeId: nodeId,
      segments: [...segments, JoltPathSegment.range(start: start, end: end)],
    );
  }

  JoltValuePath get parent {
    if (segments.isEmpty) {
      return this;
    }
    return JoltValuePath(
      nodeId: nodeId,
      segments: segments.sublist(0, segments.length - 1),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! JoltValuePath) {
      return false;
    }
    if (other.nodeId != nodeId || other.segments.length != segments.length) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != other.segments[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(nodeId, Object.hashAll(segments));
}
