import 'package:autodentifyr/models/assessment.dart';

class SeveritySuggestion {
  const SeveritySuggestion({
    required this.findingId,
    required this.level,
    required this.evidenceCaptureIds,
  });

  final String findingId;
  final SeverityLevel level;
  final List<String> evidenceCaptureIds;
}

class SeveritySuggestionBatch {
  const SeveritySuggestionBatch.supported({
    required this.sourceVersion,
    required this.suggestions,
    this.isSynthetic = false,
  }) : isSupported = true,
       limitation = null;

  const SeveritySuggestionBatch.unavailable({
    required this.sourceVersion,
    required this.limitation,
  }) : isSupported = false,
       suggestions = const [],
       isSynthetic = false;

  final bool isSupported;
  final String sourceVersion;
  final List<SeveritySuggestion> suggestions;
  final String? limitation;
  final bool isSynthetic;
}

abstract interface class SeveritySuggestionSource {
  Future<SeveritySuggestionBatch> suggest(
    List<DamageFinding> confirmedFindings,
    List<Capture> captures,
  );
}

class UnavailableSeveritySuggestionSource implements SeveritySuggestionSource {
  const UnavailableSeveritySuggestionSource();

  @override
  Future<SeveritySuggestionBatch> suggest(
    List<DamageFinding> confirmedFindings,
    List<Capture> captures,
  ) async => const SeveritySuggestionBatch.unavailable(
    sourceVersion: 'unsupported-severity-v1',
    limitation: 'Automated severity review is not supported.',
  );
}
