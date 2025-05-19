import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DataCache {  static const String _commoditiesKey = 'cached_commodities';
  static const String _filteredCommoditiesKey = 'cached_filtered_commodities';
  static const String _globalPriceDateKey = 'cached_global_price_date';
  static const String _lastFetchTimeKey = 'last_fetch_time';
  static const String _selectedForecastKey = 'selected_forecast';
  static const String _selectedCommodityKey = 'selected_commodity_details';
  static const String _selectedSortKey = 'selected_sort';
  
  // Cache duration in minutes
  static const int _cacheDuration = 30; // 30 minutes by default
  
  // Save commodities to cache
  static Future<void> saveCommodities(List<Map<String, dynamic>> commodities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = commodities.map((commodity) => jsonEncode(commodity)).toList();
      await prefs.setStringList(_commoditiesKey, jsonData);
      await prefs.setString(_lastFetchTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving commodities to cache: $e');
    }
  }    // Get commodities from cache
  static Future<List<dynamic>> getCommodities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getStringList(_commoditiesKey) ?? [];
      
      return jsonData.map((item) => jsonDecode(item)).toList();
    } catch (e) {
      print('Error getting commodities from cache: $e');
      return [];
    }
  }
  
  // Save filtered commodities to cache
  static Future<void> saveFilteredCommodities(List<Map<String, dynamic>> filteredCommodities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = filteredCommodities.map((commodity) => jsonEncode(commodity)).toList();
      await prefs.setStringList(_filteredCommoditiesKey, jsonData);
    } catch (e) {
      print('Error saving filtered commodities to cache: $e');
    }
  }    // Get filtered commodities from cache
  static Future<List<dynamic>> getFilteredCommodities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getStringList(_filteredCommoditiesKey) ?? [];
      
      return jsonData.map((item) => jsonDecode(item)).toList();
    } catch (e) {
      print('Error getting filtered commodities from cache: $e');
      return [];
    }
  }
  
  // Save global price date
  static Future<void> saveGlobalPriceDate(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_globalPriceDateKey, date);
    } catch (e) {
      print('Error saving global price date to cache: $e');
    }
  }
  
  // Get global price date
  static Future<String> getGlobalPriceDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_globalPriceDateKey) ?? '';
    } catch (e) {
      print('Error getting global price date from cache: $e');
      return '';
    }
  }
  
  // Save selected forecast
  static Future<void> saveSelectedForecast(String forecast) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedForecastKey, forecast);
    } catch (e) {
      print('Error saving selected forecast to cache: $e');
    }
  }
  
  // Get selected forecast
  static Future<String> getSelectedForecast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedForecastKey) ?? 'Now';
    } catch (e) {
      print('Error getting selected forecast from cache: $e');
      return 'Now';
    }
  }
  
  // Check if cache is valid (not expired)
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTimeStr = prefs.getString(_lastFetchTimeKey);
      
      if (lastFetchTimeStr == null) {
        return false; // No cache exists yet
      }
      
      final lastFetchTime = DateTime.parse(lastFetchTimeStr);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastFetchTime).inMinutes;
      
      return difference < _cacheDuration;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }
    // Save selected commodity details
  static Future<void> saveSelectedCommodityDetails(Map<String, dynamic> commodityDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedCommodityKey, jsonEncode(commodityDetails));
      print('Saved selected commodity details to cache');
    } catch (e) {
      print('Error saving selected commodity details to cache: $e');
    }
  }
  
  // Get selected commodity details
  static Future<Map<String, dynamic>?> getSelectedCommodityDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_selectedCommodityKey);
      
      if (jsonData == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(jsonData));
    } catch (e) {
      print('Error getting selected commodity details from cache: $e');
      return null;
    }  }
  // Force refresh cache
  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Store sorting preference before invalidating cache
      final sortPreference = await getSelectedSort();
      
      // Remove all cache-related keys for a complete reset
      await prefs.remove(_lastFetchTimeKey);
      await prefs.remove(_commoditiesKey);
      await prefs.remove(_filteredCommoditiesKey);
      await prefs.remove(_globalPriceDateKey);
      
      // Restore sorting preference after cache reset
      if (sortPreference != null) {
        await saveSelectedSort(sortPreference);
      }
      
      // Keep selected forecast and commodity for better UX
      print('✅ Cache completely invalidated - next fetch will be from Firestore');
      print('✅ Preserved sort preference: $sortPreference');
    } catch (e) {
      print('❌ Error invalidating cache: $e');
    }
  }
  
  // Save selected sort option
  static Future<void> saveSelectedSort(String? sort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedSortKey, sort ?? "None");
      print('✅ Saved selected sort to cache: ${sort ?? "None"}');
    } catch (e) {
      print('❌ Error saving selected sort to cache: $e');
    }
  }
  
  // Get selected sort option
  static Future<String?> getSelectedSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortValue = prefs.getString(_selectedSortKey);
      return sortValue == "None" ? null : sortValue;
    } catch (e) {
      print('❌ Error getting selected sort from cache: $e');
      return null;
    }
  }
}