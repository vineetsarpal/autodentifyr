import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

class FailNextAssessmentSaveRepository implements AssessmentRepository {
  FailNextAssessmentSaveRepository(this.delegate);

  final AssessmentRepository delegate;
  bool failNextSave = false;

  @override
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      return const AssessmentSaveFailed(
        message: 'Device storage is temporarily unavailable.',
      );
    }
    return delegate.save(assessment, expectedUpdatedAt: expectedUpdatedAt);
  }

  @override
  Future<IntakeAssessment?> findById(String id) => delegate.findById(id);

  @override
  Future<List<IntakeAssessment>> list() => delegate.list();

  @override
  Future<AssessmentDeleteResult> delete(
    String id, {
    DateTime? expectedUpdatedAt,
  }) => delegate.delete(id, expectedUpdatedAt: expectedUpdatedAt);
}
