import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_log/models/set_entry.dart';
import 'package:gym_log/theme/app_theme.dart';
import 'package:gym_log/widgets/set_input_row.dart';

void main() {
  late int removed;

  Future<void> pumpRow(WidgetTester tester, {bool isLastSet = false}) async {
    removed = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: ListView(
          children: [
            SetInputRow(
              set: const SetEntry(setNumber: 1, weightInput: 40, weightTotal: 100, reps: 5),
              index: 0,
              previous: const SetEntry(setNumber: 1, weightInput: 40, weightTotal: 100, reps: 5),
              isLastSet: isLastSet,
              equipmentType: 'barbell',
              barWeightKg: 20,
              onWeightChanged: (_) {},
              onRepsChanged: (_) {},
              onWarmupToggled: () {},
              onDropsetToggled: () {},
              onRemove: () => removed++,
              onUsePrevious: () {},
            ),
          ],
        ),
      ),
    ));
  }

  Future<void> swipeLeftFrom(WidgetTester tester, Finder start) async {
    await tester.drag(start, const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('swipe left starting on the weight field removes the set', (tester) async {
    await pumpRow(tester);
    await swipeLeftFrom(tester, find.byType(TextField).first);
    expect(removed, 1);
  });

  testWidgets('swipe left starting on the reps field removes the set', (tester) async {
    await pumpRow(tester);
    await swipeLeftFrom(tester, find.byType(TextField).last);
    expect(removed, 1);
  });

  testWidgets('swipe left starting on the previous value removes the set', (tester) async {
    await pumpRow(tester);
    await swipeLeftFrom(tester, find.text('100 × 5'));
    expect(removed, 1);
  });

  testWidgets('tapping a field focuses it and selects the value for overwrite', (tester) async {
    await pumpRow(tester);
    await tester.tap(find.byType(TextField).last);
    await tester.pump();

    final reps = tester.widget<TextField>(find.byType(TextField).last);
    expect(reps.focusNode!.hasFocus, isTrue);
    expect(reps.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 1));

    await tester.enterText(find.byType(TextField).last, '8');
    expect(reps.controller!.text, '8');
  });

  testWidgets('the only set cannot be swiped away', (tester) async {
    await pumpRow(tester, isLastSet: true);
    await swipeLeftFrom(tester, find.text('100 × 5'));
    expect(removed, 0);
  });
}
