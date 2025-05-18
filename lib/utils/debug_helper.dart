import 'package:flutter/foundation.dart';
import 'dart:math';

class DebugHelper {
  static void printCommodityDebug({
    required List<Map<String, dynamic>> commodities,
    required List<String> displayedCommoditiesIds,
    required List<Map<String, dynamic>> filteredCommodities
  }) {
    debugPrint('\n=== COMMODITY DEBUG INFO ===');
    debugPrint('Total commodities fetched: ${commodities.length}');
    debugPrint('Total displayed IDs: ${displayedCommoditiesIds.length}');
    debugPrint('Total filtered commodities: ${filteredCommodities.length}');
    
    // Print first 3 commodities for inspection
    if (commodities.isNotEmpty) {
      debugPrint('\nSample commodities:');
      for (int i = 0; i < min(3, commodities.length); i++) {
        final commodity = commodities[i];
        debugPrint('[$i] ID: ${commodity['id']}, Price: ${commodity['weekly_average_price']}');
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
}

int min(int a, int b) => a < b ? a : b;
