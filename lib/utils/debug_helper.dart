import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugHelper {
  static void printCommodityDebug({
    required List<Map<String, dynamic>> commodities,
    required List<String> displayedCommoditiesIds,
    required List<Map<String, dynamic>> filteredCommodities,
    String? globalPriceDate
  }) {
    debugPrint('\n=== COMMODITY DEBUG INFO ===');
    debugPrint('Total commodities fetched: ${commodities.length}');
    debugPrint('Total displayed IDs: ${displayedCommoditiesIds.length}');
    debugPrint('Total filtered commodities: ${filteredCommodities.length}');
    if (globalPriceDate != null) {
      debugPrint('Global Price Date: $globalPriceDate');
    }
    
    // Print first 3 commodities for inspection
    if (commodities.isNotEmpty) {
      debugPrint('\nSample commodities:');
      for (int i = 0; i < min(3, commodities.length); i++) {
        final commodity = commodities[i];
        final isGlobalDate = commodity['is_global_date'] ?? false;
        debugPrint('[$i] ID: ${commodity['id']}, Price: ${commodity['weekly_average_price']}, Date: ${commodity['price_date']}');
        debugPrint('    Is Global Date: $isGlobalDate, Is Forecast: ${commodity['is_forecast']}');
        debugPrint('    Display data: ${_getDisplayData(commodity['id'].toString())}');
      }
    } else {
      debugPrint('\nNo commodities to display!');
    }
    
    // Print first 3 displayed IDs for inspection
    if (displayedCommoditiesIds.isNotEmpty) {
      debugPrint('\nSample displayed IDs:');
      for (int i = 0; i < min(3, displayedCommoditiesIds.length); i++) {
        final id = displayedCommoditiesIds[i];
        debugPrint('[$i] ID: $id, Display data: ${_getDisplayData(id)}');
      }
    } else {
      debugPrint('\nNo displayed IDs!');
    }
    
    debugPrint('============================\n');
  }
  
  static String _getDisplayData(String id) {
    // This would need to be imported from your constants file
    // Just a placeholder for the debug file
    return 'ID mapping info would go here';
  }
  
  static void logPriceEntries(List<Map<String, dynamic>> entries, String label) {
    debugPrint('\n=== PRICE ENTRIES: $label ===');
    debugPrint('Total entries: ${entries.length}');
    
    // Count actual vs forecast prices
    final actualPrices = entries.where((p) => p['is_forecast'] == false).length;
    final forecastPrices = entries.where((p) => p['is_forecast'] == true).length;
    debugPrint('Actual prices: $actualPrices, Forecast prices: $forecastPrices');
    
    // Print a few sample entries for debugging
    if (entries.isNotEmpty) {
      for (int i = 0; i < min(3, entries.length); i++) {
        final entry = entries[i];
        final price = entry['price'];
        final date = entry['formatted_end_date'];
        final isForecast = entry['is_forecast'];
        final isGlobalDate = entry['is_global_date'] ?? false;
        
        debugPrint('[$i] Price: $price, Date: $date');
        debugPrint('    Is Forecast: $isForecast, Is Global Date: $isGlobalDate');
      }
    }
    
    debugPrint('============================\n');
  }
}

int min(int a, int b) => a < b ? a : b;
