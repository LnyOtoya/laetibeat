import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

void main() {
  testWidgets('shifted mini player controls remain tappable', (
    WidgetTester tester,
  ) async {
    final scrollState = M3EFloatingToolbarState()
      ..offsetLimit = -80
      ..offset = -80;
    var pausePressed = false;

    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomOverlay(
              navigationBar: const SizedBox(height: 80),
              navigationBarHeight: 80,
              miniPlayer: Center(
                child: TextButton(
                  key: const ValueKey<String>('mini-pause'),
                  onPressed: () => pausePressed = true,
                  child: const Text('Pause'),
                ),
              ),
              miniVisible: true,
              miniPlayerHeight: 96,
              navBarScrollState: scrollState,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mini-pause')));

    expect(pausePressed, isTrue);
  });
}
