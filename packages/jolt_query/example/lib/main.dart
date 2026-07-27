import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show JoltBuilder;
import 'package:jolt_query/jolt_query.dart';

import 'demo_controller.dart';

const _background = Color(0xFF071218);
const _surface = Color(0xFF0E2028);
const _surfaceHigh = Color(0xFF152A33);
const _mint = Color(0xFF61E6CB);
const _blue = Color(0xFF72A7FF);
const _amber = Color(0xFFFFC66D);
const _rose = Color(0xFFFF8098);
const _muted = Color(0xFF91AAB5);

void main() {
  runApp(const QueryLabApp());
}

final class QueryLabApp extends StatelessWidget {
  const QueryLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _mint,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _mint,
      secondary: _blue,
      surface: _surface,
      error: _rose,
    );
    return MaterialApp(
      title: 'Jolt Query Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _background,
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: const Color(0xFFE5F2F4),
              displayColor: const Color(0xFFF4FBFC),
            ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        tooltipTheme: const TooltipThemeData(waitDuration: Duration.zero),
      ),
      home: const QueryLabPage(),
    );
  }
}

final class QueryLabPage extends StatefulWidget {
  const QueryLabPage({super.key});

  @override
  State<QueryLabPage> createState() => _QueryLabPageState();
}

final class _QueryLabPageState extends State<QueryLabPage> {
  late final DemoController controller;

  @override
  void initState() {
    super.initState();
    controller = DemoController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.78, -1.05),
                radius: 1.35,
                colors: <Color>[Color(0xFF12343B), _background],
              ),
            ),
            child: SafeArea(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
                    vertical: 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _LabHeader(controller: controller),
                          const SizedBox(height: 24),
                          _QueryStoryCard(controller: controller),
                          const SizedBox(height: 28),
                          const _SectionIntro(
                            eyebrow: 'MORE QUERY WORKFLOWS',
                            title:
                                'The same client, beyond the core cache loop',
                            message:
                                'Try a cache write during an active request, '
                                'then compare it with explicit '
                                'cancel-before-write. Mutations, infinite '
                                'queries, and streams all compose with that '
                                'same cache.',
                          ),
                          const SizedBox(height: 16),
                          _FeatureColumns(controller: controller),
                          const SizedBox(height: 20),
                          _ActivityCard(controller: controller),
                          const SizedBox(height: 34),
                          const _Footer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _LabHeader extends StatelessWidget {
  const _LabHeader({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 18,
            spacing: 24,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 690),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _Eyebrow(
                      'SERVER-STATE CACHE  ·  QUERYWIDGET  ·  FLUTTER WEB',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Jolt Query Lab',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Change one input and watch the query key, cache entry, '
                      'result state, and automatic fetch behavior move '
                      'together.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _muted,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _EnvironmentToggle(
                    label: 'Simulated online',
                    icon: Icons.wifi_rounded,
                    value: controller.isOnline,
                    onTap: controller.toggleOnline,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow(eyebrow),
          const SizedBox(height: 7),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

final class _FeatureColumns extends StatelessWidget {
  const _FeatureColumns({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final left = Column(
      children: <Widget>[
        _RuntimeCard(controller: controller),
        const SizedBox(height: 20),
        _StreamCard(controller: controller),
      ],
    );
    final right = Column(
      children: <Widget>[
        _MutationCard(controller: controller),
        const SizedBox(height: 20),
        _InfiniteCard(controller: controller),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 940) {
          return Column(
            children: <Widget>[
              left,
              const SizedBox(height: 20),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 20),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

final class _QueryStoryCard extends StatelessWidget {
  const _QueryStoryCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _FeatureCard(
      number: '01',
      title: 'A Query follows its key',
      subtitle: 'QueryWidget(query: target) → cached data and execution state',
      accent: _mint,
      child: JoltBuilder(
        builder: (context) {
          final selectedPage = controller.projectPage.value;
          final stalePreset = controller.stalePreset.value;
          final keepPrevious = controller.keepPreviousProjects.value;
          final configuredQuery = ProjectsQuery(
            client: controller.client,
            api: controller.api,
            page: selectedPage,
          ).observer(
            staleTime: stalePreset.policy,
            refetchOnMount: RefetchPolicy.stale,
            refetchOnFocus: RefetchPolicy.stale,
            refetchOnReconnect: RefetchPolicy.stale,
          );
          final target = keepPrevious
              ? configuredQuery.placeholder((previous) => previous)
              : configuredQuery;

          return QueryWidget<ProjectPage>(
            query: target,
            builder: (context, observer) {
              final result = observer.value;
              final data =
                  result.data.isPresent ? result.data.requireValue() : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _QueryCausalChain(
                    page: selectedPage,
                    result: result,
                  ),
                  const SizedBox(height: 10),
                  const _InfoBanner(
                    icon: Icons.widgets_outlined,
                    title: 'This result is built by QueryWidget',
                    message: 'The outer JoltBuilder tracks only the query '
                        'inputs. Same-key recipe updates change configuration '
                        'in place; changing page changes the key and '
                        'automatically queries its absent or stale cache '
                        'entry. QueryWidget owns that observer.',
                    color: _blue,
                  ),
                  const SizedBox(height: 10),
                  const _InfoBanner(
                    icon: Icons.timer_off_outlined,
                    title: 'stale ≠ fetching',
                    message: 'The stale deadline only flips isStale. '
                        'Expiration alone never starts a request; mount, key '
                        'revisit, focus, reconnect, or invalidation provides '
                        'the trigger.',
                    color: _amber,
                  ),
                  const SizedBox(height: 16),
                  _QueryDefinitionPanel(
                    page: selectedPage,
                    stalePreset: stalePreset,
                    keepPrevious: keepPrevious,
                  ),
                  const SizedBox(height: 16),
                  _ProjectPageSelector(
                    selectedPage: selectedPage,
                    requestCount: controller.projectRequestCount,
                    busy: controller.isProjectsBusy,
                    onSelected: controller.selectProjectPage,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final resultPanel = _ProjectResultPanel(
                        selectedPage: selectedPage,
                        data: data,
                        result: result,
                      );
                      final statePanel = _QueryStatePanel(
                        result: result,
                        selectedPage: selectedPage,
                        totalRequests: controller.projectTotalRequests,
                        currentPageRequests:
                            controller.projectRequestCount(selectedPage),
                      );
                      if (constraints.maxWidth < 900) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            resultPanel,
                            const SizedBox(height: 12),
                            statePanel,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(flex: 3, child: resultPanel),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: statePanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _QueryBehaviorControls(
                    controller: controller,
                    stalePreset: stalePreset,
                    keepPrevious: keepPrevious,
                    activeKey: result.key,
                    observer: observer,
                  ),
                  const SizedBox(height: 16),
                  _ProjectCachePanel(
                    snapshots: controller.projectCacheSnapshots,
                    currentKey: result.key,
                    currentIsStale: result.isStale,
                    requestCount: controller.projectRequestCount,
                  ),
                  const SizedBox(height: 16),
                  const _StaleRules(),
                  if (result.failure case final failure?) ...<Widget>[
                    const SizedBox(height: 12),
                    _FailureBanner('${failure.error}'),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: controller.isProjectsBusy
                          ? null
                          : () => unawaited(controller.resetProjectsDemo()),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset Query demo'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

final class _QueryCausalChain extends StatelessWidget {
  const _QueryCausalChain({required this.page, required this.result});

  final int page;
  final QueryObserverResult<ProjectPage> result;

  @override
  Widget build(BuildContext context) {
    final nodes = <Widget>[
      _CausalNode(
        icon: Icons.tune_rounded,
        label: 'page signal',
        value: '$page',
        color: _blue,
      ),
      _CausalNode(
        icon: Icons.key_rounded,
        label: 'queryKey',
        value: "['projects', $page]",
        color: _mint,
      ),
      _CausalNode(
        icon: Icons.inventory_2_outlined,
        label: 'cache entry',
        value: result.data.isPresent ? 'present' : 'absent',
        color: _amber,
      ),
      _CausalNode(
        icon: Icons.monitor_heart_outlined,
        label: 'state',
        value: '${result.status.name} / ${result.fetchStatus.name}',
        color: result.fetchStatus == FetchStatus.fetching ? _blue : _mint,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                nodes[0],
                const _CausalArrow(vertical: true),
                nodes[1],
                const _CausalArrow(vertical: true),
                nodes[2],
                const _CausalArrow(vertical: true),
                nodes[3],
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: nodes[0]),
              const _CausalArrow(),
              Expanded(child: nodes[1]),
              const _CausalArrow(),
              Expanded(child: nodes[2]),
              const _CausalArrow(),
              Expanded(child: nodes[3]),
            ],
          );
        },
      ),
    );
  }
}

final class _CausalNode extends StatelessWidget {
  const _CausalNode({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _CausalArrow extends StatelessWidget {
  const _CausalArrow({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 5),
      child: Icon(
        vertical ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
        size: 18,
        color: _muted,
      ),
    );
  }
}

final class _QueryDefinitionPanel extends StatelessWidget {
  const _QueryDefinitionPanel({
    required this.page,
    required this.stalePreset,
    required this.keepPrevious,
  });

  final int page;
  final DemoStalePreset stalePreset;
  final bool keepPrevious;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF071116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final equation = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Eyebrow('QUERYWIDGET QUERY INPUT'),
              const SizedBox(height: 8),
              Text(
                'QueryKey([\'projects\', $page])',
                style: const TextStyle(
                  color: _mint,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'The key is the dependency list and cache identity.',
                style: TextStyle(color: _muted, height: 1.35),
              ),
            ],
          );
          final options = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Eyebrow('TARGET OPTIONS'),
              const SizedBox(height: 8),
              Text(
                'staleTime: StalePolicy.${stalePreset.codeLabel}',
                style: const TextStyle(
                  color: Color(0xFFBCD0D7),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                keepPrevious
                    ? 'placeholder: (previous) => previous'
                    : 'placeholder: none',
                style: const TextStyle(
                  color: Color(0xFFBCD0D7),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                equation,
                const SizedBox(height: 16),
                options,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: equation),
              Container(
                width: 1,
                height: 76,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(child: options),
            ],
          );
        },
      ),
    );
  }
}

final class _ProjectPageSelector extends StatelessWidget {
  const _ProjectPageSelector({
    required this.selectedPage,
    required this.requestCount,
    required this.busy,
    required this.onSelected,
  });

  final int selectedPage;
  final int Function(int page) requestCount;
  final bool busy;
  final void Function(int page) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '1. Change the key input',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const _Pill(
              label: 'no refetch() call',
              color: _blue,
              icon: Icons.auto_mode_rounded,
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (var page = 1; page <= 3; page += 1)
              _ProjectPageButton(
                page: page,
                selected: page == selectedPage,
                requests: requestCount(page),
                onPressed: busy ? null : () => onSelected(page),
              ),
          ],
        ),
      ],
    );
  }
}

final class _ProjectPageButton extends StatelessWidget {
  const _ProjectPageButton({
    required this.page,
    required this.selected,
    required this.requests,
    required this.onPressed,
  });

  final int page;
  final bool selected;
  final int requests;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        backgroundColor:
            selected ? _mint.withValues(alpha: 0.12) : Colors.transparent,
        side: BorderSide(
          color: selected
              ? _mint.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Page $page',
            style: TextStyle(
              color: selected ? _mint : null,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$requests request${requests == 1 ? '' : 's'}',
            style: const TextStyle(color: _muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

final class _ProjectResultPanel extends StatelessWidget {
  const _ProjectResultPanel({
    required this.selectedPage,
    required this.data,
    required this.result,
  });

  final int selectedPage;
  final ProjectPage? data;
  final QueryObserverResult<ProjectPage> result;

  @override
  Widget build(BuildContext context) {
    return _QueryDemoPanel(
      eyebrow: 'RENDERED DATA',
      title: data == null
          ? 'Page $selectedPage has no data yet'
          : 'Projects from page ${data!.page}',
      trailing: _QueryStatusPill(result: result),
      child: data == null
          ? Container(
              constraints: const BoxConstraints(minHeight: 174),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (result.isFetching)
                    const SizedBox.square(
                      dimension: 27,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    const Icon(
                      Icons.inbox_outlined,
                      color: _muted,
                      size: 28,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    result.isFetching
                        ? 'Fetching this key for the first time…'
                        : 'No cached result for this key.',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    _CodePill('server r${data!.serverRevision}'),
                    _CodePill('request #${data!.requestNumber}'),
                    if (result.isPlaceholderData)
                      const _Pill(
                        label: 'previous page placeholder',
                        color: _amber,
                        icon: Icons.layers_outlined,
                      ),
                    if (data!.page != selectedPage)
                      _Pill(
                        label: 'waiting for page $selectedPage',
                        color: _amber,
                        icon: Icons.hourglass_top_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final project in data!.items)
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            project.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '#${project.id}',
                          style: const TextStyle(
                            color: _muted,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

final class _QueryStatePanel extends StatelessWidget {
  const _QueryStatePanel({
    required this.result,
    required this.selectedPage,
    required this.totalRequests,
    required this.currentPageRequests,
  });

  final QueryObserverResult<ProjectPage> result;
  final int selectedPage;
  final int totalRequests;
  final int currentPageRequests;

  @override
  Widget build(BuildContext context) {
    return _QueryDemoPanel(
      eyebrow: 'QUERYWIDGET BUILDER RESULT',
      title: 'Two independent state axes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StateAxis(
            label: 'status',
            value: result.status.name,
            message: 'Does usable data exist?',
            color: switch (result.status) {
              QueryStatus.pending => _muted,
              QueryStatus.success => _mint,
              QueryStatus.error => _rose,
            },
          ),
          const SizedBox(height: 8),
          _StateAxis(
            label: 'fetchStatus',
            value: result.fetchStatus.name,
            message: 'Is transport running right now?',
            color: switch (result.fetchStatus) {
              FetchStatus.fetching => _blue,
              FetchStatus.paused => _amber,
              FetchStatus.idle => _muted,
            },
          ),
          const SizedBox(height: 12),
          _FactRow(label: 'key', value: result.key.toString(), monospace: true),
          _FactRow(
            label: 'isStale',
            value: '${result.isStale}',
          ),
          _FactRow(
            label: 'isPlaceholderData',
            value: '${result.isPlaceholderData}',
          ),
          _FactRow(
            label: 'selected page requests',
            value: '$currentPageRequests',
          ),
          _FactRow(label: 'all project requests', value: '$totalRequests'),
          const SizedBox(height: 6),
          Text(
            _stateExplanation(result, selectedPage),
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

final class _StateAxis extends StatelessWidget {
  const _StateAxis({
    required this.label,
    required this.value,
    required this.message,
    required this.color,
  });

  final String label;
  final String value;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

final class _QueryBehaviorControls extends StatelessWidget {
  const _QueryBehaviorControls({
    required this.controller,
    required this.stalePreset,
    required this.keepPrevious,
    required this.activeKey,
    required this.observer,
  });

  final DemoController controller;
  final DemoStalePreset stalePreset;
  final bool keepPrevious;
  final QueryKey activeKey;
  final QueryObserver<ProjectPage> observer;

  @override
  Widget build(BuildContext context) {
    return _QueryDemoPanel(
      eyebrow: 'FRESHNESS EXPERIMENTS',
      title: '2. Follow key → stale → trigger',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '① Page 1 mounts and fetches. ② Open page 2: the key changes, so '
            'QueryWidget retargets its observer and fetches. ③ Return to page '
            '1 before five seconds: fresh cache is reused with no request. '
            '④ Wait for isStale to flip: still no request. ⑤ Focus, reconnect, '
            'or invalidate: that trigger may start a background refetch.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          SegmentedButton<DemoStalePreset>(
            segments: <ButtonSegment<DemoStalePreset>>[
              for (final preset in DemoStalePreset.values)
                ButtonSegment<DemoStalePreset>(
                  value: preset,
                  label: Text(preset.label),
                ),
            ],
            selected: <DemoStalePreset>{stalePreset},
            onSelectionChanged: controller.isProjectsBusy
                ? null
                : (selection) => controller.selectStalePreset(selection.single),
            showSelectedIcon: false,
          ),
          if (stalePreset == DemoStalePreset.immutable) ...<Widget>[
            const SizedBox(height: 10),
            const _InfoBanner(
              icon: Icons.lock_outline_rounded,
              title: 'This observed query is now static',
              message: 'Invalidate still marks the cache entry, but bulk and '
                  'automatic refetch skip it. “Explicit observer refetch” '
                  'still runs because the caller asked for this exact observer.',
              color: _amber,
            ),
          ],
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: keepPrevious,
              onChanged: controller.isProjectsBusy
                  ? null
                  : (_) => controller.toggleKeepPreviousProjects(),
              title: const Text('Keep previous page while the new key loads'),
              subtitle: const Text(
                'Observer-local placeholder only; page caches stay separate.',
                style: TextStyle(color: _muted),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ButtonWrap(
            children: <Widget>[
              _DemoButton(
                label: 'Lose + regain focus',
                icon: Icons.center_focus_strong_rounded,
                busy: controller.isProjectsBusy,
                onPressed: controller.simulateProjectFocusCycle,
              ),
              _DemoButton(
                label: 'Disconnect + reconnect',
                icon: Icons.wifi_find_rounded,
                busy: controller.isProjectsBusy,
                onPressed: controller.simulateProjectReconnect,
              ),
              _DemoButton(
                label: 'Invalidate active key',
                icon: Icons.bolt_rounded,
                busy: controller.isProjectsBusy,
                onPressed: () => controller.invalidateCurrentProjects(
                  activeKey,
                ),
              ),
              _DemoButton(
                label: 'Explicit observer refetch',
                icon: Icons.refresh_rounded,
                busy: controller.isProjectsBusy,
                onPressed: () => controller.refetchCurrentProjects(observer),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isProjectsBusy
                    ? null
                    : controller.changeProjectsOnServer,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Change server only'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            '“Change server only” proves that server state does not push into '
            'the cache. Fire a trigger after the deadline to pull it; cached '
            'data remains visible while fetchStatus = fetching.',
            style: TextStyle(color: _mint, height: 1.4, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

final class _ProjectCachePanel extends StatelessWidget {
  const _ProjectCachePanel({
    required this.snapshots,
    required this.currentKey,
    required this.currentIsStale,
    required this.requestCount,
  });

  final List<QueryCacheSnapshot> snapshots;
  final QueryKey currentKey;
  final bool currentIsStale;
  final int Function(int page) requestCount;

  @override
  Widget build(BuildContext context) {
    return _QueryDemoPanel(
      eyebrow: 'CACHE BY QUERY KEY',
      title: 'Each page keeps an independent entry',
      child: snapshots.isEmpty
          ? const Text(
              'The first request will create QueryKey([projects, 1]).',
              style: TextStyle(color: _muted),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 780
                    ? (constraints.maxWidth - 16) / 3
                    : constraints.maxWidth >= 480
                        ? (constraints.maxWidth - 8) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final snapshot in snapshots)
                      SizedBox(
                        width: width,
                        child: _ProjectCacheTile(
                          snapshot: snapshot,
                          activeIsStale: snapshot.key == currentKey
                              ? currentIsStale
                              : null,
                          requests: requestCount(
                            snapshot.key.parts.length > 1 &&
                                    snapshot.key.parts[1] is int
                                ? snapshot.key.parts[1]! as int
                                : -1,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

final class _ProjectCacheTile extends StatelessWidget {
  const _ProjectCacheTile({
    required this.snapshot,
    required this.activeIsStale,
    required this.requests,
  });

  final QueryCacheSnapshot snapshot;
  final bool? activeIsStale;
  final int requests;

  @override
  Widget build(BuildContext context) {
    final cachedValue =
        snapshot.data.isPresent ? snapshot.data.requireValue() : null;
    final cachedPage = cachedValue is ProjectPage ? cachedValue : null;
    final page = snapshot.key.parts.length > 1 && snapshot.key.parts[1] is int
        ? snapshot.key.parts[1]! as int
        : -1;
    final active = snapshot.isActive;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? _mint.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active
              ? _mint.withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  page < 0 ? snapshot.key.toString() : '[projects, $page]',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (active)
                const _Pill(
                  label: 'active',
                  color: _mint,
                  icon: Icons.visibility_outlined,
                ),
            ],
          ),
          const SizedBox(height: 9),
          _FactRow(
            label: 'state',
            value: '${snapshot.status.name} / ${snapshot.fetchStatus.name}',
          ),
          _FactRow(
            label: 'observers',
            value: '${snapshot.activeObserverCount}/${snapshot.observerCount} '
                'active',
          ),
          _FactRow(label: 'requests', value: '$requests'),
          _FactRow(
            label: 'cached response',
            value: cachedPage == null
                ? 'absent'
                : 'server r${cachedPage.serverRevision}',
          ),
          if (activeIsStale case final stale?)
            _FactRow(label: 'observer stale', value: '$stale'),
        ],
      ),
    );
  }
}

final class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _QueryDemoPanel extends StatelessWidget {
  const _QueryDemoPanel({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Eyebrow(eyebrow),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (trailing case final trailing?) ...<Widget>[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

final class _StaleRules extends StatelessWidget {
  const _StaleRules();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const rules = <Widget>[
          _StaleRule(
            number: '1',
            title: 'Stale is eligibility',
            message: 'The stale deadline only flips isStale. It does not '
                'start transport.',
          ),
          _StaleRule(
            number: '2',
            title: 'Triggers make the decision',
            message: 'Mount, key revisit, focus, reconnect, and invalidate '
                'check freshness.',
          ),
          _StaleRule(
            number: '3',
            title: 'Data can stay while fetching',
            message: 'A stale cached entry can be success + fetching during '
                'background revalidation.',
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            children: <Widget>[
              rules[0],
              SizedBox(height: 8),
              rules[1],
              SizedBox(height: 8),
              rules[2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: rules[0]),
            SizedBox(width: 8),
            Expanded(child: rules[1]),
            SizedBox(width: 8),
            Expanded(child: rules[2]),
          ],
        );
      },
    );
  }
}

final class _StaleRule extends StatelessWidget {
  const _StaleRule({
    required this.number,
    required this.title,
    required this.message,
  });

  final String number;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _mint.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mint.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: _background,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _stateExplanation(
  QueryObserverResult<ProjectPage> result,
  int selectedPage,
) {
  if (result.isLoading) {
    return 'Page $selectedPage has no cached data: pending + fetching is the '
        'initial load state.';
  }
  if (result.isRefetching) {
    return 'Cached data remains usable: success + fetching is a background '
        'refetch, not a loading screen.';
  }
  if (result.fetchStatus == FetchStatus.paused) {
    return 'The request is eligible but paused by ${result.pauseReason?.name}.';
  }
  if (result.isStale) {
    return 'The data is stale and idle. No request starts until an automatic '
        'trigger or an explicit invalidation/refetch occurs.';
  }
  return 'The cache entry is fresh and idle. Revisiting this key reuses it '
      'without a request.';
}

final class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _FeatureCard(
      number: '02',
      title: 'Fetch lane + data lane',
      subtitle: 'state-derived polling · cancellation · retry · data writes',
      accent: _blue,
      child: JoltBuilder(
        builder: (context) {
          final poll = controller.pollingObserver.value;
          final dataLane = controller.dataLaneObserver.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: _EnvironmentToggle(
                  label: 'Simulated focus',
                  icon: Icons.center_focus_strong_rounded,
                  value: controller.isFocused,
                  onTap: controller.toggleFocused,
                ),
              ),
              const SizedBox(height: 12),
              _InfoBanner(
                icon: Icons.timer_outlined,
                title: 'State-derived poll tick ${_queryValue(poll.data)}',
                message: controller.isFocused
                    ? 'The resolver read the complete result and selected '
                        '${controller.nextPollingInterval.inSeconds}s before '
                        'the next poll (even ticks → 2s, odd ticks → 1s).'
                    : 'Polling is suspended while simulated focus is off.',
                color: controller.isFocused ? _blue : _amber,
              ),
              if (controller.lastGreeting case final greeting?) ...<Widget>[
                const SizedBox(height: 10),
                _InfoBanner(
                  icon: Icons.check_circle_outline_rounded,
                  title: greeting,
                  message: 'First attempt failed; typed retry succeeded.',
                  color: _mint,
                ),
              ],
              const SizedBox(height: 14),
              _ButtonWrap(
                children: <Widget>[
                  _DemoButton(
                    label: 'Run typed retry',
                    icon: Icons.replay_rounded,
                    busy: controller.isBusy('retry'),
                    onPressed: controller.runGreetingRetry,
                  ),
                  _DemoButton(
                    label: 'Cancel query',
                    icon: Icons.cancel_outlined,
                    busy: controller.isBusy('cancel'),
                    onPressed: controller.runCancellationDemo,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'The online switch gates NetworkMode.online attempts. The '
                'focus switch gates retry continuation as well as automatic '
                'refetch and polling; it does not abort an in-flight attempt.',
                style: TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'A/B: who wins after a manual cache write?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const _FactRow(
                label: 'A · setQueryData during fetch',
                value: 'operation stays active; server may win',
              ),
              const _FactRow(
                label: 'B · await cancelQueries, then write',
                value: 'late server result cannot win',
              ),
              const SizedBox(height: 6),
              _InfoBanner(
                icon: Icons.call_split_rounded,
                title: 'cache ${_queryValue(dataLane.data)} · '
                    '${dataLane.fetchStatus.name}',
                message: controller.dataLaneExplanation,
                color: _mint,
              ),
              const SizedBox(height: 12),
              _ButtonWrap(
                children: <Widget>[
                  _DemoButton(
                    label: 'Write 777 during fetch',
                    icon: Icons.edit_note_rounded,
                    busy: controller.isBusy('data-lane'),
                    onPressed: controller.runNonCancellingWriteDemo,
                  ),
                  _DemoButton(
                    label: 'Cancel, then write 888',
                    icon: Icons.lock_outline_rounded,
                    busy: controller.isBusy('data-lane'),
                    onPressed: controller.runProtectedWriteDemo,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _MutationCard extends StatelessWidget {
  const _MutationCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _FeatureCard(
      number: '03',
      title: 'One Mutation, optional optimism',
      subtitle:
          'MutationWidget · Mutation<V, D, R> · onMutate · FIFO scope · retry',
      accent: _amber,
      child: MutationWidget<String, Todo, void>(
        client: controller.client,
        mutation: controller.renameMutation,
        builder: (context, renameObserver) =>
            MutationWidget<int, int, CounterRollback>(
          client: controller.client,
          mutation: controller.incrementMutation,
          builder: (context, incrementObserver) => JoltBuilder(
            builder: (context) {
              final rename = renameObserver.snapshot;
              final increment = incrementObserver.snapshot;
              final counter = controller.counterObserver.value;
              final mutating = controller.client.mutatingCount.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricBox(
                          label: 'cached counter',
                          value: '${_queryValue(counter.data)}',
                          accent: _amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricBox(
                          label: 'mutating',
                          value: '$mutating',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _InfoBanner(
                    icon: Icons.data_object_rounded,
                    title: 'V = int · D = int · R = CounterRollback',
                    message: 'onMutate is ordinary user code: it snapshots and '
                        'writes the counter, then returns a typed rollback '
                        'checkpoint as R. The mutation runtime itself performs '
                        'no optimistic cache behavior.',
                    color: _amber,
                  ),
                  const SizedBox(height: 10),
                  const _InfoBanner(
                    icon: Icons.schedule_send_outlined,
                    title: 'Terminal observer → per-call callback → Future',
                    message: 'Run either counter mutation and inspect the '
                        'timeline. The per-call callback already reads success '
                        'or error; only after it returns does execute() '
                        'complete.',
                    color: _blue,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MutationStatusPill(
                        label: 'rename',
                        status: rename.status,
                        paused: rename.isPaused,
                      ),
                      _MutationStatusPill(
                        label: 'counter',
                        status: increment.status,
                        paused: increment.isPaused,
                      ),
                      if (increment.onMutateResult.isPresent)
                        _Pill(
                          label: 'R checkpoint revision '
                              '${increment.onMutateResult.requireValue().optimisticRevision}',
                          color: _blue,
                          icon: Icons.shield_outlined,
                        ),
                    ],
                  ),
                  if (increment.failure case final failure?) ...<Widget>[
                    const SizedBox(height: 10),
                    _FailureBanner('${failure.error}'),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    '“Run FIFO writes” submits two class-first rename mutations '
                    'and one action (the same runtime with NoVariables) into one '
                    'MutationScope. The transport log below proves serialization.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _ButtonWrap(
                    children: <Widget>[
                      _DemoButton(
                        label: 'Run FIFO writes',
                        icon: Icons.low_priority_rounded,
                        busy: controller.isBusy('scope'),
                        onPressed: () =>
                            controller.runScopedWrites(renameObserver),
                      ),
                      _DemoButton(
                        label: '+2 with retry',
                        icon: Icons.add_rounded,
                        busy: controller.isBusy('counter'),
                        onPressed: () =>
                            controller.changeCounter(incrementObserver, 2),
                      ),
                      _DemoButton(
                        label: '−1 and rollback',
                        icon: Icons.undo_rounded,
                        busy: controller.isBusy('counter'),
                        onPressed: () =>
                            controller.changeCounter(incrementObserver, -1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Scope transport log',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _muted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (controller.transportLog.isEmpty)
                    const Text(
                      'Run the FIFO demo to see start/end ordering.',
                      style: TextStyle(color: _muted),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final entry in controller.transportLog)
                          _CodePill(entry),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _InfiniteCard extends StatelessWidget {
  const _InfiniteCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return _FeatureCard(
      number: '04',
      title: 'Infinite query',
      subtitle:
          'InfiniteQueryWidget · explicit cursor · directional lane · maxPages',
      accent: _rose,
      child: InfiniteQueryWidget<InfiniteData<String, int>>(
        query: controller.feedQuery.observer(enabled: false),
        builder: (context, feedObserver) {
          final result = feedObserver.snapshot;
          final data = result.data.isPresent
              ? result.data.requireValue()
              : InfiniteData<String, int>(
                  pages: const <String>[],
                  pageParams: const <int>[],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _QueryStatusPill(result: result.query),
                  _Pill(
                    label: result.hasNextPage ? 'has next' : 'end reached',
                    color: result.hasNextPage ? _mint : _muted,
                    icon: Icons.arrow_forward_rounded,
                  ),
                  _Pill(
                    label: '${data.pages.length}/3 retained',
                    color: _rose,
                    icon: Icons.view_carousel_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _InfoBanner(
                icon: Icons.layers_outlined,
                title: 'Refresh preserves the retained window',
                message: 'Atomic refresh rebuilds the current reachable page '
                    'count. An exception retry resumes at its failed page; '
                    'maxPages trims the opposite edge on directional fetch.',
                color: _rose,
              ),
              const SizedBox(height: 14),
              if (data.isEmpty)
                const _EmptyState(
                  icon: Icons.dynamic_feed_outlined,
                  message: 'Load the initial page, then fetch forward.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (var index = 0; index < data.pages.length; index += 1)
                      _PageTile(
                        page: data.pages[index],
                        parameter: data.pageParams[index],
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              _ButtonWrap(
                children: <Widget>[
                  _DemoButton(
                    label: data.isEmpty ? 'Load initial' : 'Atomic refresh',
                    icon: Icons.refresh_rounded,
                    busy: controller.isBusy('feed'),
                    onPressed: () => controller.loadFeed(feedObserver),
                  ),
                  _DemoButton(
                    label: 'Next page',
                    icon: Icons.arrow_forward_rounded,
                    busy: controller.isBusy('feed'),
                    onPressed: () => controller.fetchNextPage(feedObserver),
                  ),
                  _DemoButton(
                    label: 'Previous no-op',
                    icon: Icons.arrow_back_rounded,
                    busy: controller.isBusy('feed'),
                    onPressed: () => controller.fetchPreviousPage(feedObserver),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _StreamCard extends StatelessWidget {
  const _StreamCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final mode = controller.streamMode;
    return _FeatureCard(
      number: '05',
      title: 'Stream-backed query',
      subtitle:
          'streamedListQuery · visibility modes · retry-safe accumulation',
      accent: const Color(0xFFBA93FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<StreamRefetchMode>(
            segments: <ButtonSegment<StreamRefetchMode>>[
              for (final value in StreamRefetchMode.values)
                ButtonSegment<StreamRefetchMode>(
                  value: value,
                  label: Text(value.name),
                ),
            ],
            selected: <StreamRefetchMode>{mode},
            onSelectionChanged: controller.isBusy('stream')
                ? null
                : (selection) => controller.selectStreamMode(selection.single),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 14),
          JoltBuilder(
            builder: (context) {
              final result = controller.selectedStreamObserver.value;
              final values = result.data.isPresent
                  ? result.data.requireValue()
                  : IList<int>();
              final attempt = controller.streamAttemptCount(mode);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _InfoBanner(
                    icon: _streamIcon(mode),
                    title: 'StreamRefetchMode.${mode.name}',
                    message: _streamDescription(mode),
                    color: const Color(0xFFBA93FF),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricBox(
                          label: 'query status',
                          value: result.status.name,
                          accent: const Color(0xFFBA93FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBox(
                          label: 'fetch status',
                          value: result.fetchStatus.name,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBox(
                          label: 'stream attempt',
                          value: '$attempt',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(minHeight: 76),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: values.isEmpty
                        ? const Center(
                            child: Text(
                              'Attempt 1 stops after chunk 1. During retry '
                              'delay [99] is written without cancellation; '
                              'the next attempt then applies the selected '
                              'mode’s reset/baseline rule.',
                              style: TextStyle(color: _muted),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final value in values)
                                _NumberToken(value: value),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _DemoButton(
                    label: 'Run: [0] → [1] → [99] → retry',
                    icon: Icons.stream_rounded,
                    busy: controller.isBusy('stream'),
                    onPressed: controller.runStream,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.controller});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final querySnapshots = controller.client.queryCache.snapshots;
    final mutationSnapshots = controller.client.mutationCache.snapshots;
    return _FeatureCard(
      number: '06',
      title: 'Cache inspector + event timeline',
      subtitle: 'immutable snapshots · query events · mutation events',
      accent: _blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _InfoBanner(
            icon: Icons.rule_folder_outlined,
            title: 'Post-commit QueryCache callbacks',
            message: 'QueryCacheCallbacks lines are emitted after terminal '
                'state commits and before the caller’s Future resumes. Retry '
                'attempts, stream partials, cancellation, and manual writes '
                'do not create terminal callback pairs.',
            color: _blue,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Pill(
                label: '${querySnapshots.length} query entries',
                color: _blue,
                icon: Icons.storage_rounded,
              ),
              _Pill(
                label: '${mutationSnapshots.length} mutation entries',
                color: _amber,
                icon: Icons.swap_horiz_rounded,
              ),
              for (final snapshot in querySnapshots.take(8))
                _CodePill(snapshot.key.toString()),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF071116),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: controller.activity.isEmpty
                ? const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'Interactions will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: controller.activity.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withValues(alpha: 0.05),
                      height: 16,
                    ),
                    itemBuilder: (context, index) {
                      return Text(
                        controller.activity[index],
                        style: const TextStyle(
                          color: Color(0xFFB8CDD4),
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

final class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _muted,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

final class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: busy ? null : () => unawaited(onPressed()),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

final class _ButtonWrap extends StatelessWidget {
  const _ButtonWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

final class _EnvironmentToggle extends StatelessWidget {
  const _EnvironmentToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = value ? _mint : _rose;
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    this.accent = _mint,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

final class _PageTile extends StatelessWidget {
  const _PageTile({required this.page, required this.parameter});

  final String page;
  final int parameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _rose.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rose.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(page, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('param $parameter', style: const TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

final class _NumberToken extends StatelessWidget {
  const _NumberToken({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFBA93FF).withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFBA93FF).withValues(alpha: 0.35),
        ),
      ),
      child:
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

final class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: _muted, size: 25),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

final class _FailureBanner extends StatelessWidget {
  const _FailureBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _rose.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _rose.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: _rose, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: _rose))),
        ],
      ),
    );
  }
}

final class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class _QueryStatusPill extends StatelessWidget {
  const _QueryStatusPill({required this.result});

  final QueryObserverResult<Object?> result;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (result.fetchStatus) {
      FetchStatus.fetching => (
          result.isRefetching ? 'refetching' : 'fetching',
          _blue,
          Icons.downloading_rounded,
        ),
      FetchStatus.paused => (
          'paused · ${result.pauseReason?.name}',
          _amber,
          Icons.pause_rounded,
        ),
      FetchStatus.idle => switch (result.status) {
          QueryStatus.pending => ('pending', _muted, Icons.hourglass_empty),
          QueryStatus.success => ('success', _mint, Icons.check_rounded),
          QueryStatus.error => ('error', _rose, Icons.error_outline_rounded),
        },
    };
    return _Pill(label: label, color: color, icon: icon);
  }
}

final class _MutationStatusPill extends StatelessWidget {
  const _MutationStatusPill({
    required this.label,
    required this.status,
    required this.paused,
  });

  final String label;
  final MutationStatus status;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = paused
        ? (_amber, Icons.pause_rounded)
        : switch (status) {
            MutationStatus.idle => (_muted, Icons.horizontal_rule_rounded),
            MutationStatus.pending => (_blue, Icons.sync_rounded),
            MutationStatus.success => (_mint, Icons.check_rounded),
            MutationStatus.error => (_rose, Icons.error_outline_rounded),
          };
    return _Pill(
      label: '$label · ${paused ? 'paused' : status.name}',
      color: color,
      icon: icon,
    );
  }
}

final class _CodePill extends StatelessWidget {
  const _CodePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFBCD0D7),
          fontFamily: 'monospace',
          fontSize: 11.5,
        ),
      ),
    );
  }
}

final class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _mint,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.55,
      ),
    );
  }
}

final class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.bolt_rounded, color: _mint, size: 17),
        SizedBox(width: 7),
        Text(
          'jolt_query · one client owns every resource on this page',
          style: TextStyle(color: _muted),
        ),
      ],
    );
  }
}

Object _queryValue<T>(QueryValue<T> value) {
  return value.isPresent ? value.requireValue() as Object : '—';
}

IconData _streamIcon(StreamRefetchMode mode) {
  return switch (mode) {
    StreamRefetchMode.reset => Icons.restart_alt_rounded,
    StreamRefetchMode.append => Icons.playlist_add_rounded,
    StreamRefetchMode.replace => Icons.swap_horiz_rounded,
  };
}

String _streamDescription(StreamRefetchMode mode) {
  return switch (mode) {
    StreamRefetchMode.reset =>
      'The manual [0] makes this entry fetched. With no configured initial '
          'data, every attempt restores pending absence before subscribing: '
          '[1] may survive the delay, but retry start clears [99] before its '
          'next accepted chunks.',
    StreamRefetchMode.append =>
      'Both attempts rebuild from the logical [0] baseline, never the failed '
          'partial. Manual [99] stays visible until an accepted retry chunk '
          'publishes rebuilt output without duplication.',
    StreamRefetchMode.replace =>
      'Both attempts remain private. Manual [99] stays visible until retry '
          'closes and atomically commits [1, 2, 3].',
  };
}
