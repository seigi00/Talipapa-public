import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DataCache {  static const String _commoditiesKey = 'cached_commodities';
  static const String _filteredCommoditiesKey = 'cached_filtered_commodities';
  static const String _globalPriceDateKey = 'cached_global_price_date';
  static const String _lastFetchTimeKey = 'last_fetch_time';
  static const String _selectedForecastKey = 'selected_forecast';  static const String _selectedCommodityKey = 'selected_commodity_details';
  static const String _selectedSortKey = 'selected_sort';
  static const String _forecastStartDateKey = 'forecast_start_date';
  // Keys for forecast-specific commodity selections
  static const String _forecastCommodityKeyPrefix = 'forecast_commodity_';
  
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
      
      // Also save commodity details for the current forecast
      final currentForecast = await getSelectedForecast();
      // currentForecast is never null (defaults to 'Now')
      final forecastSpecificKey = _forecastCommodityKeyPrefix + currentForecast;
      await prefs.setString(forecastSpecificKey, jsonEncode(commodityDetails));
      print('Saved selected commodity details to cache for forecast: $currentForecast');
      
      print('Saved selected commodity details to global cache');
    } catch (e) {
      print('Error saving selected commodity details to cache: $e');
    }
  }
    // Get selected commodity details
  static Future<Map<String, dynamic>?> getSelectedCommodityDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentForecast = await getSelectedForecast();
      String? jsonData;
      
      // First try to get forecast-specific selection
      final forecastSpecificKey = _forecastCommodityKeyPrefix + currentForecast;
      jsonData = prefs.getString(forecastSpecificKey);
      
      if (jsonData != null) {
        print('Found forecast-specific commodity selection for: $currentForecast');
        return Map<String, dynamic>.from(jsonDecode(jsonData));
      }
      
      // Fall back to global selection
      jsonData = prefs.getString(_selectedCommodityKey);
      
      if (jsonData == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(jsonData));
    } catch (e) {
      print('Error getting selected commodity details from cache: $e');
      return null;
    }}// Force refresh cache
  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store global sorting and filtering preferences before invalidating cache
      final sortPreference = await getSelectedSort();
      final globalFilterPreference = await getSelectedFilter("global");
      
      // Remove all cache-related keys for a complete reset
      await prefs.remove(_lastFetchTimeKey);
      await prefs.remove(_commoditiesKey);
      await prefs.remove(_filteredCommoditiesKey);
      await prefs.remove(_globalPriceDateKey);
      await prefs.remove(_forecastStartDateKey);
      
      // Restore global sorting and filtering preferences after cache reset
      if (sortPreference != null) {
        await saveSelectedSort(sortPreference);
      }
      
      if (globalFilterPreference != null) {
        await saveSelectedFilter(globalFilterPreference, "global");
      }
      
      // Keep selected forecast and commodity for better UX
      print('✅ Cache completely invalidated - next fetch will be from Firestore');
      print('✅ Preserved sort/filter preferences for all forecast periods');
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
      // Return the actual value including "None" to preserve selection
      return sortValue;
    } catch (e) {
      print('❌ Error getting selected sort from cache: $e');
      return null;
    }
  }

  // Save forecast start date
  static Future<void> saveForecastStartDate(String forecastStartDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_forecastStartDateKey, forecastStartDate);
      print('✅ Saved forecast start date to cache: $forecastStartDate');
    } catch (e) {
      print('❌ Error saving forecast start date to cache: $e');
    }
  }
  
  // Get forecast start date
  static Future<String> getForecastStartDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startDate = prefs.getString(_forecastStartDateKey) ?? "";
      return startDate;
    } catch (e) {
      print('❌ Error getting forecast start date from cache: $e');
      return "";
    }
  }

  // Save selected filter option for specific forecast period
  static Future<void> saveSelectedFilter(String? filter, String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${forecastPeriod}_selected_filter';
      await prefs.setString(key, filter ?? "None");
      print('✅ Saved selected filter to cache for $forecastPeriod: ${filter ?? "None"}');
    } catch (e) {
      print('❌ Error saving selected filter to cache: $e');
    }
  }
    // Get selected filter option for specific forecast period
  static Future<String?> getSelectedFilter(String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${forecastPeriod}_selected_filter';
      final filterValue = prefs.getString(key);
      // Return the actual value including "None" to preserve selection
      return filterValue;
    } catch (e) {
      print('❌ Error getting selected filter from cache: $e');
      return null;
    }
  }

  // Save selected sort option for specific forecast period
  static Future<void> saveSelectedSortForForecast(String? sort, String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${forecastPeriod}_selected_sort';
      await prefs.setString(key, sort ?? "None");
      print('✅ Saved selected sort to cache for $forecastPeriod: ${sort ?? "None"}');
    } catch (e) {
      print('❌ Error saving selected sort to cache: $e');
    }
  }
  // Get selected sort option for specific forecast period
  static Future<String?> getSelectedSortForForecast(String forecastPeriod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${forecastPeriod}_selected_sort';
      final sortValue = prefs.getString(key);
      // Return the actual value including "None" to preserve selection
      return sortValue;
    } catch (e) {
      print('❌ Error getting selected sort from cache: $e');
      return null;
    }
  }
}