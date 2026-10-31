import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_akimi/core/theme.dart';
import 'package:souq_akimi/models/enums.dart';
import 'package:souq_akimi/widgets/common.dart';

void main() {
  group('AppTheme', () {
    test('builds a Material 3 light and dark scheme', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.seed, const Color(0xFF0B5D4B));
    });
  });

  group('StatusChip', () {
    test('renders its label', () {
      expect(
        const StatusChip(label: 'Held', color: Colors.amber).label,
        'Held',
      );
    });

    test('order statuses carry their own colour', () {
      final chip = StatusChip.order(OrderStatus.delivered);
      expect(chip.label, OrderStatus.delivered.label);
      expect(chip.dense, isFalse);
      expect(
        StatusChip.order(OrderStatus.delivered, dense: true).dense,
        isTrue,
      );
    });
  });

  group('EmptyState', () {
    testWidgets('shows a title, message and its action', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing yet',
              message: 'When something arrives it appears here.',
              action: FilledButton(
                onPressed: () => tapped = true,
                child: const Text('Do it'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(
        find.text('When something arrives it appears here.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

      await tester.tap(find.text('Do it'));
      expect(tapped, isTrue);
    });

    testWidgets('omits the message when none is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(icon: Icons.inbox_outlined, title: 'Bare'),
          ),
        ),
      );
      expect(find.text('Bare'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget); // title only
    });
  });

  group('SectionHeader', () {
    testWidgets('renders a title and an optional trailing widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SectionHeader(
                  title: 'Hand-overs',
                  trailing: Text('One per seller'),
                ),
                SectionHeader(title: 'Items'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Hand-overs'), findsOneWidget);
      expect(find.text('One per seller'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
    });
  });
}
