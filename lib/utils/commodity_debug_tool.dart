import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'data_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// This class provides debug utilities for identifying commodities showing as "Unknown"
class CommodityDebugTool {
  /// Identify commodities that are missing from the COMMODITY_ID_TO_DISPLAY map
  static Future<List<Map<String, dynamic>>> findUnknownCommodities() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> unknownCommodities = [];
    
    try {
      // Get all commodities from Firestore
      final querySnapshot = await _firestore.collection('commodities').get();
      debugPrint('\n===== COMMODITY DEBUG TOOL =====');
      debugPrint('Total commodities in Firestore: ${querySnapshot.docs.length}');
      
      // Check each commodity against the COMMODITY_ID_TO_DISPLAY map
      for (var doc in querySnapshot.docs) {
        final commodityId = doc.id;
        final commodityData = doc.data();
        
        if (!COMMODITY_ID_TO_DISPLAY.containsKey(commodityId)) {
          debugPrint('⚠️ UNKNOWN COMMODITY DETECTED: $commodityId');
          debugPrint('    Data: ${commodityData.toString()}');
          
          unknownCommodities.add({
            'id': commodityId,
            'data': commodityData,
          });
        }
      }
      
      // Summary
      if (unknownCommodities.isEmpty) {
        debugPrint('✅ No unknown commodities found.');
      } else {
        debugPrint('⛔️ Found ${unknownCommodities.length} unknown commodities:');
        for (var commodity in unknownCommodities) {
          debugPrint('  - ${commodity['id']}');
        }
      }
      
      return unknownCommodities;
    } catch (e) {
      debugPrint('❌ Error finding unknown commodities: $e');
      return [];
    }
  }
  
  /// Log the commodities currently loaded in the app
  static void logLoadedCommodities(List<Map<String, dynamic>> commodities) {
    debugPrint('\n===== LOADED COMMODITIES =====');
    debugPrint('Total loaded commodities: ${commodities.length}');
    
    // Count commodities without display mapping
    int unknownCount = 0;
    List<String> unknownIds = [];
    
    for (var commodity in commodities) {
      final id = commodity['id'].toString();
      if (!COMMODITY_ID_TO_DISPLAY.containsKey(id)) {
        unknownCount++;
        unknownIds.add(id);
        
        // Print details of the unknown commodity
        debugPrint('⚠️ UNMAPPED COMMODITY: $id');
        debugPrint('    Data: ${commodity.toString()}');
      }
    }
    
    // Print summary
    if (unknownCount == 0) {
      debugPrint('✅ All loaded commodities have display mappings.');
    } else {
      debugPrint('⛔️ Found $unknownCount commodities without display mappings:');
      for (var id in unknownIds) {
        debugPrint('  - $id');
      }
    }
  }
}
