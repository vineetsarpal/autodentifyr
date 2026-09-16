import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_completion_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:autodentifyr/services/assessment_report_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prepared PDF exposes native open, Files, and share actions', (
    tester,
  ) async {
    final repository = InMemoryAssessmentRepository();
    final assessment = _completedNoDamageAssessment();
    await repository.save(assessment);
    final delivery = _FakeReportDelivery();
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentCompletionScreen(
          controller: AssessmentCompletionController(
            assessmentId: assessment.id,
            repository: repository,
            idGenerator: () => 'unused',
            now: DateTime.now,
          ),
          reportDelivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('render-pdf-report')),
      400,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('render-pdf-report')));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(AssessmentCompletionScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(delivery.prepared!.artifact.revisionId, 'revision-1');
    expect(delivery.prepared!.artifact.mimeType, 'application/pdf');
    expect(find.text('Ready: revision-1.pdf'), findsOneWidget);
    expect(find.byKey(const Key('open-prepared-report')), findsOneWidget);
    expect(find.byKey(const Key('save-prepared-report')), findsOneWidget);
    expect(find.byKey(const Key('share-prepared-report')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('save-prepared-report')),
      200,
    );
    delivery.nextResult = ReportDeliveryResult.canceled;
    await tester.tap(find.byKey(const Key('save-prepared-report')));
    await tester.pumpAndSettle();
    expect(delivery.savedFileName, 'revision-1.pdf');
    expect(find.textContaining('Save canceled.'), findsOneWidget);
    expect(find.byKey(const Key('open-prepared-report')), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(AssessmentCompletionScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    delivery.nextResult = ReportDeliveryResult.completed;
    await tester.tap(find.byKey(const Key('open-prepared-report')));
    await tester.pumpAndSettle();
    expect(delivery.openedFileName, 'revision-1.pdf');
  });

  testWidgets('PNG preview and share failure keep the prepared revision', (
    tester,
  ) async {
    final repository = InMemoryAssessmentRepository();
    final assessment = _completedNoDamageAssessment();
    await repository.save(assessment);
    final delivery = _FakeReportDelivery();
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentCompletionScreen(
          controller: AssessmentCompletionController(
            assessmentId: assessment.id,
            repository: repository,
            idGenerator: () => 'unused',
            now: DateTime.now,
          ),
          reportDelivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('render-shared-image-report')),
      400,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('render-shared-image-report')));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(AssessmentCompletionScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(delivery.prepared!.artifact.mimeType, 'image/png');
    expect(find.byKey(const Key('shared-image-preview')), findsOneWidget);
    expect(find.text('Ready: revision-1.png'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('share-prepared-report')),
      200,
    );
    delivery.failShare = true;
    await tester.tap(find.byKey(const Key('share-prepared-report')));
    await tester.pumpAndSettle();
    expect(delivery.sharedFileName, 'revision-1.png');
    expect(find.textContaining('Report action failed:'), findsOneWidget);
    expect(find.byKey(const Key('save-prepared-report')), findsOneWidget);
  });

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

    expect(find.text('Appraiser: Alex Appraiser'), findsOneWidget);
    expect(find.byKey(const Key('summary-photo-capture-1')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Assumption: Only visible exterior damage was assessed.'),
      300,
    );
    expect(
      find.text('Assumption: Only visible exterior damage was assessed.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Completion Gate'), 300);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
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
    expect(find.text('No additional limitations recorded.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-no-visible-damage')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('complete-assessment')));
    await tester.pumpAndSettle();

    expect(
      controller.state.assessment!.status,
      IntakeAssessmentStatus.completed,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Revision 1'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('No supported visible exterior damage.'),
      300,
    );
    expect(find.text('No supported visible exterior damage.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('report-audit-details')),
      300,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-audit-details')));
    await tester.pumpAndSettle();
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

  testWidgets('voided revision shows its marker and reason above the report', (
    tester,
  ) async {
    final repository = InMemoryAssessmentRepository();
    final assessment = _completedNoDamageAssessment().voidAssessment(
      voidedAt: DateTime.utc(2026, 9, 14, 22),
      reason: 'Duplicate intake.',
    );
    await repository.save(assessment);
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentCompletionScreen(
          controller: AssessmentCompletionController(
            assessmentId: assessment.id,
            repository: repository,
            idGenerator: () => 'unused',
            now: DateTime.now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('VOIDED'), 300);

    expect(find.text('VOIDED'), findsOneWidget);
    expect(find.text('Reason: Duplicate intake.'), findsOneWidget);
  });

  for (final save in [true, false]) {
    for (final keyboardShown in [true, false]) {
      testWidgets(
        '${save ? 'save' : 'cancel'} limitations with keyboard ${keyboardShown ? 'shown' : 'hidden'} keeps the dialog alive through exit',
        (tester) async {
          final repository = InMemoryAssessmentRepository();
          final assessment = _draftAssessment().recordLimitations(
            limitations: const ['Existing limitation.'],
            reviewedAt: DateTime.utc(2026, 9, 14, 20, 1),
          );
          await repository.save(assessment);
          final controller = AssessmentCompletionController(
            assessmentId: assessment.id,
            repository: repository,
            idGenerator: () => 'unused-revision-id',
            now: () => DateTime.utc(2026, 9, 14, 21),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: AssessmentCompletionScreen(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('edit-assessment-limitations')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('assessment-limitations')),
            ' Rear bumper partly obscured. \n\n Second note. ',
          );
          if (!keyboardShown) {
            tester.testTextInput.hide();
            await tester.pump();
          }

          await tester.tap(
            find.byKey(
              Key(
                save
                    ? 'save-assessment-limitations'
                    : 'cancel-assessment-limitations',
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            (await repository.findById(assessment.id))!.limitations,
            save
                ? ['Rear bumper partly obscured.', 'Second note.']
                : ['Existing limitation.'],
          );
          if (save) {
            final reloaded = AssessmentCompletionController(
              assessmentId: assessment.id,
              repository: repository,
              idGenerator: () => 'unused-revision-id',
              now: () => DateTime.utc(2026, 9, 14, 22),
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              MaterialApp(
                home: AssessmentCompletionScreen(controller: reloaded),
              ),
            );
            await tester.pumpAndSettle();
            expect(reloaded.state.assessment!.limitations, [
              'Rear bumper partly obscured.',
              'Second note.',
            ]);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final confirm in [true, false]) {
    for (final keyboardShown in [true, false]) {
      testWidgets(
        '${confirm ? 'confirming' : 'canceling'} void reason with keyboard ${keyboardShown ? 'shown' : 'hidden'} keeps the dialog alive through exit',
        (tester) async {
          final repository = InMemoryAssessmentRepository();
          final assessment = _draftAssessment();
          await repository.save(assessment);
          final controller = AssessmentCompletionController(
            assessmentId: assessment.id,
            repository: repository,
            idGenerator: () => 'unused-revision-id',
            now: () => DateTime.utc(2026, 9, 14, 21),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: AssessmentCompletionScreen(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const Key('void-assessment')),
            200,
          );
          await tester.tap(find.byKey(const Key('void-assessment')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('void-reason')),
            'Duplicate intake record.',
          );
          if (!keyboardShown) {
            tester.testTextInput.hide();
            await tester.pump();
          }
          await tester.tap(
            find.byKey(
              Key(
                confirm ? 'confirm-void-assessment' : 'cancel-void-assessment',
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final stored = (await repository.findById(assessment.id))!;
          expect(
            stored.status,
            confirm
                ? IntakeAssessmentStatus.voided
                : IntakeAssessmentStatus.draft,
          );
          expect(
            stored.voidRecord?.reason,
            confirm ? 'Duplicate intake record.' : null,
          );
        },
      );
    }
  }
}

IntakeAssessment _draftAssessment() => IntakeAssessment.create(
  id: 'assessment-dialog-lifecycle',
  vehicle: const Vehicle(id: 'vehicle-dialog-lifecycle'),
  appraiserProfile: const AppraiserProfile(
    id: 'appraiser-1',
    displayName: 'Alex Appraiser',
  ),
  createdAt: DateTime.utc(2026, 9, 14, 20),
);

IntakeAssessment _completedNoDamageAssessment() => _draftAssessment()
    .acceptCapture(
      Capture(
        id: 'capture-1',
        source: CaptureSource.camera,
        localPath: '/evidence/capture-1.jpg',
        acceptedByProfileId: 'appraiser-1',
        acceptedAt: DateTime.utc(2026, 9, 14, 20, 1),
      ),
    )
    .recordEstimate(
      AssessmentEstimate(
        operations: const [],
        assumptions: const ['Visible exterior damage only.'],
        reviewedByProfileId: 'appraiser-1',
        reviewedAt: DateTime.utc(2026, 9, 14, 20, 2),
        sourceVersion: 'unsupported-pricing-v1',
      ),
    )
    .complete(
      revisionId: 'revision-1',
      completedAt: DateTime.utc(2026, 9, 14, 21),
      noVisibleDamageConfirmed: true,
    );

class _FakeReportDelivery implements AssessmentReportDelivery {
  PreparedAssessmentReport? prepared;
  String? openedFileName;
  String? savedFileName;
  String? sharedFileName;
  ReportDeliveryResult nextResult = ReportDeliveryResult.completed;
  bool failShare = false;

  @override
  Future<PreparedAssessmentReport> prepare(
    AssessmentReportArtifact artifact,
  ) async {
    prepared = PreparedAssessmentReport(
      artifact: artifact,
      file: File(
        '/private/revision-1.${artifact.mimeType == 'application/pdf' ? 'pdf' : 'png'}',
      ),
    );
    return prepared!;
  }

  @override
  Future<ReportDeliveryResult> open(PreparedAssessmentReport report) async {
    openedFileName = report.fileName;
    return nextResult;
  }

  @override
  Future<ReportDeliveryResult> saveToFiles(
    PreparedAssessmentReport report,
  ) async {
    savedFileName = report.fileName;
    return nextResult;
  }

  @override
  Future<ReportDeliveryResult> share(
    PreparedAssessmentReport report, {
    required Rect sharePositionOrigin,
  }) async {
    sharedFileName = report.fileName;
    if (failShare) throw StateError('Share UI unavailable');
    return nextResult;
  }
}
