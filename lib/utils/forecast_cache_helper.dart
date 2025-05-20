import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for caching forecast data
class ForecastCacheHelper {
  static const String _forecastPricesKey = 'all_latest_prices';
  
  /// Checks if we have valid cached forecast data for a given forecast period
  /// Returns the cached data if valid, null otherwise
  static Future<Map<String, dynamic>?> getValidCachedForecastData(String forecastPeriod) async {
    try {
      // Check if we have cached data for this forecast period in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_forecastPricesKey}_$forecastPeriod';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        // Parse the cached data
        final jsonData = jsonDecode(cachedData);
        final timestamp = DateTime.parse(jsonData['timestamp']);
        final currentTime = DateTime.now();
          // Use the same cache duration (5 days) for all periods since we're using global date for "Now"
        final cacheDurationMinutes = 7200; // 5 days for all periods
        
        // Check if the cache is still valid (not expired)
        if (currentTime.difference(timestamp).inMinutes < cacheDurationMinutes) {
          print("✅ Using cached forecast data for $forecastPeriod view (${currentTime.difference(timestamp).inMinutes} minutes old)");
          return Map<String, dynamic>.from(jsonData['data']);
        } else {
          print("⏱️ Forecast cache expired - fetching new data");
          return null;
        }
      }
      
      print("🔄 No cache found for $forecastPeriod view");
      return null;
    } catch (e) {
      print("❌ Error retrieving cached forecast data: $e");
      return null;
    }
  }

  /// Saves forecast data to cache
  static Future<void> cacheForecastData(String forecastPeriod, Map<String, dynamic> forecastData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_forecastPricesKey}_$forecastPeriod';
      
      // Serialize the data with timestamp
      final cacheData = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': forecastData,
      });
      
      await prefs.setString(cacheKey, cacheData);
      print("✅ Saved forecast data to cache for $forecastPeriod view");
    } catch (e) {
      print("❌ Error saving forecast data to cache: $e");
    }
  }
  
  /// Updates commodities with forecast prices
  static List<Map<String, dynamic>> updateCommoditiesWithForecastPrices(
    List<Map<String, dynamic>> commodities,
    Map<String, dynamic> forecastPrices
  ) {
    return commodities.map((commodity) {
      final commodityId = commodity['id'].toString();
      if (forecastPrices.containsKey(commodityId)) {
        // Properly merge forecast data, preserve commodity metadata
        final forecastData = forecastPrices[commodityId];
        return {
          ...commodity,
          'weekly_average_price': forecastData['weekly_average_price'],
          'is_forecast': true,
          'has_forecast': true,
          'start_date': forecastData['start_date'],
          'end_date': forecastData['end_date'],
        };
      } else {
        // For commodities without forecast data
        return {
          ...commodity,
          'weekly_average_price': null,
          'is_forecast': false,
          'has_forecast': false,
        };
      }
    }).toList();
  }
}
