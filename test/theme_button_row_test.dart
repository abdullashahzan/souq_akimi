import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/core/theme.dart';

/// Regression guard for a real crash: the theme used to set
/// `minimumSize: Size.fromHeight(52)`, which is an *infinite* minimum width.
/// A button stretched by a Column is fine, but as soon as one sits inside a
/// Row it demands infinite width and the whole subtree fails to lay out —
/// which is exactly what blanked the hand-over card on the order screen.
void main() {
  Future<void> pumpRow(WidgetTester tester, {required bool outlined}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              if (outlined) ...[
                FilledButton(
                  onPressed: () {},
                  child: const Text('Show hand-over code'),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Refund')),
              ] else ...[
                OutlinedButton(onPressed: () {}, child: const Text('Accept')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Decline'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('filled and outlined buttons sit side by side in a Row', (
    tester,
  ) async {
    await pumpRow(tester, outlined: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tonal and outlined buttons sit side by side in a Row', (
    tester,
  ) async {
    await pumpRow(tester, outlined: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the theme minimum width is finite, never infinite', (
    tester,
  ) async {
    await pumpRow(tester, outlined: true);
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.width.isFinite, isTrue);
    expect(size.height, greaterThanOrEqualTo(52));
  });
}
