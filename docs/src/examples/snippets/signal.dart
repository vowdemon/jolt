import 'package:jolt/jolt.dart';

void main() {
  // 创建一个信号
  final count = Signal(0);

  // 订阅信号的变化
  Effect(() {
    print('Count: ${count.value}');
  });

  // 修改信号的值
  count.value = 5; // 输出: "Count: 5"
}
