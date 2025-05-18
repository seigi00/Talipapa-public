import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  }  // Fetch weekly prices for a commodity
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
  }
    // Get most recent prices for all commodities (for homepage)
  Future<Map<String, dynamic>> fetchAllLatestPrices() async {
    try {
      print("🔄 Fetching all latest prices in a single query...");
      Map<String, dynamic> results = {};
      
      // Get all non-forecast prices in a single query, ordered by end_date
      final pricesQuery = await _db
          .collection('price_entries')
          .where('is_forecast', isEqualTo: false)
          .orderBy('end_date', descending: true)
          .get();
          
      print("✅ Found ${pricesQuery.docs.length} total price entries");
      
      // Group prices by commodity_id and keep only the latest one per commodity
      Map<String, Map<String, dynamic>> latestPricesByCommmodity = {};
      
      for (var doc in pricesQuery.docs) {
        final data = doc.data();
        final commodityId = data['commodity_id'] as String?;
        
        if (commodityId == null) continue;
        
        // If we haven't processed this commodity before, or if this price is more recent
        // Note: Since we ordered by end_date descending, the first entry for each commodity 
        // will be the most recent one
        if (!latestPricesByCommmodity.containsKey(commodityId)) {
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
          
          // Save this price as the latest for this commodity
          latestPricesByCommmodity[commodityId] = {
            'date': formattedStartDate,
            'start_date': data['start_date'],
            'end_date': data['end_date'],
            'price': price,
            'is_forecast': false,
            'source': data['source'] ?? '',
            'formatted_start_date': formattedStartDate,
            'formatted_end_date': formattedEndDate,
            'original_data': data
          };
          
          // Debug
          print("💰 Found latest price for $commodityId: $price (date: $formattedEndDate)");
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
}