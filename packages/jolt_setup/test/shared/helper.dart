import 'package:flutter/material.dart';

typedef ReparentableTargetBuilder = Widget Function(GlobalKey key);
typedef ReparentableWrapper = Widget Function(Widget child);

Widget buildReparentableHost({
  required GlobalKey key,
  required bool placeInFirstSlot,
  required ReparentableTargetBuilder buildTarget,
  ReparentableWrapper? wrapFirstSlot,
  ReparentableWrapper? wrapSecondSlot,
  ReparentableWrapper? wrapHome,
}) {
  Widget firstChild = placeInFirstSlot ? buildTarget(key) : const SizedBox();
  Widget secondChild = placeInFirstSlot ? const SizedBox() : buildTarget(key);

  if (wrapFirstSlot != null) {
    firstChild = wrapFirstSlot(firstChild);
  }
  if (wrapSecondSlot != null) {
    secondChild = wrapSecondSlot(secondChild);
  }

  Widget home = Row(children: [
    Expanded(child: firstChild),
    Expanded(child: secondChild),
  ]);

  if (wrapHome != null) {
    home = wrapHome(home);
  }

  return MaterialApp(home: home);
}
