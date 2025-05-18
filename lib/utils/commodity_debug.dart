import 'package:flutter/foundation.dart';
import '../constants.dart';

class CommodityDebugHelper {
  /// Prints debug information about commodity loading
  static void logCommodityLoading({
    required List<Map<String, dynamic>> commodities,
    required List<String> displayedIds,
    required List<Map<String, dynamic>> filteredCommodities,
  }) {
    debugPrint('\n====== COMMODITY LOADING DEBUG ======');
    debugPrint('Total commodities fetched: ${commodities.length}');
    debugPrint('Total displayedIds: ${displayedIds.length}');
    debugPrint('Total filtered commodities: ${filteredCommodities.length}');
    
    // Check for mapping issues
    int missingMappings = 0;
    if (commodities.isNotEmpty) {
      for (var commodity in commodities.take(min(5, commodities.length))) {
        final id = commodity['id'].toString();
        final hasMapping = COMMODITY_ID_TO_DISPLAY.containsKey(id);
        if (!hasMapping) {
          missingMappings++;
          debugPrint('⚠️ Missing mapping for commodity ID: $id');
        }
      }
    }
    
    if (missingMappings > 0) {
      debugPrint('⚠️ Found $missingMappings commodities without display mappings in the first 5');
    }
    
    // Print first 3 commodities as samples
    if (commodities.isNotEmpty) {
      debugPrint('\n📝 SAMPLE COMMODITIES:');
      for (int i = 0; i < min(3, commodities.length); i++) {
        final commodity = commodities[i];
        final id = commodity['id'].toString();
        final displayData = COMMODITY_ID_TO_DISPLAY[id];
        
        debugPrint('[$i] ID: $id');
        debugPrint('    Display name: ${displayData?['display_name'] ?? "UNKNOWN"}');
        debugPrint('    Category: ${displayData?['category'] ?? "UNKNOWN"}');
        debugPrint('    Price: ${commodity['weekly_average_price']}');
      }
    }
    
    // Check if displayed IDs are in the commodities list
    if (displayedIds.isNotEmpty && commodities.isNotEmpty) {
      final commodityIds = commodities.map((c) => c['id'].toString()).toSet();
      int missingIds = 0;
      
      for (var id in displayedIds.take(min(5, displayedIds.length))) {
        if (!commodityIds.contains(id)) {
          missingIds++;
          debugPrint('⚠️ Displayed ID $id not found in fetched commodities');
        }
      }
      
      if (missingIds > 0) {
        debugPrint('⚠️ Found $missingIds displayed IDs not present in commodity data');
      }
    }
    
    debugPrint('====================================\n');
  }
}

int min(int a, int b) => a < b ? a : b;
