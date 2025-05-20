import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/forecast_cache_manager.dart';

// Method to build the dialog content for selecting commodities
Widget buildDialogContent(
  String searchText,
  List<String> selectedItems,
  Function(String, bool) onItemToggle,
  Function(String) onSearchChanged,
  Map<String, Map<String, dynamic>> commodityIdToDisplay,
  List<Map<String, dynamic>> allCommodities,
) {
  // Filter the commodities based on search text
  final filteredCommodities = searchText.isEmpty
      ? allCommodities
      : allCommodities.where((commodity) {
          final commodityId = commodity['id'].toString();
          final displayInfo = commodityIdToDisplay[commodityId];
          final displayName = displayInfo?['display_name'] ?? "Unknown Commodity";
          return displayName.toLowerCase().contains(searchText.toLowerCase());
        }).toList();

  return Container(
    height: 400,
    width: 300,
    child: Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search commodities...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        
        // List of commodities with checkboxes
        Expanded(
          child: ListView.builder(
            itemCount: filteredCommodities.length,
            itemBuilder: (context, index) {
              final commodity = filteredCommodities[index];
              final commodityId = commodity['id'].toString();
              final displayInfo = commodityIdToDisplay[commodityId] ?? {'display_name': 'Unknown'};
              final displayName = displayInfo['display_name'] ?? "Unknown";
              
              return CheckboxListTile(
                title: Text(displayName),
                value: selectedItems.contains(commodityId),
                onChanged: (bool? value) {
                  if (value != null) {
                    onItemToggle(commodityId, value);
                  }
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

// Helper to format forecast button
Widget buildForecastButton(
  BuildContext context,
  String text, {
  required double height,
  required String selectedForecast,
  required Function(String) onForecastChanged,
  required Function(Map<String, dynamic>) onPricesUpdated,
  required firestoreService,
  required Color kPink,
  required Color kDivider,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(minWidth: 100, maxWidth: 130),
    child: SizedBox(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: selectedForecast == text ? kPink : kDivider),
          backgroundColor: selectedForecast == text ? kPink.withOpacity(0.2) : Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),        onPressed: () async {
          // Update the selected forecast period
          onForecastChanged(text);
          
          // First check if we have cached data for this forecast period
          final forecastCache = await ForecastCacheManager.getCachedForecastData(text);
          if (forecastCache != null) {
            print("✅ Using cached forecast data for $text");
            
            // We have valid cached data, pass it to the parent
            final Map<String, dynamic> latestPricesMap = {};
            
            // Transform the cached data format to match what's expected
            final commodities = forecastCache['commodities'] as List<dynamic>;
            for (final commodity in commodities) {
              final commodityId = commodity['id'].toString();
              if (commodity['weekly_average_price'] != null) {
                latestPricesMap[commodityId] = {
                  'price': commodity['weekly_average_price'],
                  'is_forecast': commodity['is_forecast'] ?? false,
                  'formatted_end_date': commodity['price_date'] ?? '',
                  'forecast_period': commodity['forecast_period'] ?? '',
                  'is_global_date': commodity['is_global_date'] ?? false,
                };
              }
            }
            
            // Use the cached data
            onPricesUpdated(latestPricesMap);
            print("✅ Updated prices from cache with forecast period: $text");
          } else {
            // No valid cache, fetch from Firestore
            try {
              print("🔄 No valid cache for $text, fetching from Firestore...");
              // Fetch the latest prices with the selected forecast period
              final Map<String, dynamic> latestPricesData = await firestoreService.fetchAllLatestPrices(
                forecastPeriod: text
              );
              
              // Pass the price data to the parent widget to update the UI
              onPricesUpdated(latestPricesData);
              
              print("✅ Updated prices with forecast period: $text");
            } catch (e) {
              print("❌ Error updating prices with forecast: $e");
            }
          }
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: selectedForecast == text ? kPink : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

// Build the global date display widget with dynamic date
Widget buildGlobalDateDisplay(String globalPriceDate, Color kBlue) {
  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: EdgeInsets.symmetric(vertical: 8),
    alignment: Alignment.center,
    child: Text(
      "As of: ${globalPriceDate.isNotEmpty ? globalPriceDate : 'Latest Available Data'}",
      style: TextStyle(
        color: kBlue,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

// Helper method to check if a commodity date is different from global date
bool isOlderDate(String commodityDate, String globalDate) {
  if (commodityDate.isEmpty || 
      commodityDate == "No data" || 
      commodityDate == globalDate) {
    return false;
  }
  return true;
}
