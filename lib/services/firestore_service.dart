import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // For tracking forecast entries by commodity
  bool _forecastDatesOrganized = false;
  Map<String, List<Timestamp>> _forecastDatesByCommodity = {};

  // Fetch all commodities
  Future<List<Map<String, dynamic>>> fetchCommodities() async {
    final snapshot = await _db.collection('commodities').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Include the document ID as part of the data
      return {
        ...data,
        'id': doc.id,
      };
    }).toList();
  }
  // Fetch a single commodity by ID
  Future<Map<String, dynamic>?> fetchCommodityById(String id) async {
    final doc = await _db.collection('commodities').doc(id).get();
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    return {
      ...data,
      'id': doc.id,
    };
  }
  
  // NEW: Fetch all commodity IDs for the dialog
  Future<List<String>> fetchAllCommodityIds() async {
    final snapshot = await _db.collection('commodities').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }
  
  // NEW: Fetch all commodities for the dialog
  Future<List<Map<String, dynamic>>> fetchAllCommodities() async {
    final snapshot = await _db.collection('commodities').get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }// Fetch weekly prices for a commodity
  Future<List<Map<String, dynamic>>> fetchWeeklyPrices(String commodityId) async {
    try {
      print("🔍 Fetching weekly prices for commodity: $commodityId");
      
      final snapshot = await _db
          .collection('price_entries')
          .where('commodity_id', isEqualTo: commodityId)
          // Don't filter by is_forecast here, so we get both actual and forecast prices
          .orderBy('end_date') // Change to end_date for consistency with other queries
          .get()
          .catchError((error) {
            print("❌ Firestore query error: $error");
            if (error.toString().contains("requires an index")) {
              print("⚠️ This query requires a Firestore index. Please create it using the link in the error message.");
            }
            throw error; // Rethrow to be caught by the outer try-catch
          });
      
      final results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Format start_date and end_date
        String formattedStartDate = data['start_date'] != null ? 
            _formatTimestamp(data['start_date']) : "";
        
        String formattedEndDate = data['end_date'] != null ? 
            _formatTimestamp(data['end_date']) : "";
        
        // Ensure price is a valid number
        double price = 0.0;
        if (data['price'] != null) {
          if (data['price'] is double) {
            price = data['price'];
          } else if (data['price'] is num) {
            price = (data['price'] as num).toDouble();
          } else {
            price = double.tryParse(data['price'].toString()) ?? 0.0;
          }
        }
        
        // Ensure is_forecast is properly set (default to false if missing)
        final isForecast = data['is_forecast'] ?? false;
        
        final result = {
          'date': formattedStartDate, // Keep for backward compatibility
          'start_date': data['start_date'],
          'end_date': data['end_date'],
          'price': price,
          'is_forecast': isForecast,
          'source': data['source'] ?? '',
          'formatted_start_date': formattedStartDate,
          'formatted_end_date': formattedEndDate,
          'original_data': data
        };
        
        // Debug log each entry
        print("📝 Price entry: ${result['price']} (${isForecast ? 'Forecast' : 'Actual'}) - ${formattedEndDate}");
        
        return result;
      }).toList();
      
      print("✅ Fetched ${results.length} price entries for commodity $commodityId");
      
      // Count actual vs forecast prices
      final actualCount = results.where((p) => p['is_forecast'] == false).length;
      final forecastCount = results.where((p) => p['is_forecast'] == true).length;
      print("💰 $actualCount actual prices, $forecastCount forecast prices");
      
      if (results.isNotEmpty) {
        // Find the latest actual price
        final actualPrices = results.where((p) => p['is_forecast'] == false).toList();
        if (actualPrices.isNotEmpty) {
          actualPrices.sort((a, b) {
            final aDate = a['end_date'] as Timestamp;
            final bDate = b['end_date'] as Timestamp;
            return bDate.compareTo(aDate); // Latest first
          });
          
          final latestActual = actualPrices.first;
          print("💰 Latest actual price: ${latestActual['price']}, Date: ${latestActual['formatted_end_date']}");
        } else {
          print("⚠️ No actual (non-forecast) prices found");
        }
      }
      
      return results;
    } catch (e) {
      print("❌ Error fetching weekly prices: $e");
      
      // Check if this is an index error and provide more helpful message
      if (e.toString().contains("requires an index")) {
        print("📢 IMPORTANT: You need to create a Firestore index for price_entries collection.");
        print("📢 Please click the link in the error message above or go to Firebase console to create the required index.");
      }
      
      return [];
    }
  }  // Fetch only forecasted prices for a commodity
  Future<List<Map<String, dynamic>>> fetchForecastPrices(String commodityId) async {
    try {
      final snapshot = await _db
          .collection('price_entries')
          .where('commodity_id', isEqualTo: commodityId)
          .where('is_forecast', isEqualTo: true)
          .orderBy('end_date') // Use end_date for consistency with other queries
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Format start_date and end_date
        String formattedStartDate = data['start_date'] != null ? 
            _formatTimestamp(data['start_date']) : "";
        
        String formattedEndDate = data['end_date'] != null ? 
            _formatTimestamp(data['end_date']) : "";
          // Ensure price is a valid number
        double price = 0.0;
        if (data['price'] != null) {
          if (data['price'] is double) {
            price = data['price'];
          } else if (data['price'] is num) {
            price = (data['price'] as num).toDouble();
          } else {
            price = double.tryParse(data['price'].toString()) ?? 0.0;
          }
        }
        
        return {
          'date': formattedStartDate, // Keep for backward compatibility
          'start_date': data['start_date'],
          'end_date': data['end_date'],
          'price': price,
          'is_forecast': true, // Make sure it's marked as forecast
          'source': data['source'] ?? '',
          'formatted_start_date': formattedStartDate,
          'formatted_end_date': formattedEndDate,
          'original_data': data
        };
      }).toList();
    } catch (e) {
      if (e.toString().contains("requires an index")) {
        print("❗ Index required for fetching forecast prices: $e");
        print("📢 You need to create a Firestore index for the price_entries collection.");
        print("📢 Please click the link in the error message above or go to Firebase console.");
      } else {
        print("Error fetching forecast prices: $e");
      }
      return [];
    }
  }
  // Fetch the latest price for a commodity
  Future<Map<String, dynamic>?> fetchLatestPrice(String commodityId) async {
    try {
      print("🔍 Fetching latest price for commodity: $commodityId");
      
      final snapshot = await _db
          .collection('price_entries')
          .where('commodity_id', isEqualTo: commodityId)
          .where('is_forecast', isEqualTo: false) // Only get actual prices, not forecasts
          .orderBy('end_date', descending: true) // Use end_date for most recent
          .limit(1)
          .get()
          .catchError((error) {
            print("❌ Firestore query error: $error");
            if (error.toString().contains("requires an index")) {
              print("⚠️ This query requires a Firestore index. Please create it using the link in the error message.");
            }
            throw error; // Rethrow to be caught by the outer try-catch
          });
      
      if (snapshot.docs.isEmpty) {
        print("⚠️ No actual prices found for commodity: $commodityId");
        
        // Try to get forecast prices as a fallback
        print("🔍 Trying to fetch forecast prices instead...");
        final forecastSnapshot = await _db
            .collection('price_entries')
            .where('commodity_id', isEqualTo: commodityId)
            .where('is_forecast', isEqualTo: true)
            .orderBy('end_date', descending: true)
            .limit(1)
            .get();
            
        if (forecastSnapshot.docs.isEmpty) {
          print("⚠️ No forecast prices found either for commodity: $commodityId");
          return null;
        }
        
        final forecastData = forecastSnapshot.docs.first.data();
        final formattedStartDate = forecastData['start_date'] != null ? 
            _formatTimestamp(forecastData['start_date']) : "";
        final formattedEndDate = forecastData['end_date'] != null ? 
            _formatTimestamp(forecastData['end_date']) : "";
            
        print("✅ Found forecast price: ${forecastData['price']} for $commodityId");
        
        return {
          'date': formattedStartDate,
          'start_date': forecastData['start_date'],
          'end_date': forecastData['end_date'],
          'price': forecastData['price'] ?? 0.0,
          'is_forecast': true, // Mark as forecast
          'source': forecastData['source'] ?? '',
          'formatted_start_date': formattedStartDate,
          'formatted_end_date': formattedEndDate,
          'original_data': forecastData
        };
      }
      
      final data = snapshot.docs.first.data();
      
      // Format start_date and end_date
      String formattedStartDate = data['start_date'] != null ? 
          _formatTimestamp(data['start_date']) : "";
      
      String formattedEndDate = data['end_date'] != null ? 
          _formatTimestamp(data['end_date']) : "";
      
      // Ensure price is a valid number
      double price = 0.0;
      if (data['price'] != null) {
        if (data['price'] is double) {
          price = data['price'];
        } else if (data['price'] is num) {
          price = (data['price'] as num).toDouble();
        } else {
          price = double.tryParse(data['price'].toString()) ?? 0.0;
        }
      }
      
      print("✅ Found actual price: $price for $commodityId (date: $formattedEndDate)");
      
      return {
        'date': formattedStartDate,
        'start_date': data['start_date'],
        'end_date': data['end_date'],
        'price': price,
        'is_forecast': false, // Make sure it's marked as non-forecast
        'source': data['source'] ?? '',
        'formatted_start_date': formattedStartDate,
        'formatted_end_date': formattedEndDate,
        'original_data': data
      };
    } catch (e) {
      if (e.toString().contains("requires an index")) {
        print("❗ Index required for fetching latest price: $e");
        print("📢 You need to create a Firestore index for the price_entries collection.");
        print("📢 Please click the link in the error message above or go to Firebase console.");
      } else {
        print("❌ Error fetching latest price: $e");
      }
      return null;
    }
  }
    // Helper method to format timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.month}/${date.day}/${date.year}";
  }  // Get most recent prices for all commodities (for homepage)
  Future<Map<String, dynamic>> fetchAllLatestPrices({String forecastPeriod = "Now"}) async {
    try {
      print("🔄 Fetching all latest prices in a single query... (Forecast: $forecastPeriod)");
      Map<String, dynamic> results = {};
      
      // First, get the latest global price date (for non-forecasted prices)
      final globalDateInfo = await fetchLatestGlobalPriceDate();
      final Timestamp? globalLatestDate = globalDateInfo['date'];
      final String globalFormattedDate = globalDateInfo['formattedDate'];
      
      // Create an efficient query based on our needs
      var pricesQuery;
        if (forecastPeriod == "Now") {
        // For "Now" view, get only the most recent non-forecast prices
        // We'll use the global date as reference for consistency
        final globalDateInfo = await fetchLatestGlobalPriceDate();
        final globalLatestDate = globalDateInfo['date'] as Timestamp?;

        if (globalLatestDate != null) {
          pricesQuery = await _db
              .collection('price_entries')
              .where('is_forecast', isEqualTo: false)
              .where('end_date', isEqualTo: globalLatestDate)
              .get();
        } else {
          // Fallback to getting latest prices if no global date
          pricesQuery = await _db
              .collection('price_entries')
              .where('is_forecast', isEqualTo: false)
              .orderBy('end_date', descending: true)
              .get();
        }      } else {        // For forecast views, only get forecast prices
        print("🔍 Querying forecast prices for period: $forecastPeriod");
        pricesQuery = await _db
            .collection('price_entries')
            .where('is_forecast', isEqualTo: true)
            .orderBy('end_date') // Order by ascending to get chronological order
            .get();
            
        print("📊 Found ${pricesQuery.docs.length} forecast price entries");
        
        // Debug: Print all forecast entries grouped by commodity
        Map<String, List<Map<String, dynamic>>> forecastsByCommodity = {};
        for (var doc in pricesQuery.docs) {
          final data = doc.data();
          final commodityId = data['commodity_id'] as String?;
          final endDate = data['end_date'] as Timestamp?;
          
          if (commodityId != null && endDate != null) {
            if (!forecastsByCommodity.containsKey(commodityId)) {
              forecastsByCommodity[commodityId] = [];
            }
            forecastsByCommodity[commodityId]!.add({
              'date': _formatTimestamp(endDate),
              'price': data['price'],
            });
          }
        }
        
        // Print forecast data for each commodity
        print("\n📅 Forecast Dates by Commodity:");
        forecastsByCommodity.forEach((commodityId, forecasts) {
          print("\n🔸 Commodity: $commodityId");
          forecasts.sort((a, b) => a['date'].compareTo(b['date'])); // Sort by date
          for (int i = 0; i < forecasts.length; i++) {
            print("  ${i + 1}. Date: ${forecasts[i]['date']}, Price: ${forecasts[i]['price']}");
          }
        });
      }
          
      print("✅ Found ${pricesQuery.docs.length} total price entries");
      
      // Group prices by commodity_id and keep the appropriate ones based on forecast setting
      Map<String, Map<String, dynamic>> latestPricesByCommmodity = {};
      
      // First pass: Add the global date prices (highest priority)
      if (globalLatestDate != null) {
        for (var doc in pricesQuery.docs) {
          final data = doc.data();
          final commodityId = data['commodity_id'] as String?;
          final isForecast = data['is_forecast'] ?? false;
          final currentEndDate = data['end_date'] as Timestamp?;
          
          if (commodityId == null || isForecast || currentEndDate == null) continue;
            // For "Now" view: only add non-forecast prices from global date
          // For forecast views: only add forecast prices
          bool isRelevantPrice = (forecastPeriod == "Now" && !isForecast && currentEndDate.seconds == globalLatestDate.seconds) ||
                                 (forecastPeriod != "Now" && isForecast);
          
          if (isRelevantPrice) {
            _addPriceEntry(
              data: data, 
              commodityId: commodityId, 
              latestPricesByCommmodity: latestPricesByCommmodity,
              globalLatestDate: globalLatestDate,
              globalFormattedDate: globalFormattedDate,
              isForecast: isForecast,
              forecastPeriod: forecastPeriod
            );
          }
        }
      }
        // Second pass: Process all remaining prices
      for (var doc in pricesQuery.docs) {
        final data = doc.data();
        final commodityId = data['commodity_id'] as String?;
        final isForecast = data['is_forecast'] ?? false;
        
        if (commodityId == null) continue;
        
        // Process based on forecast setting
        bool shouldProcess = false;
        final currentEndDate = data['end_date'] as Timestamp?;
        
        if (forecastPeriod == "Now") {
          if (!isForecast) {
            // Skip if we already have a global date price for this commodity
            if (latestPricesByCommmodity.containsKey(commodityId) && 
                latestPricesByCommmodity[commodityId]!['is_global_date']) {
              continue;
            }
            
            // Otherwise, if we don't have any price for this commodity yet
            if (!latestPricesByCommmodity.containsKey(commodityId)) {
              shouldProcess = true;
            } 
            // Or if we have a price, but this one is newer
            else if (latestPricesByCommmodity.containsKey(commodityId)) {
              final existingDate = latestPricesByCommmodity[commodityId]!['end_date'] as Timestamp;
              if (currentEndDate != null && currentEndDate.compareTo(existingDate) > 0) {
                // This price is newer, so use it
                shouldProcess = true;
              }
            }
          }        } else if (forecastPeriod == "Next Week" || forecastPeriod == "Two Weeks") {          // For forecast views, handle each commodity's forecast entries chronologically
          if (isForecast) {
            final currentEndDate = data['end_date'] as Timestamp?;
            
            if (currentEndDate != null) {
              print("\n🔍 Processing forecast entry for commodity $commodityId");
              print("📅 Current entry date: ${_formatTimestamp(currentEndDate)}");
              
              // Get all forecast entries for this commodity
              final allForecastEntries = pricesQuery.docs
                  .where((d) => d.data()['commodity_id'] == commodityId && (d.data()['is_forecast'] ?? false))
                  .toList();
              
              // Sort by date (ascending)
              allForecastEntries.sort((a, b) {
                final aDate = a.data()['end_date'] as Timestamp;
                final bDate = b.data()['end_date'] as Timestamp;
                return aDate.compareTo(bDate);
              });
              
              print("📊 Found ${allForecastEntries.length} total forecast entries for this commodity");
              print("Forecast dates in order:");
              for (var entry in allForecastEntries) {
                final date = entry.data()['end_date'] as Timestamp;
                final price = entry.data()['price'];
                print("  - ${_formatTimestamp(date)}: ₱$price");
              }
              
              // Find position of this entry
              int position = -1;
              for (int i = 0; i < allForecastEntries.length; i++) {
                final entryDate = allForecastEntries[i].data()['end_date'] as Timestamp;
                if (entryDate.seconds == currentEndDate.seconds) {
                  position = i + 1; // 1-based position
                  break;
                }
              }
              
              print("📍 This entry's position in sequence: $position");
              
              // First position = Next Week, others = Two Weeks
              String actualForecastPeriod = (position == 1) ? "Next Week" : "Two Weeks";
              
              print("📊 Forecast position for ${_formatTimestamp(currentEndDate)}: $position, period: $actualForecastPeriod");
              
              // Only process if the forecast period matches what we want to show
              if (forecastPeriod == actualForecastPeriod) {
                shouldProcess = true;
              }
            }
          } else if (!latestPricesByCommmodity.containsKey(commodityId)) {
            // If we don't have any price for this commodity yet, use this actual price
            shouldProcess = true;
          }
        }
        
        if (shouldProcess) {
          _addPriceEntry(
            data: data, 
            commodityId: commodityId, 
            latestPricesByCommmodity: latestPricesByCommmodity,
            globalLatestDate: globalLatestDate,
            globalFormattedDate: globalFormattedDate,
            isForecast: isForecast,
            forecastPeriod: forecastPeriod
          );
        }
      }
      
      print("✅ Processed latest prices for ${latestPricesByCommmodity.length} commodities");
      
      // Convert to final result format
      results = latestPricesByCommmodity;
      
      return results;
    } catch (e) {
      print("❌ Error fetching all latest prices: $e");
      if (e.toString().contains("requires an index")) {
        print("📢 IMPORTANT: You need to create a Firestore index for the price_entries collection.");
        print("📢 Please click the link in the error message above or go to Firebase console.");
      }
      return {};
    }
  }
  
  // Helper method to add a price entry to the latestPricesByCommmodity map
  void _addPriceEntry({
    required Map<String, dynamic> data,
    required String commodityId,
    required Map<String, Map<String, dynamic>> latestPricesByCommmodity,
    required Timestamp? globalLatestDate,
    required String globalFormattedDate,
    required bool isForecast,
    required String forecastPeriod
  }) {
    // Format dates for display
    String formattedStartDate = data['start_date'] != null ? 
        _formatTimestamp(data['start_date']) : "";
    
    String formattedEndDate = data['end_date'] != null ? 
        _formatTimestamp(data['end_date']) : "";
    
    // Ensure price is a valid number
    double price = 0.0;
    if (data['price'] != null) {
      if (data['price'] is double) {
        price = data['price'];
      } else if (data['price'] is num) {
        price = (data['price'] as num).toDouble();
      } else {
        price = double.tryParse(data['price'].toString()) ?? 0.0;
      }
    }
      // Add flag to indicate if this price is from the global date
    final isGlobalDate = globalLatestDate != null && 
                   data['end_date'] != null &&
                   (data['end_date'] as Timestamp).seconds == globalLatestDate.seconds;
      // For forecast prices, determine whether it's Next Week or Two Weeks
    String actualForecastPeriod = "";
    if (isForecast && data['end_date'] != null) {
      // For consistency, we use the same determination logic as in the selection code
      if (forecastPeriod == "Next Week" || forecastPeriod == "Two Weeks") {
        // Use the selected forecast period since we've already validated it
        actualForecastPeriod = forecastPeriod;
      } else {
        // Fallback to legacy calculation
        final forecastDate = (data['end_date'] as Timestamp).toDate();
        final today = DateTime.now();
        final daysDifference = forecastDate.difference(today).inDays;
        
        // Categorize based on days from now
        actualForecastPeriod = (daysDifference <= 7) ? "Next Week" : "Two Weeks";
      }
    }
    
    // Save this price as the latest for this commodity
    latestPricesByCommmodity[commodityId] = {
      'date': formattedStartDate,
      'start_date': data['start_date'],
      'end_date': data['end_date'],
      'price': price,
      'is_forecast': isForecast,
      'forecast_period': actualForecastPeriod, // Add the actual forecast period
      'is_global_date': isGlobalDate,
      'global_date': globalFormattedDate,
      'source': data['source'] ?? '',
      'formatted_start_date': formattedStartDate,
      'formatted_end_date': formattedEndDate,
      'original_data': data
    };
      // Debug
    String forecastInfo = isForecast ? 'forecast ($actualForecastPeriod)' : 'actual';
    print("💰 ${isGlobalDate ? '[GLOBAL DATE]' : 'Found'} $forecastInfo price for $commodityId: $price (date: $formattedEndDate) [${forecastPeriod}]");
  }
  
  // Get the latest global price date (for non-forecasted prices)
  Future<Map<String, dynamic>> fetchLatestGlobalPriceDate() async {
    try {
      print("🔄 Fetching latest global price date...");
      
      // Get the global latest price date
      final latestPriceQuery = await _db
          .collection('price_entries')
          .where('is_forecast', isEqualTo: false)
          .orderBy('end_date', descending: true)
          .limit(1)
          .get();
          
      if (latestPriceQuery.docs.isEmpty) {
        print("⚠️ No non-forecasted prices found in the database");
        return {
          'success': false,
          'date': null,
          'formattedDate': ""
        };
      }
      
      final latestPriceDoc = latestPriceQuery.docs.first;
      final endDate = latestPriceDoc['end_date'] as Timestamp?;
      
      if (endDate == null) {
        print("⚠️ Latest price document has no end_date");
        return {
          'success': false,
          'date': null,
          'formattedDate': ""
        };
      }
        final date = endDate.toDate();
      
      // Format date as "May 3 2025" style
      final List<String> months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final String formattedDate = "${months[date.month - 1]} ${date.day} ${date.year}";
      print("📅 Latest global price date: $formattedDate");
      
      return {
        'success': true,
        'date': endDate,
        'formattedDate': formattedDate
      };
    } catch (e) {
      print("❌ Error fetching latest global price date: $e");
      return {
        'success': false,
        'date': null,
        'formattedDate': ""
      };
    }
  }
}
