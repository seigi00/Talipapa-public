import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/utils/data_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('None Value Persistence Tests', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Global filter "None" value should be preserved', () async {
      // Save "None" filter globally
      await DataCache.saveSelectedFilter("None", "global");
      
      // Verify it can be retrieved as "None"
      final filter = await DataCache.getSelectedFilter("global");
      expect(filter, "None");
    });

    test('Global sort "None" value should be preserved', () async {
      // Save "None" sort setting globally
      await DataCache.saveSelectedSort("None");
      
      // Verify it can be retrieved as "None"
      final sort = await DataCache.getSelectedSort();
      expect(sort, "None");
    });

    test('Forecast-specific sort "None" value should be preserved', () async {
      // Save "None" sort for specific forecast periods
      await DataCache.saveSelectedSortForForecast("None", "Now");
      await DataCache.saveSelectedSortForForecast("None", "Next Week");
      await DataCache.saveSelectedSortForForecast("None", "Two Weeks");
      
      // Verify all are retrieved as "None" 
      final nowSort = await DataCache.getSelectedSortForForecast("Now");
      final nextWeekSort = await DataCache.getSelectedSortForForecast("Next Week");
      final twoWeeksSort = await DataCache.getSelectedSortForForecast("Two Weeks");
      
      expect(nowSort, "None");
      expect(nextWeekSort, "None");
      expect(twoWeeksSort, "None");
    });

    test('Forecast-specific filter "None" value should be preserved', () async {
      // Save "None" filter for specific forecast periods
      await DataCache.saveSelectedFilter("None", "Now");
      await DataCache.saveSelectedFilter("None", "Next Week");
      await DataCache.saveSelectedFilter("None", "Two Weeks");
      
      // Verify all are retrieved as "None"
      final nowFilter = await DataCache.getSelectedFilter("Now");
      final nextWeekFilter = await DataCache.getSelectedFilter("Next Week");
      final twoWeeksFilter = await DataCache.getSelectedFilter("Two Weeks");
      
      expect(nowFilter, "None");
      expect(nextWeekFilter, "None");
      expect(twoWeeksFilter, "None");
    });

    test('Switching forecast views preserves "None" filter and sort', () async {
      // Setup initial state with "None" values
      await DataCache.saveSelectedFilter("None", "global");
      await DataCache.saveSelectedSort("None");
      
      // Simulate switching between forecast views
      // In the real app, this would trigger loading settings from cache
      final filterAfterSwitch = await DataCache.getSelectedFilter("global");
      final sortAfterSwitch = await DataCache.getSelectedSort();
      
      // Verify values remain "None"
      expect(filterAfterSwitch, "None");
      expect(sortAfterSwitch, "None");
    });
  });
}
