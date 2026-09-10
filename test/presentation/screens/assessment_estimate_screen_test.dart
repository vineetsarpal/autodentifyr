import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_estimate_screen.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentEstimateScreen', () {
    testWidgets(
      'Draft Estimate deduplicates shared work and labels unavailable pricing',
      (tester) async {
        final harness = await _Harness.create(const [
          SuggestedRepairOperation(
            operationId: 'repair-door',
            findingId: 'finding-1',
            description: 'Repair left-front door',
          ),
          SuggestedRepairOperation(
            operationId: 'repair-door',
            findingId: 'finding-2',
            description: 'Repair left-front door',
          ),
        ]);
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('recalculate-estimate')));
        await tester.pumpAndSettle();

        expect(find.text('Draft Estimate'), findsOneWidget);
        expect(find.text('Partial Estimate'), findsOneWidget);
        expect(find.text('Repair left-front door'), findsOneWidget);
        expect(find.text('Supports 2 Confirmed Findings'), findsOneWidget);
        expect(find.text('Pricing unavailable'), findsOneWidget);
        expect(find.text('Known subtotal unavailable'), findsOneWidget);
        expect(find.textContaining(r'$0'), findsNothing);
      },
    );

    testWidgets('Appraiser overrides an operation with recorded provenance', (
      tester,
    ) async {
      final harness = await _Harness.create(const [
        SuggestedRepairOperation(
          operationId: 'repair-door',
          findingId: 'finding-1',
          description: 'Repair left-front door',
        ),
      ]);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recalculate-estimate')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('override-repair-door')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('operation-description')),
        'Repair and refinish left-front door',
      );
      await tester.enterText(find.byKey(const Key('minimum-cents')), '10000');
      await tester.enterText(find.byKey(const Key('maximum-cents')), '20000');
      await tester.enterText(find.byKey(const Key('currency')), 'CAD');
      await tester.enterText(
        find.byKey(const Key('pricing-source-version')),
        'appraiser-source-v1',
      );
      await tester.enterText(
        find.byKey(const Key('override-reason')),
        'Supported by the Appraiser shop range.',
      );
      await tester.tap(find.byKey(const Key('submit-estimate-action')));
      await tester.pumpAndSettle();

      expect(find.text('Repair and refinish left-front door'), findsOneWidget);
      expect(find.text('CAD 100.00–200.00'), findsOneWidget);
      expect(find.text('1 recorded override'), findsOneWidget);
      final override =
          harness.controller.state.assessment!.estimate!.overrides.single;
      expect(override.original.hasPricing, isFalse);
      expect(override.authorProfileId, 'appraiser-1');
      expect(override.reason, 'Supported by the Appraiser shop range.');
    });

    testWidgets(
      'Appraiser edits assumptions and acknowledges a Partial Estimate',
      (tester) async {
        final harness = await _Harness.create(const [
          SuggestedRepairOperation(
            operationId: 'repair-door',
            findingId: 'finding-1',
            description: 'Repair left-front door',
          ),
        ]);
        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('recalculate-estimate')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('edit-estimate-assumptions')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('estimate-assumptions')),
          'Pricing awaits an authorized local source.\nTax is excluded.',
        );
        await tester.tap(find.byKey(const Key('submit-estimate-action')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Pricing awaits an authorized local source.'),
          findsOneWidget,
        );
        expect(find.textContaining('Tax is excluded.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('acknowledge-partial-estimate')));
        await tester.pumpAndSettle();

        expect(find.text('Missing pricing acknowledged'), findsOneWidget);
        final estimate = harness.controller.state.assessment!.estimate!;
        expect(estimate.missingPricingAcknowledgedByProfileId, 'appraiser-1');
        expect(
          estimate.missingPricingAcknowledgedAt,
          DateTime.utc(2026, 9, 7, 13),
        );
      },
    );
  });
}

class _Harness {
  const _Harness(this.controller);

  final AssessmentEstimateController controller;

  Widget get widget =>
      MaterialApp(home: AssessmentEstimateScreen(controller: controller));

  static Future<_Harness> create(
    List<SuggestedRepairOperation> suggestions,
  ) async {
    final repository = InMemoryAssessmentRepository();
    await repository.save(_assessment());
    return _Harness(
      AssessmentEstimateController(
        assessmentId: 'assessment-1',
        repository: repository,
        source: _Source(suggestions),
        idGenerator: () => 'override-1',
        now: () => DateTime.utc(2026, 9, 7, 13),
      ),
    );
  }
}

class _Source implements AssessmentEstimateSource {
  const _Source(this.suggestions);

  final List<SuggestedRepairOperation> suggestions;

  @override
  String get version => 'test-source-v1';

  @override
  bool get supportsNumericPricing => true;

  @override
  Future<List<SuggestedRepairOperation>> suggestOperations(
    List<DamageFinding> confirmedFindings,
  ) async => suggestions;
}

IntakeAssessment _assessment() {
  var assessment =
      IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 7, 12),
      ).acceptCapture(
        Capture(
          id: 'capture-1',
          source: CaptureSource.camera,
          localPath: '/evidence/capture-1.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 7, 12, 1),
        ),
      );
  for (final id in ['finding-1', 'finding-2']) {
    assessment = assessment.addFinding(
      DamageFinding.manual(
        id: id,
        vehicleComponent: 'left-front door',
        damageType: id == 'finding-1' ? 'dent' : 'scratch',
        supportingCaptureIds: const ['capture-1'],
        evidenceNote: 'Visible damage supported by the Capture.',
      ),
    );
  }
  return assessment;
}
