import 'dart:async';

void main() {
  final sc = StreamController<int>.broadcast(
    onListen: () {
      print('onListen');
    },
    onCancel: () {
      print('onCancel');
    },
  );
  final a = sc.stream.listen((value) {
    print('listen: $value');
  });
  final b = sc.stream.listen((value) {
    print('listen: $value');
  });
  sc.add(1);
  sc.add(2);

  // a.cancel();
  // b.cancel();
}
