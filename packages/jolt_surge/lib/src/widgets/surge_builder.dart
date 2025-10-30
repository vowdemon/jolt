import '../surge.dart';
import 'surge_consumer.dart';

class SurgeBuilder<T extends Surge<S>, S> extends SurgeConsumer<T, S> {
  const SurgeBuilder(
      {super.key, required super.builder, super.surge, super.buildWhen});
}
