import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

class SurgeConsumer<T extends Surge<S>, S> extends StatefulWidget {
  const SurgeConsumer({
    super.key,
    required this.builder,
    this.listener,
    this.buildWhen,
    this.listenWhen,
    this.surge,
  });

  final Widget Function(BuildContext context, S state, T surge) builder;
  final void Function(BuildContext context, S state, T surge)? listener;
  final bool Function(S prevState, S newState, T surge)? buildWhen;
  final bool Function(S prevState, S newState, T surge)? listenWhen;
  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return SurgeConsumerState<T, S>();
  }
}

class SurgeConsumerState<T extends Surge<S>, S>
    extends State<SurgeConsumer<T, S>> {
  SurgeConsumerState();

  late T _surge;
  late S _state;

  Effect? _effect;

  @override
  void initState() {
    super.initState();
    _surge = widget.surge ?? context.read<T>();
    _state = _surge.state;
    _startEffect();
  }

  @override
  void dispose() {
    super.dispose();
    _stopEffect();
  }

  @override
  void didUpdateWidget(SurgeConsumer<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSurge = oldWidget.surge ?? context.read<T>();
    final currentSurge = widget.surge ?? oldSurge;
    if (!identical(oldSurge, currentSurge)) {
      _surge = currentSurge;
      _state = _surge.state;
      _restartEffect();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surge = widget.surge ?? context.read<T>();
    if (!identical(_surge, surge)) {
      _surge = surge;
      _state = _surge.state;
      _restartEffect();
    }
  }

  void _startEffect() {
    final allowNullSkip =
        (widget.listenWhen == null || widget.listener == null) &&
            widget.buildWhen == null;
    bool firstEffect = true;
    _effect = Effect(() {
      if (!mounted) return;

      final state = _surge.state;
      final listenerTriggable = widget.listener != null &&
          (widget.listenWhen?.call(_state, state, _surge) ?? true);
      final builderTriggable =
          widget.buildWhen?.call(_state, state, _surge) ?? true;

      if ((_state == state && allowNullSkip) || firstEffect) {
        firstEffect = false;
        return;
      }

      if (listenerTriggable) {
        untracked(() {
          widget.listener!(context, state, _surge);
        });
      }
      if (builderTriggable) {
        (context as StatefulElement).markNeedsBuild();
      }

      _state = state;
    });
  }

  void _stopEffect() {
    _effect?.dispose();
    _effect = null;
  }

  void _restartEffect() {
    _stopEffect();
    _startEffect();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.surge == null) {
      context.select<T, bool>((surge) => identical(_surge, surge));
    }
    return widget.builder(context, _state, _surge);
  }
}
