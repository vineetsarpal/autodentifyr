import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_progress.dart';
import 'package:autodentifyr/presentation/screens/assessment_workflow_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

import 'fail_next_assessment_save_repository.dart';

void main() {
  group('AssessmentWorkflowScreen', () {
    testWidgets('shows a full legacy human-entered Vehicle ID', (tester) async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(
        IntakeAssessment.create(
          id: 'assessment-legacy',
          vehicle: const Vehicle(id: 'UX-PIXEL-0914'),
          appraiserProfile: const AppraiserProfile(
            id: 'appraiser-legacy',
            displayName: 'Legacy Appraiser',
          ),
          createdAt: DateTime.utc(2026, 9, 14),
        ),
      );
      final controller = AssessmentWorkflowController(
        repository: repository,
        idGenerator: () => 'unused',
        now: () => DateTime.utc(2026, 9, 16),
      );
      Future<void> noop(BuildContext context, String id) async {}

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentWorkflowScreen(
            controller: controller,
            openEvidence: noop,
            openFindings: noop,
            openEstimate: noop,
            openSeverity: noop,
            openCompletion: noop,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UX-PIXEL-0914'), findsOneWidget);
      expect(find.text('Vehicle XEL-0914'), findsNothing);
    });

    testWidgets(
      'reuses selected Vehicle and Appraiser Profile without typing IDs',
      (tester) async {
        tester.view.physicalSize = const Size(393, 851);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = InMemoryAssessmentRepository();
        var sequence = 0;
        final controller = AssessmentWorkflowController(
          repository: repository,
          idGenerator: () => 'generated-${++sequence}',
          now: () => DateTime.utc(2026, 9, 15, sequence),
        );
        Future<void> noop(BuildContext context, String id) async {}
        await tester.pumpWidget(
          MaterialApp(
            home: AssessmentWorkflowScreen(
              controller: controller,
              openEvidence: noop,
              openFindings: noop,
              openEstimate: noop,
              openSeverity: noop,
              openCompletion: noop,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('new-assessment')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('vehicle-display-label')),
          'Blue hatchback',
        );
        await tester.enterText(
          find.byKey(const Key('appraiser-name')),
          'Alex Appraiser',
        );
        await tester.tap(find.byKey(const Key('start-assessment')));
        await tester.pumpAndSettle();
        final first = controller.state.assessments.single;
        expect(first.vehicle.id, startsWith('vehicle-'));
        expect(first.appraiserProfile.id, startsWith('appraiser-'));

        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('new-assessment')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Existing vehicle'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-assessment')));
        await tester.pumpAndSettle();
        expect(find.text('Select a Vehicle.'), findsOneWidget);
        expect(find.text('Alex Appraiser'), findsOneWidget);
        await tester.tap(find.byKey(const Key('vehicle-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Blue hatchback').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('appraiser-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alex Appraiser').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-assessment')));
        await tester.pumpAndSettle();
        final records = await repository.list();
        expect(records.length, 2);
        expect(records.map((record) => record.vehicle.id).toSet(), {
          first.vehicle.id,
        });
        expect(records.map((record) => record.appraiserProfile.id).toSet(), {
          first.appraiserProfile.id,
        });
      },
    );
    testWidgets('required errors and save failure retain assessment input', (
      tester,
    ) async {
      final repository = FailNextAssessmentSaveRepository(
        InMemoryAssessmentRepository(),
      );
      final controller = AssessmentWorkflowController(
        repository: repository,
        idGenerator: () => 'assessment-1',
        now: () => DateTime.utc(2026, 9, 9, 20),
      );
      Future<void> noop(BuildContext context, String id) async {}
      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentWorkflowScreen(
            controller: controller,
            openEvidence: noop,
            openFindings: noop,
            openEstimate: noop,
            openSeverity: noop,
            openCompletion: noop,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-assessment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-assessment')));
      await tester.pumpAndSettle();
      expect(find.text('Appraiser name is required.'), findsOneWidget);
      expect(find.text('New Intake Assessment'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('vehicle-display-label')),
        'Blue hatchback',
      );
      await tester.enterText(
        find.byKey(const Key('appraiser-name')),
        'Alex Appraiser',
      );
      repository.failNextSave = true;
      await tester.tap(find.byKey(const Key('start-assessment')));
      await tester.pumpAndSettle();
      expect(
        find.text('Device storage is temporarily unavailable.'),
        findsWidgets,
      );
      expect(find.text('New Intake Assessment'), findsOneWidget);
      expect(find.text('Blue hatchback'), findsOneWidget);

      await tester.tap(find.byKey(const Key('start-assessment')));
      await tester.pumpAndSettle();
      expect(find.text('New Intake Assessment'), findsNothing);
      expect(find.text('Blue hatchback'), findsOneWidget);
    });
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
      await tester.enterText(
        find.byKey(const Key('vehicle-display-label')),
        'Blue hatchback',
      );
      await tester.enterText(find.byKey(const Key('vehicle-vin')), 'VIN-1');
      await tester.enterText(
        find.byKey(const Key('appraiser-name')),
        'Alex Appraiser',
      );
      await tester.tap(find.byKey(const Key('start-assessment')));
      await tester.pumpAndSettle();

      expect(find.text('Blue hatchback'), findsOneWidget);
      expect(find.textContaining('Draft'), findsOneWidget);
      expect(find.byKey(const Key('open-evidence')), findsOneWidget);
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

    testWidgets(
      'Continue visits the ordered stages without returning to list',
      (tester) async {
        final visited = <AssessmentStage>[];
        final controller = AssessmentWorkflowController(
          repository: InMemoryAssessmentRepository(),
          idGenerator: () => 'assessment-guided',
          now: () => DateTime.utc(2026, 9, 15, 12),
        );
        Future<void> noop(BuildContext context, String id) async {}
        await tester.pumpWidget(
          MaterialApp(
            home: AssessmentWorkflowScreen(
              controller: controller,
              openEvidence: noop,
              openFindings: noop,
              openSeverity: noop,
              openEstimate: noop,
              openCompletion: noop,
              openGuidedStage: (context, id, stage) async {
                visited.add(stage);
                expect(id, 'assessment-guided');
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('new-assessment')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('vehicle-display-label')),
          'Blue hatchback',
        );
        await tester.enterText(
          find.byKey(const Key('appraiser-name')),
          'Alex Appraiser',
        );
        await tester.tap(find.byKey(const Key('start-assessment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('open-evidence')), findsOneWidget);
        expect(find.textContaining('0 of 5 stages ready'), findsOneWidget);
        expect(find.textContaining('Add evidence first'), findsWidgets);
        expect(
          find.textContaining('outstanding before completion'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('open-evidence')));
        await tester.pumpAndSettle();
        expect(visited, AssessmentStage.values);
        expect(find.byKey(const Key('open-evidence')), findsOneWidget);
      },
    );
  });
}
