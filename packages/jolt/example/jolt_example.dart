import "package:jolt/jolt.dart";

void main() {
  final a = Signal(1);
  final b = Computed(() => a.value + 1);

  Effect(() {
    print(b.value);
  });

  a.value = 2;
}
