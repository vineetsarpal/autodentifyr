import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_completion_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Appraiser confirms No Visible Damage and sees revision one', (
    tester,
  ) async {
    final repository = InMemoryAssessmentRepository();
    final assessment =
        IntakeAssessment.create(
              id: 'assessment-1',
              vehicle: const Vehicle(id: 'vehicle-1', licencePlate: 'ABC123'),
              appraiserProfile: const AppraiserProfile(
                id: 'appraiser-1',
                displayName: 'Alex Appraiser',
              ),
              createdAt: DateTime.utc(2026, 9, 8, 19),
            )
            .acceptCapture(
              Capture(
                id: 'capture-1',
                source: CaptureSource.camera,
                localPath: '/evidence/capture-1.jpg',
                acceptedByProfileId: 'appraiser-1',
                acceptedAt: DateTime.utc(2026, 9, 8, 19, 1),
              ),
            )
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
    await repository.save(assessment);
    final controller = AssessmentCompletionController(
      assessmentId: assessment.id,
      repository: repository,
      idGenerator: () => 'revision-1',
      now: () => DateTime.utc(2026, 9, 8, 20),
    );
    final artifacts = <AssessmentReportArtifact>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentCompletionScreen(
          controller: controller,
          onReportArtifact: (artifact) async => artifacts.add(artifact),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completion Gate'), findsOneWidget);
    expect(
      find.text('Confirm that no supported visible exterior damage was found.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('complete-assessment')))
          .onPressed,
      isNull,
    );
    expect(find.text('Review before completing'), findsOneWidget);
    expect(
      find.text('Only visible exterior damage was assessed.'),
      findsOneWidget,
    );
    expect(find.text('No additional limitations recorded.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-no-visible-damage')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('complete-assessment')));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Preliminary Damage Assessment'), findsOneWidget);
    expect(find.text('Revision 1'), findsWidgets);
    expect(find.text('No Visible Damage Outcome'), findsOneWidget);
    expect(find.text('Revision ID: revision-1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('render-pdf-report')),
      400,
    );
    await tester.tap(find.byKey(const Key('render-pdf-report')));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(AssessmentCompletionScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('render-shared-image-report')),
      200,
    );
    await tester.tap(find.byKey(const Key('render-shared-image-report')));
    await tester.pumpAndSettle();

    expect(artifacts, hasLength(2));
    expect(artifacts.map((artifact) => artifact.revisionId).toSet(), {
      'revision-1',
    });
    expect(artifacts.map((artifact) => artifact.canonicalText).toSet(), {
      artifacts.first.canonicalText,
    });
    expect(artifacts.map((artifact) => artifact.mimeType), [
      'application/pdf',
      'image/png',
    ]);
  });
}
