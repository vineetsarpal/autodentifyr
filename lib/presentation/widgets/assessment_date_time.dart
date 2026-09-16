import 'package:flutter/material.dart';

/// Presents assessment audit times in the reader's local time and locale.
/// Persisted and exported timestamps retain their original precision.
String formatAssessmentDateTime(BuildContext context, DateTime timestamp) {
  final local = timestamp.toLocal();
  final format = MaterialLocalizations.of(context);
  final date = format.formatMediumDate(local);
  final time = format.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date at $time';
}
