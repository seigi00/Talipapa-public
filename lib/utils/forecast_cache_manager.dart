import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';  // Import for COMMODITY_ID_TO_DISPLAY

class ForecastCacheManager {
  static const String _baseKey = 'all_latest_prices';
  static const String _cacheVersion = '1.0';
  
  /// Get cached forecast data if it exists and is valid
  static Future<Map<String, dynamic>?> getCachedForecastData(String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_baseKey}_$forecastPeriod';
      final String? cachedData = prefs.getString(cacheKey);
      
      print("🔍 Checking cache for $forecastPeriod forecast data...");
        if (cachedData != null) {
        final Map<String, dynamic> jsonData = jsonDecode(cachedData);
        
        // Verify cache version
        final cacheVersion = jsonData['cacheVersion'] as String?;
        if (cacheVersion != _cacheVersion) {
          print("⚠️ Cache version mismatch. Expected: $_cacheVersion, Found: $cacheVersion");
          await invalidateForecastCache(forecastPeriod);
          return null;
        }
        
        final timestamp = DateTime.parse(jsonData['timestamp'] as String);
        final currentTime = DateTime.now();
          // Cache all data for 5 days since historical and forecast data won't change once in database
        final cacheDurationMinutes = 7200; // 5 days
        final minutesOld = currentTime.difference(timestamp).inMinutes;
        
        if (minutesOld < cacheDurationMinutes) {
          print("✅ Using cached forecast data for $forecastPeriod ($minutesOld minutes old)");
          // Include all fields except 'timestamp' which we add ourselves when saving
          final data = Map<String, dynamic>.from(jsonData);
          data.remove('timestamp');
          return data;
        } else {
          print("⏱️ Cache expired for $forecastPeriod - $minutesOld minutes old");
          // Cleanup expired cache
          await prefs.remove(cacheKey);
        }
      } else {
        print("📭 No cache found for $forecastPeriod period");
      }
      
      return null;
    } catch (e) {
      print("❌ Error reading forecast cache: $e");
      return null;
    }
  }
  /// Save forecast data to cache
  static Future<void> saveForecastData(String forecastPeriod, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_baseKey}_$forecastPeriod';
        // Prepare cache data with version and timestamp
      final Map<String, dynamic> dataCopy = Map<String, dynamic>.from(data);
      dataCopy['timestamp'] = DateTime.now().toIso8601String();
      dataCopy['cacheVersion'] = _cacheVersion;
      
      // Validate data structure before caching
      if (!_validateCacheData(dataCopy)) {
        print("⚠️ Invalid cache data structure for $forecastPeriod");
        return;
      }
      
      final cacheData = jsonEncode(dataCopy);
      
      await prefs.setString(cacheKey, cacheData);
      print("✅ Saved forecast data to cache for $forecastPeriod period");
      
      // Verify the data was saved correctly
      final saved = await getCachedForecastData(forecastPeriod);
      if (saved != null) {
        print("✅ Verified forecast cache for $forecastPeriod: contains ${saved['commodities']?.length ?? 0} commodities");
      } else {
        print("⚠️ Failed to verify forecast cache for $forecastPeriod");
      }
    } catch (e) {
      print("❌ Error saving forecast data to cache: $e");
    }
  }

  /// Invalidate specific forecast cache
  static Future<void> invalidateForecastCache(String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_baseKey}_$forecastPeriod';
      await prefs.remove(cacheKey);
      print("🗑️ Invalidated cache for $forecastPeriod period");
    } catch (e) {
      print("❌ Error invalidating forecast cache: $e");
    }
  }

  /// Check if there's valid cache for a forecast period
  static Future<bool> hasForecastCache(String forecastPeriod) async {
    return (await getCachedForecastData(forecastPeriod)) != null;
  }

  /// Validate cache data structure
  static bool _validateCacheData(Map<String, dynamic> data) {
    try {
      // Required fields
      if (!data.containsKey('commodities') || !data.containsKey('timestamp') || !data.containsKey('cacheVersion')) {
        return false;
      }
      
      // Validate commodities structure
      final commodities = data['commodities'] as List<dynamic>;
      if (commodities.isEmpty) {
        return false;
      }
      
      // Check first commodity for required fields
      final firstCommodity = commodities.first as Map<String, dynamic>;
      return firstCommodity.containsKey('id') && 
             firstCommodity.containsKey('weekly_average_price') &&
             firstCommodity.containsKey('price_date');
    } catch (e) {
      print("❌ Cache validation error: $e");
      return false;
    }
  }

  /// Convert forecast data to a readable string for the chatbot
  static String formatForChatbot(Map<String, dynamic> data, String forecastPeriod) {
    final StringBuffer buffer = StringBuffer();
    final commodities = data['commodities'] as List<dynamic>;
    final globalPriceDate = data['globalPriceDate'] as String;

    buffer.writeln('Forecast Period: $forecastPeriod');
    buffer.writeln('Latest price data as of: $globalPriceDate');
    buffer.writeln('\nCommodity Prices:');

    for (final commodity in commodities) {
      final id = commodity['id'] as String;
      final price = commodity['weekly_average_price'];
      final priceDate = commodity['price_date'] as String;
      final isForecast = commodity['is_forecast'] ?? false;
      
      final displayData = COMMODITY_ID_TO_DISPLAY[id];
      if (displayData != null) {
        final name = displayData['display_name'];
        final unit = displayData['unit'];
        final category = displayData['category'];
        
        buffer.writeln('\n- $name ($category)');
        buffer.writeln('  Price: ₱${price.toString()} per $unit');
        buffer.writeln('  Date: $priceDate');
        if (isForecast) {
          buffer.writeln('  Type: Forecast');
        }
      }
    }

    return buffer.toString();
  }

  /// Get all cached forecast data as formatted string for chatbot
  static Future<String> getAllForecastDataForChatbot() async {
    final StringBuffer buffer = StringBuffer();
    final periods = ['Now', 'Next Week', 'Two Weeks'];
    
    for (final period in periods) {
      final data = await getCachedForecastData(period);
      if (data != null) {
        buffer.writeln('\n=== $period ===');
        buffer.writeln(formatForChatbot(data, period));
      }
    }
    
    return buffer.toString();
  }
}
