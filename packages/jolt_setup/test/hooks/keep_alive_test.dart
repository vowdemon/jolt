import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useKeepAlive', () {
    testWidgets('keeps widget alive when wantKeepAlive is true',
        (tester) async {
      var buildCount = 0;
      var disposeCount = 0;
      ReadableNode<bool>? wantKeepAlive;

      final pageController = PageController();

      await tester.pumpWidget(MaterialApp(
        home: PageView(
          controller: pageController,
          children: [
            // Page 0: Test widget with keepAlive
            SetupBuilder(setup: (context) {
              wantKeepAlive = useSignal(true);
              useAutomaticKeepAlive.value(wantKeepAlive!);
              return () {
                buildCount++;

                return _TestPage(
                  key: const ValueKey('test-page'),
                  onDispose: () => disposeCount++,
                  child: Text('Page 0 - Build: $buildCount'),
                );
              };
            }),
            // Page 1: Another page to scroll to
            const Center(child: Text('Page 1')),
            // Page 2: Another page
            const Center(child: Text('Page 2')),
          ],
        ),
      ));

      await tester.pumpAndSettle();
      final initialBuildCount = buildCount;
      expect(initialBuildCount, greaterThan(0),
          reason: 'Widget should build initially');
      expect(disposeCount, 0,
          reason: 'Widget should not be disposed initially');

      // Scroll to page 1 - widget should still be kept alive
      pageController.jumpToPage(1);
      await tester.pumpAndSettle();

      // Widget should still be kept alive (not disposed)
      expect(disposeCount, 0,
          reason: 'Widget should be kept alive when wantKeepAlive is true');

      // Scroll back to page 0
      pageController.jumpToPage(0);
      await tester.pumpAndSettle();

      // Widget should still not be disposed (kept alive)
      expect(disposeCount, 0,
          reason:
              'Widget should still not be disposed when wantKeepAlive is true');
    });

    testWidgets('does not keep widget alive when wantKeepAlive is false',
        (tester) async {
      var buildCount = 0;
      var disposeCount = 0;
      ReadableNode<bool>? wantKeepAlive;

      final pageController = PageController();

      await tester.pumpWidget(MaterialApp(
        home: PageView(
          controller: pageController,
          children: [
            // Page 0: Test widget without keepAlive
            SetupBuilder(setup: (context) {
              wantKeepAlive = useSignal(false);
              useAutomaticKeepAlive.value(wantKeepAlive!);
              return () {
                buildCount++;

                return _TestPage(
                  key: const ValueKey('test-page'),
                  onDispose: () => disposeCount++,
                  child: Text('Page 0 - Build: $buildCount'),
                );
              };
            }),
            // Page 1: Another page to scroll to
            const Center(child: Text('Page 1')),
            // Page 2: Another page
            const Center(child: Text('Page 2')),
          ],
        ),
      ));

      await tester.pumpAndSettle();
      final initialBuildCount = buildCount;
      expect(initialBuildCount, greaterThan(0),
          reason: 'Widget should build initially');
      expect(disposeCount, 0,
          reason: 'Widget should not be disposed initially');

      // Scroll to page 1 - widget may be disposed (not kept alive)
      pageController.jumpToPage(1);
      await tester.pumpAndSettle();

      // Widget may be disposed when wantKeepAlive is false
      // Note: Flutter's PageView may or may not dispose widgets immediately,
      // but with keepAlive=false, it's allowed to dispose
      // We verify that keepAlive is not preventing disposal

      // Scroll back to page 0
      pageController.jumpToPage(0);
      await tester.pumpAndSettle();

      // When wantKeepAlive is false, widget may be disposed when off-screen
      // We verify that keepAlive is not preventing disposal
      // (disposeCount may be 0 or 1 depending on Flutter's behavior)
      expect(
        disposeCount,
        greaterThan(0),
      );
    });

    testWidgets('releases keepalive when transitioning from true to false',
        (tester) async {
      var buildCount = 0;
      var disposeCount = 0;
      final wantKeepAlive = Signal(true);

      final pageController = PageController();

      await tester.pumpWidget(MaterialApp(
        home: PageView(
          controller: pageController,
          children: [
            // Page 0: Test widget with keepAlive initially true
            SetupBuilder(setup: (context) {
              useAutomaticKeepAlive.value(wantKeepAlive);
              return () {
                buildCount++;

                return _TestPage(
                  key: const ValueKey('test-page'),
                  onDispose: () => disposeCount++,
                  child: Text('Page 0 - Build: $buildCount'),
                );
              };
            }),
            // Page 1: Another page to scroll to
            const Center(child: Text('Page 1')),
            // Page 2: Another page
            const Center(child: Text('Page 2')),
          ],
        ),
      ));

      await tester.pumpAndSettle();
      final initialBuildCount = buildCount;
      expect(initialBuildCount, greaterThan(0),
          reason: 'Widget should build initially');
      expect(disposeCount, 0,
          reason: 'Widget should not be disposed initially');
      expect(wantKeepAlive.value, isTrue,
          reason: 'wantKeepAlive should be true initially');

      pageController.jumpToPage(1);
      await tester.pumpAndSettle();

      final disposeCountWhenTrue = disposeCount;
      expect(disposeCountWhenTrue, 0,
          reason: 'Widget should be kept alive when wantKeepAlive is true');

      wantKeepAlive.value = false;
      wantKeepAlive.value = true;
      wantKeepAlive.value = false;
      await tester.pumpAndSettle();

      pageController.jumpToPage(2);
      await tester.pumpAndSettle();

      final disposeCountWhenFalse = disposeCount;
      pageController.jumpToPage(1);
      await tester.pumpAndSettle();
      pageController.jumpToPage(2);
      await tester.pumpAndSettle();
      pageController.jumpToPage(0);
      await tester.pumpAndSettle();
      pageController.jumpToPage(2);
      await tester.pumpAndSettle();

      expect(disposeCountWhenTrue, 0,
          reason: 'Widget should not be disposed when wantKeepAlive is true');
      expect(disposeCountWhenFalse, greaterThan(disposeCountWhenTrue),
          reason: 'Widget should be disposed when wantKeepAlive is false');
    });

    testWidgets('useAutomaticKeepAlive.call keeps widget alive when true',
        (tester) async {
      var disposeCount = 0;

      final pageController = PageController();

      await tester.pumpWidget(MaterialApp(
        home: PageView(
          controller: pageController,
          children: [
            // Page 0: Test widget with keepAlive using .call(true)
            SetupBuilder(setup: (context) {
              useAutomaticKeepAlive(true);
              return () {
                return _TestPage(
                  key: const ValueKey('test-page'),
                  onDispose: () => disposeCount++,
                  child: const Text('Page 0'),
                );
              };
            }),
            // Page 1: Another page to scroll to
            const Center(child: Text('Page 1')),
          ],
        ),
      ));

      await tester.pumpAndSettle();
      expect(disposeCount, 0,
          reason: 'Widget should not be disposed initially');

      // Scroll to page 1 - widget should still be kept alive
      pageController.jumpToPage(1);
      await tester.pumpAndSettle();

      // Widget should still be kept alive (not disposed)
      expect(disposeCount, 0,
          reason:
              'Widget should be kept alive when useAutomaticKeepAlive.call(true)');
    });

    testWidgets(
        'useAutomaticKeepAlive.call does not keep widget alive when false',
        (tester) async {
      var disposeCount = 0;

      final pageController = PageController();

      await tester.pumpWidget(MaterialApp(
        home: PageView(
          controller: pageController,
          children: [
            // Page 0: Test widget without keepAlive using .call(false)
            SetupBuilder(setup: (context) {
              useAutomaticKeepAlive(false);
              return () {
                return _TestPage(
                  key: const ValueKey('test-page'),
                  onDispose: () => disposeCount++,
                  child: const Text('Page 0'),
                );
              };
            }),
            // Page 1: Another page to scroll to
            const Center(child: Text('Page 1')),
          ],
        ),
      ));

      await tester.pumpAndSettle();
      expect(disposeCount, 0,
          reason: 'Widget should not be disposed initially');

      // Scroll to page 1 - widget may be disposed (not kept alive)
      pageController.jumpToPage(1);
      await tester.pumpAndSettle();

      // When wantKeepAlive is false, widget may be disposed when off-screen
      expect(disposeCount, greaterThan(0),
          reason:
              'Widget should be disposed when useAutomaticKeepAlive.call(false)');
    });
  });
}

/// Helper widget that tracks dispose calls
class _TestPage extends StatefulWidget {
  const _TestPage({
    super.key,
    required this.onDispose,
    required this.child,
  });

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<_TestPage> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
