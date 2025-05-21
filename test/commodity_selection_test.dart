import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../lib/utils/data_cache.dart';

void main() {
  setUp(() async {
    // Set up mock for SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  test('Commodity selection persists when switching forecast views', () async {
    // Arrange
    final commodityDetails = {
      'id': '12345',
      'name': 'Test Commodity',
      'price': '100.0',
    };

    // First save with "Now" forecast view
    await DataCache.saveSelectedForecast("Now");
    await DataCache.saveSelectedCommodityDetails(commodityDetails);
    
    // Switch to "Next Week" forecast view
    await DataCache.saveSelectedForecast("Next Week");
    
    // Act
    final selectedCommodity = await DataCache.getSelectedCommodityDetails();
    
    // Assert
    // Should have saved the commodity to the forecast-specific key
    expect(selectedCommodity?['id'], equals('12345'));
    expect(selectedCommodity?['name'], equals('Test Commodity'));
  });

  test('Commodity selection for each forecast view is separate', () async {
    // Arrange
    final commodityDetailsNow = {
      'id': '12345',
      'name': 'Commodity for Now View',
      'price': '100.0',
    };
    
    final commodityDetailsNextWeek = {
      'id': '67890',
      'name': 'Commodity for Next Week View',
      'price': '200.0',
    };

    // Save for "Now" forecast
    await DataCache.saveSelectedForecast("Now");
    await DataCache.saveSelectedCommodityDetails(commodityDetailsNow);
    
    // Save for "Next Week" forecast
    await DataCache.saveSelectedForecast("Next Week");
    await DataCache.saveSelectedCommodityDetails(commodityDetailsNextWeek);
    
    // Act - switch back to "Now" and get the selection
    await DataCache.saveSelectedForecast("Now");
    final selectedForNow = await DataCache.getSelectedCommodityDetails();
    
    // Switch to "Next Week" and get the selection
    await DataCache.saveSelectedForecast("Next Week");
    final selectedForNextWeek = await DataCache.getSelectedCommodityDetails();
    
    // Assert
    expect(selectedForNow?['id'], equals('12345'));
    expect(selectedForNow?['name'], equals('Commodity for Now View'));
    
    expect(selectedForNextWeek?['id'], equals('67890'));
    expect(selectedForNextWeek?['name'], equals('Commodity for Next Week View'));
  });
}
