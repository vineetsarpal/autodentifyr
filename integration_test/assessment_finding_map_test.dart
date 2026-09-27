import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_finding_review_screen.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'top map reflects findings while component selection stays local',
    (tester) async {
      final repository = InMemoryAssessmentRepository();
      var assessment = IntakeAssessment.create(
        id: 'map-assessment',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 25, 12),
      );
      assessment = assessment.acceptCapture(
        Capture(
          id: 'capture-1',
          source: CaptureSource.camera,
          localPath: '/evidence/capture-1.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 25, 12, 1),
        ),
      );
      assessment = assessment.recordObservation(
        const DamageObservation(
          id: 'observation-1',
          captureId: 'capture-1',
          rawClass: 'dent',
          confidence: .8,
          bounds: ObservationBounds(left: .1, top: .2, width: .3, height: .4),
          modelIdentifier: 'integration-model',
        ),
      );
      assessment = assessment.addFinding(
        DamageFinding.proposed(
          id: 'finding-1',
          observationIds: const ['observation-1'],
          supportingCaptureIds: const ['capture-1'],
          suggestedVehicleComponentId: VehicleComponentId.hood,
          suggestedDamageType: 'dent',
        ),
      );
      await repository.save(assessment);
      final controller = AssessmentFindingReviewController(
        assessmentId: assessment.id,
        repository: repository,
        idGenerator: () => 'generated-finding',
        now: () => DateTime.utc(2026, 9, 25, 12, 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentFindingReviewScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicle condition'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-vehicle-map')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Browse components'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('top-map-component-search')),
        'hood',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('top-map-component-hood')));
      await tester.pumpAndSettle();
      expect(find.textContaining('80% confidence'), findsOneWidget);
      expect(find.textContaining('Proposed'), findsWidgets);
      expect(find.text('Use component anyway'), findsOneWidget);

      await tester.tap(find.byTooltip('Browse components'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('top-map-component-search')),
        'roof',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('top-map-component-roof')));
      await tester.pumpAndSettle();
      expect(
        find.text('No active findings on this component.'),
        findsOneWidget,
      );
      expect(find.text('Use Roof'), findsOneWidget);
      await tester.tap(find.text('Use Roof'));
      await tester.pumpAndSettle();
      expect(find.text('Vehicle condition'), findsOneWidget);

      final persisted = await repository.findById(assessment.id);
      expect(persisted, isNotNull);
      expect(persisted!.corrections, isEmpty);
      expect(
        persisted.findings.single.vehicleComponentId,
        VehicleComponentId.hood,
      );
    },
  );
}
