// Reset cached forecast data and force refresh
// This function will be called to fix forecast graph display issues

import 'package:shared_preferences/shared_preferences.dart';

class ForecastDataFixer {
  // Keys used for forecast caching
  static const String _baseKey = 'forecast_cache';
  
  // Invalidate all forecast cache
  static Future<bool> invalidateAllForecastCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all forecast-related cache keys
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(_baseKey)) {
          await prefs.remove(key);
          print("🧹 Cleared forecast cache: $key");
        }
      }
      
      // Also clear the last used forecast marker
      await prefs.setString('last_used_forecast', '');
      
      print("✅ Successfully cleared all forecast caches");
      return true;
    } catch (e) {
      print("❌ Error clearing forecast caches: $e");
      return false;
    }
  }
  
  // Helper method to debug forecast cache
  static Future<Map<String, String>> debugForecastCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, String> cacheInfo = {};
      
      for (String key in keys) {
        if (key.startsWith(_baseKey)) {
          final value = prefs.getString(key) ?? '<null>';
          cacheInfo[key] = "${value.length} characters";
        }
      }
      
      return cacheInfo;
    } catch (e) {
      print("❌ Error debugging forecast cache: $e");
      return {};
    }
  }
}
