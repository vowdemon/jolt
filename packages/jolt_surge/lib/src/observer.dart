import 'shared.dart';
import 'surge.dart';

abstract class SurgeObserver {
  const SurgeObserver();

  void onCreate(Surge<dynamic> surge) {}
  void onChange(Surge<dynamic> surge, Change<dynamic> change) {}
  void onDispose(Surge<dynamic> surge) {}

  static SurgeObserver? observer;
}
