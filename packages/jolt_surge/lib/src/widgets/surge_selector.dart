import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

class SurgeSelector<T extends Surge<S>, S, C> extends StatefulWidget {
  const SurgeSelector({
    super.key,
    required this.builder,
    required this.selector,
    this.surge,
  });

  final Widget Function(BuildContext context, C state, T surge) builder;
  final C Function(S state, T surge) selector;

  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return SurgeSelectorState<T, S, C>();
  }
}

class SurgeSelectorState<T extends Surge<S>, S, C>
    extends State<SurgeSelector<T, S, C>> {
  SurgeSelectorState();

  late T _surge;
  late C _selectorValue;

  Effect? _effect;

  @override
  void initState() {
    super.initState();
    _surge = widget.surge ?? context.read<T>();
    _selectorValue = widget.selector(_surge.state, _surge);
    _startEffect();
  }

  @override
  void dispose() {
    super.dispose();
    _stopEffect();
  }

  @override
  void didUpdateWidget(SurgeSelector<T, S, C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSurge = oldWidget.surge ?? context.read<T>();
    final currentSurge = widget.surge ?? oldSurge;
    if (!identical(oldSurge, currentSurge)) {
      _surge = currentSurge;
      _selectorValue = widget.selector(_surge.state, _surge);
      _restartEffect();
    } else if (widget.selector != oldWidget.selector) {
      _selectorValue = widget.selector(_surge.state, _surge);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surge = widget.surge ?? context.read<T>();
    if (!identical(_surge, surge)) {
      _surge = surge;
      _selectorValue = widget.selector(_surge.state, _surge);
      _restartEffect();
    }
  }

  void _startEffect() {
    _effect = Effect(() {
      if (!mounted) return;
      final state = _surge.state;

      final newSelectorValue = widget.selector(state, _surge);
      if (_selectorValue == newSelectorValue) return;

      _selectorValue = newSelectorValue;

      (context as StatefulElement).markNeedsBuild();
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
    return widget.builder(context, _selectorValue, _surge);
  }
}
