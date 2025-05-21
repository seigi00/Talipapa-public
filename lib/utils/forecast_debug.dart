import 'package:flutter/foundation.dart';

/// Utility class for debugging forecast period assignments
class ForecastDebugHelper {
  /// Logs information about forecast periods for a commodity
  static void logForecastPeriods(
    String commodityId, 
    String forecastView,
    List<Map<String, dynamic>> forecasts,
  ) {
    debugPrint('\n====== FORECAST PERIOD DEBUG ======');
    debugPrint('Commodity ID: $commodityId');
    debugPrint('Current View: $forecastView');
    debugPrint('Total Forecasts: ${forecasts.length}');
    
    if (forecasts.isEmpty) {
      debugPrint('❌ No forecasts available for this commodity');
      return;
    }
    
    // Group by forecast period
    final Map<String, List<Map<String, dynamic>>> forecastsByPeriod = {};
    
    for (final forecast in forecasts) {
      final period = forecast['forecast_period'] ?? 'Unknown';
      if (!forecastsByPeriod.containsKey(period)) {
        forecastsByPeriod[period] = [];
      }
      forecastsByPeriod[period]!.add(forecast);
    }
    
    // Print summary of periods
    debugPrint('\n📊 FORECAST DISTRIBUTION:');
    forecastsByPeriod.forEach((period, periodForecasts) {
      debugPrint('$period: ${periodForecasts.length} forecasts');
    });
    
    // Print details of each forecast
    debugPrint('\n📝 FORECAST DETAILS:');
    for (int i = 0; i < forecasts.length; i++) {
      final forecast = forecasts[i];
      final period = forecast['forecast_period'] ?? 'Unknown';
      final date = forecast['formatted_end_date'] ?? 'Unknown date';
      final price = forecast['price']?.toString() ?? 'Unknown price';
      
      debugPrint('[$i] Period: $period');
      debugPrint('    Date: $date');
      debugPrint('    Price: $price');
    }
    
    debugPrint('====== END FORECAST DEBUG ======\n');
  }
  
  /// Verify forecast periods are correctly assigned based on chronological order
  static void verifyChronologicalAssignment(List<Map<String, dynamic>> forecasts) {
    debugPrint('\n====== CHRONOLOGICAL VERIFICATION ======');
    
    if (forecasts.isEmpty) {
      debugPrint('❌ No forecasts to verify');
      return;
    }
    
    if (forecasts.length == 1) {
      final singleForecast = forecasts.first;
      final period = singleForecast['forecast_period'] ?? 'Unknown';
      
      debugPrint('✅ Only one forecast - should be assigned to "Next Week"');
      debugPrint('   Actual assignment: $period');
      debugPrint('   Status: ${period == "Next Week" ? "CORRECT" : "INCORRECT"}');
      return;
    }
    
    // Sort by date
    forecasts.sort((a, b) {
      final aDate = a['end_date'];
      final bDate = b['end_date'];
      
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });
    
    // Verify assignments
    bool hasErrors = false;
    
    for (int i = 0; i < forecasts.length; i++) {
      final forecast = forecasts[i];
      final period = forecast['forecast_period'] ?? 'Unknown';
      final date = forecast['formatted_end_date'] ?? 'Unknown date';
      final expectedPeriod = i == 0 ? 'Next Week' : 'Two Weeks';
      final isCorrect = period == expectedPeriod;
      
      if (!isCorrect) hasErrors = true;
      
      debugPrint('[$i] Date: $date');
      debugPrint('    Expected: $expectedPeriod, Actual: $period');
      debugPrint('    Status: ${isCorrect ? "✅ CORRECT" : "❌ INCORRECT"}');
    }
    
    debugPrint('Overall Status: ${hasErrors ? "❌ ERRORS FOUND" : "✅ ALL CORRECT"}');
    debugPrint('====== END VERIFICATION ======\n');
  }
}
