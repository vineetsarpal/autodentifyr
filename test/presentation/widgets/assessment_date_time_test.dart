import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:autodentifyr/core/theme/theme.dart';
import 'package:autodentifyr/presentation/widgets/assessment_date_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assessment controls use the cyan brand accent and lighter fields', () {
    final theme = AppTheme.darkThemeMode;
    final enabled =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    final focused =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;

    expect(theme.colorScheme.primary, AppPalette.appGreen);
    expect(enabled.borderSide.width, 1);
    expect(focused.borderSide.width, 2);
    expect(focused.borderSide.color, AppPalette.appGreen);
    expect(
      theme.inputDecorationTheme.contentPadding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  });

  testWidgets('assessment dates follow local date and time conventions', (
    tester,
  ) async {
    const timestamp = '2026-09-07T17:00:00.123456Z';
    late String presented;
    late String expected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final local = DateTime.parse(timestamp).toLocal();
            final format = MaterialLocalizations.of(context);
            expected =
                '${format.formatMediumDate(local)} at '
                '${format.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
            presented = formatAssessmentDateTime(
              context,
              DateTime.parse(timestamp),
            );
            return Text(presented);
          },
        ),
      ),
    );

    expect(presented, expected);
    expect(presented, isNot(contains('T17:00:00.123456Z')));
  });
}
