import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  JoltDebug.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jolt Value Samples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490)),
        useMaterial3: true,
      ),
      home: const SampleDashboardPage(),
    );
  }
}

class SampleDashboardPage extends StatefulWidget {
  const SampleDashboardPage({super.key});

  @override
  State<SampleDashboardPage> createState() => _SampleDashboardPageState();
}

class _SampleDashboardPageState extends State<SampleDashboardPage> {
  final tapCount = Signal(0, debug: _debug('signal.intCounter', 'Primitive'));
  final nullableValue = Signal<Object?>(
    null,
    debug: _debug('signal.nullable', 'Primitive'),
  );
  final enabled = Signal(true, debug: _debug('signal.boolFlag', 'Primitive'));
  final temperature = Signal(
    21.5,
    debug: _debug('signal.doubleTemperature', 'Primitive'),
  );
  final numericValue = Signal<num>(
    64.25,
    debug: _debug('signal.numericValue', 'Primitive'),
  );
  final message = Signal(
    'hello jolt',
    debug: _debug('signal.message', 'Primitive'),
  );
  final bigIntValue = Signal(
    BigInt.parse('9007199254740993'),
    debug: _debug('signal.bigIntValue', 'CoreObject'),
  );
  final dateTimeValue = Signal(
    DateTime.utc(2026, 4, 7, 12, 34, 56),
    debug: _debug('signal.dateTimeValue', 'CoreObject'),
  );
  final durationValue = Signal(
    const Duration(hours: 1, minutes: 23, seconds: 45),
    debug: _debug('signal.durationValue', 'CoreObject'),
  );
  final uriValue = Signal(
    Uri.parse('https://jolt.dev/inspector/sample?tab=signal&selected=counter'),
    debug: _debug('signal.uriValue', 'CoreObject'),
  );
  final regExpValue = Signal(
    RegExp(r'jolt-(signal|computed)-\d+'),
    debug: _debug('signal.regExpValue', 'CoreObject'),
  );
  final status = Signal(
    SampleStatus.idle,
    debug: _debug('signal.status', 'Enum'),
  );
  final numbers = ListSignal<int>([
    1,
    2,
    3,
  ], debug: _debug('signal.numbers', 'Collection'));
  final largeListSignal = Signal<List<int>>(
    List<int>.generate(1000, (index) => index),
    debug: _debug('signal.largeList1000', 'Collection'),
  );
  final metadata = MapSignal<String, Object?>({
    'counter': 0,
    'active': true,
    'note': 'seed',
  }, debug: _debug('signal.metadata', 'Collection'));
  final tags = SetSignal<String>({
    'dart',
    'flutter',
  }, debug: _debug('signal.tags', 'Collection'));
  final typedBytes = Signal(
    Uint8List.fromList([1, 2, 3, 4, 5]),
    debug: _debug('signal.typedBytes', 'TypedData'),
  );
  final recordValue = Signal<(int, String, bool)>((
    1,
    'alpha',
    true,
  ), debug: _debug('signal.recordValue', 'Record'));
  final profile = Signal(
    const SampleProfile(
      name: 'Nova',
      age: 28,
      role: 'engineer',
      address: SampleAddress(city: 'Shanghai', zipCode: 200000),
      skills: ['dart', 'flutter'],
    ),
    debug: _debug('signal.profile', 'Object'),
  );
  final payload = Signal(
    const SamplePayload(
      id: 'payload-001',
      profile: SampleProfile(
        name: 'Nova',
        age: 28,
        role: 'engineer',
        address: SampleAddress(city: 'Shanghai', zipCode: 200000),
        skills: ['dart', 'flutter'],
      ),
      timeline: ['created', 'queued'],
      metrics: {'cpu': 0.31, 'memory': 128},
    ),
    debug: _debug('signal.payload', 'NestedObject'),
  );

  late final Computed<Object?> computedNullable = Computed<Object?>(
    () => enabled.value ? nullableValue.value : 'not-null-because-disabled',
    debug: _debug('computed.nullableView', 'PrimitiveComputed'),
  );
  late final Computed<bool> computedHot = Computed<bool>(
    () => temperature.value >= 25,
    debug: _debug('computed.isHot', 'PrimitiveComputed'),
  );
  late final Computed<double> computedProgress = Computed<double>(
    () => tapCount.value * 1.5 + temperature.value,
    debug: _debug('computed.progressScore', 'PrimitiveComputed'),
  );
  late final Computed<num> computedNumericBlend = Computed<num>(
    () => numericValue.value + tapCount.value + temperature.value,
    debug: _debug('computed.numericBlend', 'PrimitiveComputed'),
  );
  late final Computed<String> computedSummaryText = Computed<String>(
    () =>
        'Tap count: ${tapCount.value} • ${status.value.name} • ${message.value}',
    debug: _debug('computed.summaryText', 'PrimitiveComputed'),
  );
  late final Computed<BigInt> computedBigIntProjection = Computed<BigInt>(
    () => bigIntValue.value + BigInt.from(tapCount.value),
    debug: _debug('computed.bigIntProjection', 'CoreObjectComputed'),
  );
  late final Computed<DateTime> computedDateTimeProjection = Computed<DateTime>(
    () => dateTimeValue.value.add(durationValue.value),
    debug: _debug('computed.dateTimeProjection', 'CoreObjectComputed'),
  );
  late final Computed<Duration> computedDurationProjection = Computed<Duration>(
    () => durationValue.value + Duration(seconds: tapCount.value),
    debug: _debug('computed.durationProjection', 'CoreObjectComputed'),
  );
  late final Computed<Uri> computedUriProjection = Computed<Uri>(
    () => uriValue.value.replace(
      queryParameters: {
        ...uriValue.value.queryParameters,
        'count': '${tapCount.value}',
        'status': status.value.name,
      },
    ),
    debug: _debug('computed.uriProjection', 'CoreObjectComputed'),
  );
  late final Computed<RegExp> computedRegExpProjection = Computed<RegExp>(
    () => RegExp('${regExpValue.value.pattern}|${status.value.name}'),
    debug: _debug('computed.regExpProjection', 'CoreObjectComputed'),
  );
  late final Computed<SampleStatus> computedStatusMirror =
      Computed<SampleStatus>(
        () => tags.contains('reactive') ? SampleStatus.success : status.value,
        debug: _debug('computed.statusMirror', 'EnumComputed'),
      );
  late final Computed<List<String>> computedListPreview =
      Computed<List<String>>(
        () => [
          'count:${tapCount.value}',
          'numbers:${numbers.join(',')}',
          'tags:${tags.join('|')}',
        ],
        debug: _debug('computed.listPreview', 'CollectionComputed'),
      );
  late final Computed<Map<String, Object?>> computedMapSummary =
      Computed<Map<String, Object?>>(
        () => {
          'enabled': enabled.value,
          'status': status.value.name,
          'latest': numbers.isEmpty ? null : numbers.last,
          'skills': profile.value.skills.length,
        },
        debug: _debug('computed.mapSummary', 'CollectionComputed'),
      );
  late final Computed<Set<String>> computedSetSummary = Computed<Set<String>>(
    () => {...tags, status.value.name, if (enabled.value) 'enabled'},
    debug: _debug('computed.setSummary', 'CollectionComputed'),
  );
  late final Computed<Uint8List> computedTypedBytes = Computed<Uint8List>(
    () => Uint8List.fromList(typedBytes.value.reversed.toList()),
    debug: _debug('computed.typedBytesMirror', 'TypedDataComputed'),
  );
  late final Computed<(String, int, bool)> computedRecordSnapshot =
      Computed<(String, int, bool)>(
        () => (status.value.name, tapCount.value, enabled.value),
        debug: _debug('computed.recordSnapshot', 'RecordComputed'),
      );
  late final Computed<SampleProfile> computedProfileCard =
      Computed<SampleProfile>(
        () => profile.value.copyWith(
          role: '${profile.value.role}/${status.value.name}',
          age: profile.value.age + tapCount.value,
        ),
        debug: _debug('computed.profileCard', 'ObjectComputed'),
      );
  late final Computed<SamplePayload> computedPayloadOverview =
      Computed<SamplePayload>(
        () => payload.value.copyWith(
          timeline: [...payload.value.timeline, 'tick-${tapCount.value}'],
          metrics: {
            ...payload.value.metrics,
            'progress': computedProgress.value,
          },
        ),
        debug: _debug('computed.payloadOverview', 'NestedObjectComputed'),
      );

  @override
  void dispose() {
    computedNullable.dispose();
    computedHot.dispose();
    computedProgress.dispose();
    computedNumericBlend.dispose();
    computedSummaryText.dispose();
    computedBigIntProjection.dispose();
    computedDateTimeProjection.dispose();
    computedDurationProjection.dispose();
    computedUriProjection.dispose();
    computedRegExpProjection.dispose();
    computedStatusMirror.dispose();
    computedListPreview.dispose();
    computedMapSummary.dispose();
    computedSetSummary.dispose();
    computedTypedBytes.dispose();
    computedRecordSnapshot.dispose();
    computedProfileCard.dispose();
    computedPayloadOverview.dispose();
    tapCount.dispose();
    nullableValue.dispose();
    enabled.dispose();
    temperature.dispose();
    numericValue.dispose();
    message.dispose();
    bigIntValue.dispose();
    dateTimeValue.dispose();
    durationValue.dispose();
    uriValue.dispose();
    regExpValue.dispose();
    status.dispose();
    numbers.dispose();
    largeListSignal.dispose();
    metadata.dispose();
    tags.dispose();
    typedBytes.dispose();
    recordValue.dispose();
    profile.dispose();
    payload.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    tapCount.value++;
    numericValue.value = numericValue.value + 0.75;
    metadata['counter'] = tapCount.value;
  }

  void _toggleBoolean() {
    enabled.value = !enabled.value;
  }

  void _cycleEnum() {
    final values = SampleStatus.values;
    final nextIndex = (status.value.index + 1) % values.length;
    status.value = values[nextIndex];
  }

  void _advanceCoreObjects() {
    bigIntValue.value =
        bigIntValue.value + BigInt.parse('111111111111111111');
    dateTimeValue.value = dateTimeValue.value.add(
      const Duration(days: 1, minutes: 5),
    );
    durationValue.value = durationValue.value + const Duration(seconds: 30);
    uriValue.value = uriValue.value.replace(
      pathSegments: [
        ...uriValue.value.pathSegments.where((segment) => segment.isNotEmpty),
        'tick-${tapCount.value}',
      ],
      queryParameters: {
        ...uriValue.value.queryParameters,
        'selected': 'counter-${tapCount.value}',
      },
    );
    regExpValue.value = RegExp(
      '${regExpValue.value.pattern}|tick-${tapCount.value}',
    );
  }

  void _appendListItem() {
    numbers.add(tapCount.value + numbers.length + 1);
  }

  void _rotateMapValue() {
    metadata['note'] = 'tick-${tapCount.value}';
    metadata['active'] = enabled.value;
    metadata['counter'] = tapCount.value;
  }

  void _toggleSetTag() {
    if (tags.contains('reactive')) {
      tags.remove('reactive');
    } else {
      tags.add('reactive');
    }
  }

  void _advanceRecord() {
    final current = recordValue.value;
    recordValue.value = (
      current.$1 + 1,
      'phase-${current.$1 + 1}',
      !current.$3,
    );
  }

  void _flipNullability() {
    nullableValue.value = nullableValue.value == null
        ? 'now-not-null-${tapCount.value}'
        : null;
  }

  void _shuffleBytes() {
    typedBytes.value = Uint8List.fromList(
      typedBytes.value.map((byte) => (byte + 7) % 255).toList(),
    );
  }

  void _mutateProfile() {
    final current = profile.value;
    profile.value = current.copyWith(
      age: current.age + 1,
      role: current.role == 'engineer' ? 'architect' : 'engineer',
      skills: [...current.skills, 'tick-${tapCount.value}'],
    );
  }

  void _mutatePayload() {
    final current = payload.value;
    payload.value = current.copyWith(
      id: 'payload-${tapCount.value.toString().padLeft(3, '0')}',
      timeline: [...current.timeline, 'updated-${current.timeline.length}'],
      metrics: {
        ...current.metrics,
        'cpu': ((current.metrics['cpu'] as double?) ?? 0) + 0.13,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jolt Value Samples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroHeader(summaryText: computedSummaryText),
          const SizedBox(height: 16),
          _ActionPanel(
            onIncrement: _incrementCounter,
            onToggleBoolean: _toggleBoolean,
            onCycleEnum: _cycleEnum,
            onAdvanceCoreObjects: _advanceCoreObjects,
            onAppendList: _appendListItem,
            onRotateMap: _rotateMapValue,
            onToggleSet: _toggleSetTag,
            onAdvanceRecord: _advanceRecord,
            onFlipNullability: _flipNullability,
            onShuffleBytes: _shuffleBytes,
            onMutateProfile: _mutateProfile,
            onMutatePayload: _mutatePayload,
          ),
          const SizedBox(height: 16),
          _SampleSection(
            title: 'Signal Samples',
            subtitle:
                'Built-in primitives, core objects, collections, typed data, enum, record, object, and nested object.',
            children: [
              _SampleTile(
                label: 'signal.nullable',
                child: _ValueText(() => nullableValue.value),
              ),
              _SampleTile(
                label: 'signal.boolFlag',
                child: _ValueText(() => enabled.value),
              ),
              _SampleTile(
                label: 'signal.intCounter',
                child: _ValueText(() => tapCount.value),
              ),
              _SampleTile(
                label: 'signal.doubleTemperature',
                child: _ValueText(() => temperature.value),
              ),
              _SampleTile(
                label: 'signal.numericValue',
                child: _ValueText(() => numericValue.value),
              ),
              _SampleTile(
                label: 'signal.message',
                child: _ValueText(() => message.value),
              ),
              _SampleTile(
                label: 'signal.bigIntValue',
                child: _ValueText(() => bigIntValue.value),
              ),
              _SampleTile(
                label: 'signal.dateTimeValue',
                child: _ValueText(() => dateTimeValue.value),
              ),
              _SampleTile(
                label: 'signal.durationValue',
                child: _ValueText(() => durationValue.value),
              ),
              _SampleTile(
                label: 'signal.uriValue',
                child: _ValueText(() => uriValue.value),
              ),
              _SampleTile(
                label: 'signal.regExpValue',
                child: _ValueText(() => regExpValue.value),
              ),
              _SampleTile(
                label: 'signal.status',
                child: _ValueText(() => status.value),
              ),
              _SampleTile(
                label: 'signal.numbers',
                child: _ValueText(() => numbers.toList()),
              ),
              _SampleTile(
                label: 'signal.largeList1000',
                child: _ValueText(
                  () => 'length=${largeListSignal.value.length}, '
                      'first=${largeListSignal.value.first}, '
                      'last=${largeListSignal.value.last}',
                ),
              ),
              _SampleTile(
                label: 'signal.metadata',
                child: _ValueText(() => Map<String, Object?>.from(metadata)),
              ),
              _SampleTile(
                label: 'signal.tags',
                child: _ValueText(() => tags.toSet()),
              ),
              _SampleTile(
                label: 'signal.typedBytes',
                child: _ValueText(() => typedBytes.value),
              ),
              _SampleTile(
                label: 'signal.recordValue',
                child: _ValueText(() => recordValue.value),
              ),
              _SampleTile(
                label: 'signal.profile',
                child: _ValueText(() => profile.value),
              ),
              _SampleTile(
                label: 'signal.payload',
                child: _ValueText(() => payload.value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SampleSection(
            title: 'Computed Samples',
            subtitle:
                'Derived values that mirror primitive, core object, collection, record, enum, and object shapes.',
            children: [
              _SampleTile(
                label: 'computed.nullableView',
                child: _ValueText(() => computedNullable.value),
              ),
              _SampleTile(
                label: 'computed.isHot',
                child: _ValueText(() => computedHot.value),
              ),
              _SampleTile(
                label: 'computed.progressScore',
                child: _ValueText(() => computedProgress.value),
              ),
              _SampleTile(
                label: 'computed.numericBlend',
                child: _ValueText(() => computedNumericBlend.value),
              ),
              _SampleTile(
                label: 'computed.summaryText',
                child: _ValueText(() => computedSummaryText.value),
              ),
              _SampleTile(
                label: 'computed.bigIntProjection',
                child: _ValueText(() => computedBigIntProjection.value),
              ),
              _SampleTile(
                label: 'computed.dateTimeProjection',
                child: _ValueText(() => computedDateTimeProjection.value),
              ),
              _SampleTile(
                label: 'computed.durationProjection',
                child: _ValueText(() => computedDurationProjection.value),
              ),
              _SampleTile(
                label: 'computed.uriProjection',
                child: _ValueText(() => computedUriProjection.value),
              ),
              _SampleTile(
                label: 'computed.regExpProjection',
                child: _ValueText(() => computedRegExpProjection.value),
              ),
              _SampleTile(
                label: 'computed.statusMirror',
                child: _ValueText(() => computedStatusMirror.value),
              ),
              _SampleTile(
                label: 'computed.listPreview',
                child: _ValueText(() => computedListPreview.value),
              ),
              _SampleTile(
                label: 'computed.mapSummary',
                child: _ValueText(() => computedMapSummary.value),
              ),
              _SampleTile(
                label: 'computed.setSummary',
                child: _ValueText(() => computedSetSummary.value),
              ),
              _SampleTile(
                label: 'computed.typedBytesMirror',
                child: _ValueText(() => computedTypedBytes.value),
              ),
              _SampleTile(
                label: 'computed.recordSnapshot',
                child: _ValueText(() => computedRecordSnapshot.value),
              ),
              _SampleTile(
                label: 'computed.profileCard',
                child: _ValueText(() => computedProfileCard.value),
              ),
              _SampleTile(
                label: 'computed.payloadOverview',
                child: _ValueText(() => computedPayloadOverview.value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.summaryText});

  final Computed<String> summaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF164E63), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jolt Built-in Type Gallery',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Signal and Computed examples for primitives, core objects, collections, records, enums, typed data, and nested objects.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 12),
          JoltBuilder(
            builder: (context) => Text(
              summaryText.value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.onIncrement,
    required this.onToggleBoolean,
    required this.onCycleEnum,
    required this.onAdvanceCoreObjects,
    required this.onAppendList,
    required this.onRotateMap,
    required this.onToggleSet,
    required this.onAdvanceRecord,
    required this.onFlipNullability,
    required this.onShuffleBytes,
    required this.onMutateProfile,
    required this.onMutatePayload,
  });

  final VoidCallback onIncrement;
  final VoidCallback onToggleBoolean;
  final VoidCallback onCycleEnum;
  final VoidCallback onAdvanceCoreObjects;
  final VoidCallback onAppendList;
  final VoidCallback onRotateMap;
  final VoidCallback onToggleSet;
  final VoidCallback onAdvanceRecord;
  final VoidCallback onFlipNullability;
  final VoidCallback onShuffleBytes;
  final VoidCallback onMutateProfile;
  final VoidCallback onMutatePayload;

  @override
  Widget build(BuildContext context) {
    return _SampleSection(
      title: 'Mutate Samples',
      subtitle:
          'Use these buttons to trigger signal updates and inspect recomputation in DevTools.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: onIncrement,
              child: const Text('Increment Counter'),
            ),
            ElevatedButton(
              onPressed: onToggleBoolean,
              child: const Text('Toggle Boolean'),
            ),
            ElevatedButton(
              onPressed: onCycleEnum,
              child: const Text('Cycle Enum'),
            ),
            ElevatedButton(
              onPressed: onAdvanceCoreObjects,
              child: const Text('Advance Core Objects'),
            ),
            ElevatedButton(
              onPressed: onAppendList,
              child: const Text('Append List Item'),
            ),
            ElevatedButton(
              onPressed: onRotateMap,
              child: const Text('Rotate Map Value'),
            ),
            ElevatedButton(
              onPressed: onToggleSet,
              child: const Text('Toggle Set Tag'),
            ),
            ElevatedButton(
              onPressed: onAdvanceRecord,
              child: const Text('Advance Record'),
            ),
            ElevatedButton(
              onPressed: onFlipNullability,
              child: const Text('Flip Nullability'),
            ),
            ElevatedButton(
              onPressed: onShuffleBytes,
              child: const Text('Shuffle Bytes'),
            ),
            ElevatedButton(
              onPressed: onMutateProfile,
              child: const Text('Mutate Profile'),
            ),
            ElevatedButton(
              onPressed: onMutatePayload,
              child: const Text('Mutate Payload'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SampleSection extends StatelessWidget {
  const _SampleSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.reader);

  final Object? Function() reader;

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(
      builder: (context) => Text(
        _stringify(reader()),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  String _stringify(Object? value) {
    if (value is Uint8List) {
      return value.toList().toString();
    }
    return '$value';
  }
}

enum SampleStatus { idle, warming, success, failed }

class SampleAddress {
  const SampleAddress({required this.city, required this.zipCode});

  final String city;
  final int zipCode;

  @override
  String toString() => 'SampleAddress(city: $city, zipCode: $zipCode)';
}

class SampleProfile {
  const SampleProfile({
    required this.name,
    required this.age,
    required this.role,
    required this.address,
    required this.skills,
  });

  final String name;
  final int age;
  final String role;
  final SampleAddress address;
  final List<String> skills;

  SampleProfile copyWith({
    String? name,
    int? age,
    String? role,
    SampleAddress? address,
    List<String>? skills,
  }) {
    return SampleProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      role: role ?? this.role,
      address: address ?? this.address,
      skills: skills ?? this.skills,
    );
  }

  @override
  String toString() {
    return 'SampleProfile(name: $name, age: $age, role: $role, address: $address, skills: $skills)';
  }
}

class SamplePayload {
  const SamplePayload({
    required this.id,
    required this.profile,
    required this.timeline,
    required this.metrics,
  });

  final String id;
  final SampleProfile profile;
  final List<String> timeline;
  final Map<String, Object?> metrics;

  SamplePayload copyWith({
    String? id,
    SampleProfile? profile,
    List<String>? timeline,
    Map<String, Object?>? metrics,
  }) {
    return SamplePayload(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      timeline: timeline ?? this.timeline,
      metrics: metrics ?? this.metrics,
    );
  }

  @override
  String toString() {
    return 'SamplePayload(id: $id, profile: $profile, timeline: $timeline, metrics: $metrics)';
  }
}

JoltDebugOption? _debug(String label, String type) {
  return JoltDebugOption.merge(
    JoltDebugOption.label(label),
    JoltDebugOption.type(type),
  );
}
