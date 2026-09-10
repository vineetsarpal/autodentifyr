import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_workflow_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

void main() {
  group('AssessmentWorkflowScreen', () {
    testWidgets('creates a Draft and opens every assessment stage', (
      tester,
    ) async {
      final openedStages = <String>[];
      final controller = AssessmentWorkflowController(
        repository: InMemoryAssessmentRepository(),
        idGenerator: () => 'assessment-1',
        now: () => DateTime.utc(2026, 9, 9, 20),
      );
      Future<void> openStage(
        BuildContext context,
        String assessmentId,
        String stage,
      ) async {
        openedStages.add('$stage:$assessmentId');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentWorkflowScreen(
            controller: controller,
            openEvidence: (context, id) => openStage(context, id, 'evidence'),
            openFindings: (context, id) => openStage(context, id, 'findings'),
            openEstimate: (context, id) => openStage(context, id, 'estimate'),
            openSeverity: (context, id) => openStage(context, id, 'severity'),
            openCompletion: (context, id) =>
                openStage(context, id, 'completion'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-assessment')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vehicle-id')), 'vehicle-1');
      await tester.enterText(find.byKey(const Key('vehicle-vin')), 'VIN-1');
      await tester.enterText(
        find.byKey(const Key('appraiser-id')),
        'appraiser-1',
      );
      await tester.enterText(
        find.byKey(const Key('appraiser-name')),
        'Alex Appraiser',
      );
      await tester.tap(find.byKey(const Key('start-assessment')));
      await tester.pumpAndSettle();

      expect(find.text('vehicle-1'), findsOneWidget);
      expect(find.textContaining('Draft'), findsOneWidget);

      await tester.tap(find.byKey(const Key('assessment-assessment-1')));
      await tester.pumpAndSettle();
      for (final entry in const [
        ('open-evidence', 'evidence'),
        ('open-findings', 'findings'),
        ('open-estimate', 'estimate'),
        ('open-severity', 'severity'),
        ('open-completion', 'completion'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(entry.$1)));
        await tester.tap(find.byKey(Key(entry.$1)));
        await tester.pumpAndSettle();
        expect(openedStages, contains('${entry.$2}:assessment-1'));
      }
    });
  });
}
