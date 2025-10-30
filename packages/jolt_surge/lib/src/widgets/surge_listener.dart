import 'package:flutter/widgets.dart';

import '../surge.dart';
import 'surge_consumer.dart';

class SurgeListener<T extends Surge<S>, S> extends SurgeConsumer<T, S> {
  SurgeListener(
      {super.key,
      required Widget child,
      required super.listener,
      super.listenWhen,
      super.surge})
      : super(builder: (context, _, __) => child);
}
