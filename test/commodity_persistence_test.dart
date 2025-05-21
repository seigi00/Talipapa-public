import 'package:flutter_test/flutter_test.dart';
import 'package:Talipapa/utils/data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Commodity Selection Persistence Tests', () {
    setUp(() async {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });
    
    test('Should save forecast-specific commodity selection', () async {
      // Set up test data
      final testCommodity = {
        'id': 'test-commodity-id',
        'weekly_average_price': 123.45,
        'test_attribute': 'test-value'
      };
      
      // Mock the forecast selection
      await DataCache.saveSelectedForecast("Next Week");
      
      // Save the commodity details
      await DataCache.saveSelectedCommodityDetails(testCommodity);
      
      // Get the preferences directly to check the storage
      final prefs = await SharedPreferences.getInstance();
      final globalCommodity = prefs.getString('selected_commodity_details');
      final forecastCommodity = prefs.getString('forecast_commodity_Next Week');
      
      // Both should be saved
      expect(globalCommodity, isNotNull);
      expect(forecastCommodity, isNotNull);
      
      // Verify the content is the same
      final Map<String, dynamic> globalData = jsonDecode(globalCommodity!);
      final Map<String, dynamic> forecastData = jsonDecode(forecastCommodity!);
      
      expect(globalData['id'], equals('test-commodity-id'));
      expect(forecastData['id'], equals('test-commodity-id'));
      expect(globalData, equals(forecastData));
    });
    
    test('Should retrieve forecast-specific commodity selection', () async {
      // Set up test data
      final testCommodityGlobal = {
        'id': 'global-commodity-id',
        'weekly_average_price': 123.45,
      };
      
      final testCommodityNextWeek = {
        'id': 'next-week-commodity-id',
        'weekly_average_price': 150.0,
      };
      
      final testCommodityTwoWeeks = {
        'id': 'two-weeks-commodity-id',
        'weekly_average_price': 175.0,
      };
      
      // Store directly in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('selected_forecast', 'Next Week');
      prefs.setString('selected_commodity_details', jsonEncode(testCommodityGlobal));
      prefs.setString('forecast_commodity_Next Week', jsonEncode(testCommodityNextWeek));
      prefs.setString('forecast_commodity_Two Weeks', jsonEncode(testCommodityTwoWeeks));
      
      // Retrieve with the current forecast set to "Next Week"
      await DataCache.saveSelectedForecast('Next Week');
      final retrievedForNextWeek = await DataCache.getSelectedCommodityDetails();
      
      expect(retrievedForNextWeek, isNotNull);
      expect(retrievedForNextWeek!['id'], equals('next-week-commodity-id'));
      
      // Change the forecast and retrieve again
      await DataCache.saveSelectedForecast('Two Weeks');
      final retrievedForTwoWeeks = await DataCache.getSelectedCommodityDetails();
      
      expect(retrievedForTwoWeeks, isNotNull);
      expect(retrievedForTwoWeeks!['id'], equals('two-weeks-commodity-id'));
      
      // Test fallback to global when forecast-specific not found
      await DataCache.saveSelectedForecast('Now');
      final retrievedForNow = await DataCache.getSelectedCommodityDetails();
      
      expect(retrievedForNow, isNotNull);
      expect(retrievedForNow!['id'], equals('global-commodity-id'));
    });
  });
}
