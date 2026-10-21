import '../entities/weekly_summary.dart';

abstract interface class WeeklySummaryRepository {
  /// The current account's latest weekly summary; null before the first.
  Future<WeeklySummary?> getLatest();
}
