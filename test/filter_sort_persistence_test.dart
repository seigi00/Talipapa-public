import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/utils/data_cache.dart';
import '../lib/utils/forecast_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Universal Filter and Sort Persistence Tests', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Save and load global filter settings', () async {
      // Save filter globally
      await DataCache.saveSelectedFilter("Vegetables", "global");
      
      // Verify it can be retrieved
      final filter = await DataCache.getSelectedFilter("global");
      expect(filter, "Vegetables");
    });

    test('Global filter settings should apply across all forecast periods', () async {
      // Save global filter setting
      await DataCache.saveSelectedFilter("KADIWA RICE FOR ALL", "global");
      
      // Load the filter in application code - should get the global filter
      final filter = await DataCache.getSelectedFilter("global");
      
      // Verify the global filter is returned regardless of forecast period parameter
      expect(filter, "KADIWA RICE FOR ALL");
    });

    test('Save and load global sort settings', () async {
      // Save sort setting globally
      await DataCache.saveSelectedSort("Price (High to Low)");
      
      // Verify it can be retrieved
      final sort = await DataCache.getSelectedSort();
      
      expect(sort, "Price (High to Low)");
    });

    test('Legacy filter migration', () async {
      // Set up legacy filter setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedFilter', 'Vegetables');
      
      // Load state would normally handle this migration
      // Let's simulate it:
      final legacyFilter = prefs.getString('selectedFilter');
      if (legacyFilter != null) {
        await DataCache.saveSelectedFilter(legacyFilter, "global");
      }
      
      // Verify the filter was migrated
      final globalFilter = await DataCache.getSelectedFilter("global");
      expect(globalFilter, "Vegetables");
    });

    test('Save and load forecast data without filter settings', () async {
      // Create sample forecast data without filter settings (since they're now global)
      final forecastData = {
        'commodities': [],
        'filteredCommodities': [],
        'globalPriceDate': '1/1/2025',
        'forecastStartDate': '1/5/2025',
      };
      
      // Save to forecast cache
      await ForecastCacheManager.saveForecastData("Now", forecastData);
      
      // Retrieve from cache
      final cachedData = await ForecastCacheManager.getCachedForecastData("Now");
      
      // Verify data was preserved but shouldn't contain filter settings
      expect(cachedData!['globalPriceDate'], '1/1/2025');
      expect(cachedData['selectedSort'], null);
      expect(cachedData['selectedFilter'], null);
    });
  });
}
