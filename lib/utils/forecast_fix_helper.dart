// Debug utility to check forecast data and fix issues with forecast periods
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForecastDebugHelper {
  // Utility function to ensure forecasts have proper forecast_period assigned
  static List<Map<String, dynamic>> ensureForecastPeriodsExist(List<Map<String, dynamic>> priceData) {
    // Clone the list to avoid modifying the original data
    final result = List<Map<String, dynamic>>.from(priceData);
    
    // Find all forecasts
    final forecasts = result.where((entry) => entry['is_forecast'] == true).toList();
    if (forecasts.isEmpty) {
      return result; // No forecasts to fix
    }
    
    // Get actual prices (non-forecasts)
    final actualPrices = result.where((entry) => entry['is_forecast'] != true).toList();
    if (actualPrices.isEmpty) {
      debugPrint("⚠️ No actual prices found to use as reference");
      return result;
    }
    
    // Sort actual prices by date (descending to get most recent first)
    actualPrices.sort((a, b) {
      final aDate = a['end_date'] as Timestamp;
      final bDate = b['end_date'] as Timestamp;
      return bDate.compareTo(aDate);
    });
    
    // Sort forecasts by date (ascending for chronological order)
    forecasts.sort((a, b) {
      final aDate = a['end_date'] as Timestamp;
      final bDate = b['end_date'] as Timestamp;
      return aDate.compareTo(bDate);
    });
    
    debugPrint("🔍 Found ${forecasts.length} forecasts to check/fix periods");
    
    // Assign forecast periods based on chronological order
    // First forecast = Next Week, second forecast = Two Weeks
    for (int i = 0; i < forecasts.length; i++) {
      final forecasted = forecasts[i];
      final forecastIdx = result.indexWhere((e) => 
          e['is_forecast'] == true && 
          e['end_date'] == forecasted['end_date']);
      
      if (forecastIdx != -1) {
        // Check if already has a forecast_period
        if (result[forecastIdx]['forecast_period'] == null || 
            result[forecastIdx]['forecast_period'].toString().isEmpty) {
          
          // Assign period based on position
          result[forecastIdx]['forecast_period'] = (i == 0) ? "Next Week" : "Two Weeks";
          
          debugPrint("✅ Fixed: Assigned '${result[forecastIdx]['forecast_period']}' period to forecast for date ${result[forecastIdx]['formatted_end_date']}");
        } else {
          debugPrint("ℹ️ Already has period: '${result[forecastIdx]['forecast_period']}' for date ${result[forecastIdx]['formatted_end_date']}");
        }
      }
    }
    
    return result;
  }
  
  // Log actual and forecast prices to help with debugging
  static void logPriceData(List<Map<String, dynamic>> priceData, String commodityId) {
    if (priceData.isEmpty) {
      debugPrint("⚠️ No price data found for commodity $commodityId");
      return;
    }
    
    final actualPrices = priceData.where((e) => e['is_forecast'] != true).toList();
    final forecasts = priceData.where((e) => e['is_forecast'] == true).toList();
    
    debugPrint("\n📊 PRICE DATA SUMMARY FOR $commodityId:");
    debugPrint("  Actual prices: ${actualPrices.length}");
    debugPrint("  Forecast prices: ${forecasts.length}");
    
    if (actualPrices.isNotEmpty) {
      debugPrint("\n📅 ACTUAL PRICES:");
      for (var price in actualPrices) {
        debugPrint("  - Date: ${price['formatted_end_date']}, Price: ${price['price']}");
      }
    }
    
    if (forecasts.isNotEmpty) {
      debugPrint("\n🔮 FORECAST PRICES:");
      for (var forecast in forecasts) {
        final period = forecast['forecast_period'] ?? 'MISSING';
        debugPrint("  - Date: ${forecast['formatted_end_date']}, Period: $period, Price: ${forecast['price']}");
      }
    }
  }
}
