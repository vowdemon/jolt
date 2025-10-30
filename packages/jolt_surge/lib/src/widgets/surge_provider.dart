import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

class SurgeProvider<T extends Surge<dynamic>> extends InheritedProvider<T> {
  SurgeProvider({
    super.key,
    required Create<T> create,
    bool lazy = true,
    required Widget child,
  }) : super(
            create: create,
            dispose: (_, surge) => surge.dispose(),
            lazy: lazy,
            child: child);

  SurgeProvider.value({
    super.key,
    required super.value,
    bool super.lazy = true,
    super.child,
  }) : super.value();
}
