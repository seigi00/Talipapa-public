// chatbot header too big. try center setting options, change font of settings text

import 'package:Talipapa/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
// Firestore
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Local imports
import 'custom_bottom_navbar.dart';
import 'constants.dart'; // Make sure this contains COMMODITY_ID_TO_NAME
import 'image_mapping.dart';
import 'services/firestore_service.dart';
import 'utils/debug_helper.dart';
import 'utils/data_cache.dart';
import 'utils/forecast_cache_manager.dart';
import 'utils/forecast_fix_helper.dart' as FixHelper; // Import for forecast fix helper
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Talipapa',
      theme: ThemeData(
        primaryColor: kGreen,
        scaffoldBackgroundColor: kLightGray,
        iconTheme: IconThemeData(color: kBlue),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: kBlue),
          bodyMedium: TextStyle(color: kBlue),
        ),
        fontFamily: 'Roboto',
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool forceRefresh;
  
  // Constructor with optional forceRefresh parameter
  const HomePage({Key? key, this.forceRefresh = false}) : super(key: key);
  
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedForecast = "Now";
  String searchText = "";
  bool isSearching = false;
  static bool _hasShownTutorial = false;
  bool showTutorial = false;
  int? selectedIndex;
  String? selectedSort;
  String? selectedFilter;
  String? selectedCommodityId; // <-- Use ID instead of name
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firestoreService = FirestoreService();

  List<Map<String, dynamic>> commodities = [];
  List<Map<String, dynamic>> filteredCommodities = [];
  List<String> favoriteCommodities = [];
  List<String> displayedCommoditiesIds = []; // <-- Use IDs
  bool isHoldMode = false;
  Set<String> heldCommodities = {};  String? deviceUUID;
  String globalPriceDate = ""; // Store the latest global price date
  String forecastStartDate = ""; // Store the forecast start date
  bool _dataInitialized = false; // Track if data has been initialized@override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && isSearching) {
        setState(() {
          // Only change the isSearching state, but keep the searchText
          isSearching = false;
        });
      }
    });
    _initializeUUID();
    _checkFirstLaunch();
    
    // Check if a forced refresh is requested
    if (widget.forceRefresh) {
      print("🔄 Force refresh requested from initState");
      refreshDataFromFirestore();
    } else {
      loadCachedDataAndFetch();
    }
    
    loadDisplayedCommodities();
    loadFavorites();
    loadState();
    _loadSelectedCommodity();
  }
  
  // Load the selected commodity from cache
  Future<void> _loadSelectedCommodity() async {
    try {
      final cachedCommodityDetails = await DataCache.getSelectedCommodityDetails();
      
      if (cachedCommodityDetails != null && cachedCommodityDetails.isNotEmpty) {
        final commodityId = cachedCommodityDetails['id']?.toString();
        
        if (commodityId != null && commodityId.isNotEmpty) {
          setState(() {
            selectedCommodityId = commodityId;
          });
          print("✅ Loaded selected commodity from cache for forecast $selectedForecast: $commodityId");
        }
      }
    } catch (e) {
      print("❌ Error loading selected commodity from cache: $e");
    }
  }
    // Load data from cache and then fetch if needed
  Future<void> loadCachedDataAndFetch() async {
    // First try to load from cache for immediate display
    bool loadedFromCache = await _loadFromCache();
      // If cache is invalid or empty, fetch from network
    if (!loadedFromCache) {
      await fetchCommodities();
    } else {
      print("✅ Loaded commodity data from cache");
      // No background fetch to prevent unnecessary Firestore calls
      print("✅ Using cached data without background refresh");
    }
  }  // Load data from cache
  Future<bool> _loadFromCache() async {
    try {
      // Get the selected forecast period
      final cachedForecast = await DataCache.getSelectedForecast();
      final forecastPeriod = cachedForecast.isNotEmpty ? cachedForecast : "Now";
      
      print("⚠️ DEBUG: Loading from cache for forecast period: $forecastPeriod");
      
      // Load from forecast-specific cache for all periods including "Now"
      final forecastCache = await ForecastCacheManager.getCachedForecastData(forecastPeriod);
      if (forecastCache != null && forecastCache['commodities'] != null) {
        final List<dynamic> tempCommodities = forecastCache['commodities'];
        final List<Map<String, dynamic>> typedCommodities = tempCommodities.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Log forecast data to verify it's loaded correctly
        print("🔍 Loaded forecast commodities for $forecastPeriod: ${typedCommodities.length}");
        
        // Debug log to check if forecasts have the correct period data
        if (forecastPeriod != "Now") {
          int forecastCount = 0;
          int matchingPeriodCount = 0;
          
          for (var commodity in typedCommodities.take(3)) {
            if (commodity['is_forecast'] == true) {
              forecastCount++;
              final period = commodity['forecast_period'] ?? 'Unknown';
              if (period == forecastPeriod) {
                matchingPeriodCount++;
              }
              print("⚠️ Sample forecast: ${commodity['id']} - Period: $period, Price: ${commodity['weekly_average_price']}");
            }
          }
          
          print("⚠️ DEBUG: Found $forecastCount forecasts, $matchingPeriodCount match $forecastPeriod period");
        }
        
        // Get filtered commodities from the cache
        final List<dynamic> tempFilteredCommodities = forecastCache['filteredCommodities'] ?? tempCommodities;
        final List<Map<String, dynamic>> typedFilteredCommodities = tempFilteredCommodities.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Check if we need to load the forecast start date from the DataCache
        String cachedForecastStartDate = "";
        if (forecastPeriod != "Now") {
          cachedForecastStartDate = await DataCache.getForecastStartDate();
        }        // Always load global sort and filter settings
        String? sortToUse = await DataCache.getSelectedSort();
        String? filterToUse = await DataCache.getSelectedFilter("global");
        
        print("✅ Loaded global sort and filter settings: Sort=$sortToUse, Filter=$filterToUse");
          // Load the commodity selection for this specific forecast view
        final cachedCommodityDetails = await DataCache.getSelectedCommodityDetails();
        String? commodityToSelect = null;
        if (cachedCommodityDetails != null && cachedCommodityDetails.isNotEmpty) {
          commodityToSelect = cachedCommodityDetails['id']?.toString();
          print("✅ Loaded commodity selection for $forecastPeriod: $commodityToSelect");
        }
        
        // Now set the state with the determined values
        setState(() {
          commodities = typedCommodities;
          filteredCommodities = typedFilteredCommodities;
          globalPriceDate = forecastCache['globalPriceDate'] ?? "";
          forecastStartDate = forecastCache['forecastStartDate'] ?? cachedForecastStartDate;
          selectedForecast = forecastPeriod;
          // Preserve existing sort/filter selections if they exist, otherwise use the loaded values
          selectedSort = selectedSort ?? sortToUse;
          selectedFilter = selectedFilter ?? filterToUse;
          // Set the commodity selection for this forecast view
          if (commodityToSelect != null) {
            selectedCommodityId = commodityToSelect;
          }
        });
        
        // Apply the sorting and filtering after the setState
        if (selectedFilter != null) {
          _applyFiltersOnly();
        }
        if (selectedSort != null) {
          _applySorting();
        }
        
        print("✅ Successfully loaded forecast data from cache for $forecastPeriod");
        return true;
      }
      
      print("⚠️ No valid forecast cache found for $forecastPeriod");
      return false;
    } catch (e) {
      print("❌ Error loading data from cache: $e");
      return false;
    }
  }

  Future<void> _initializeUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUUID = prefs.getString('deviceUUID');

    if (storedUUID == null) {
      // Generate a new UUID
      final uuid = Uuid();
      storedUUID = uuid.v4();

      // Save the UUID to SharedPreferences
      await prefs.setString('deviceUUID', storedUUID);
    }

    setState(() {
      deviceUUID = storedUUID;
    });

    print("Device UUID: $deviceUUID");
  }

  Future<void> _checkFirstLaunch() async {
    if (_hasShownTutorial) return; // Prevent showing multiple times in one session

    final prefs = await SharedPreferences.getInstance();
    bool skipTutorial = prefs.getBool('skipLaunchTutorial') ?? false;

    if (!skipTutorial) {
      setState(() {
        showTutorial = true;
        _hasShownTutorial = true; // Mark as shown for this session
      });
    }
  }

  void _closeTutorial() {
    setState(() {
      showTutorial = false;
    });
  }  // Store the last used forecast period to detect changes
  String _lastUsedForecast = "Now";
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only fetch commodities when needed:
    // 1. First load (_dataInitialized is false)
    // 2. When forecast period changes (_lastUsedForecast != selectedForecast)
    if (!_dataInitialized || _lastUsedForecast != selectedForecast) {
      print("🔄 Forecast changed from $_lastUsedForecast to $selectedForecast");
      print("🧪 DEBUG: _dataInitialized=$_dataInitialized, cache will be checked");
      
      // Try to load from cache first if forecast period changed
      if (_lastUsedForecast != selectedForecast) {
        ForecastCacheManager.hasForecastCache(selectedForecast).then((hasCachedForecast) {
          if (hasCachedForecast) {
            print("🔍 Found forecast data in cache for $selectedForecast, loading from cache");
            _loadFromCache().then((loadedFromCache) {
              if (loadedFromCache) {
                // Save the current forecast as the last used
                _lastUsedForecast = selectedForecast;
                print("✅ Successfully switched to $selectedForecast view from cache");
                
                // Debug log all forecast periods for currently selected commodity
                if (selectedCommodityId != null) {
                  print("🧪 DEBUG: Checking chart data for commodity $selectedCommodityId in $selectedForecast view");
                  firestoreService.fetchWeeklyPrices(selectedCommodityId!).then((weeklyPrices) {
                    final actualPrices = weeklyPrices.where((p) => p['is_forecast'] == false).toList();
                    final forecastPrices = weeklyPrices.where((p) => p['is_forecast'] == true).toList();
                    
                    print("🧪 Found ${actualPrices.length} actual prices and ${forecastPrices.length} forecast prices");
                    
                    // Log forecast periods
                    for (final forecast in forecastPrices) {
                      final period = forecast['forecast_period'] ?? 'Unknown';
                      final price = forecast['price'];
                      final date = forecast['formatted_end_date'];
                      print("🧪 Forecast: $period, Price: $price, Date: $date");
                    }
                  });
                }
              } else {                print("⚠️ Failed to load from cache for $selectedForecast, will fetch from Firestore");
                fetchCommodities();
              }
            });
          } else {            print("⚠️ No cache found for $selectedForecast, will fetch from Firestore");
            fetchCommodities();
          }
        }).catchError((e) {          print("❌ Error checking forecast cache: $e");
          fetchCommodities();
        });
      } else {
        // First load, try cache first, then fetch
        _loadFromCache().then((loadedFromCache) {
          if (!loadedFromCache) {            print("⚠️ No initial cache, fetching commodities");
            fetchCommodities();
          } else {
            print("✅ Loaded initial data from cache");
            // Save the current forecast as the last used
            _lastUsedForecast = selectedForecast;
          }
        });
      }
    } else {
      print("🔄 No forecast change detected, skipping fetch (still on $selectedForecast)");
    }
  }  // Apply filters without fetching data from Firestore
  void _applyFiltersOnly() {
    print("🔍 Applying filters to existing data without Firestore fetch");
    setState(() {
      if (selectedFilter == "None" || selectedFilter == null) {
        filteredCommodities = List.from(commodities);
      } else if (selectedFilter == "Favorites") {
        // Update the filter logic for "Favorites"
        filteredCommodities = commodities.where((commodity) {
          final commodityId = commodity['id'].toString();
          return favoriteCommodities.contains(commodityId);
        }).toList();
      } else {
        // Update filter logic for commodity types - now using category
        filteredCommodities = commodities.where((commodity) {
          final commodityId = commodity['id'].toString();
          final typeInfo = COMMODITY_ID_TO_DISPLAY[commodityId];
          if (typeInfo == null) return false;
          
          final category = typeInfo['category'] ?? "";
          return category.toLowerCase() == selectedFilter?.toLowerCase();
        }).toList();
      }
      
      // Apply sorting if necessary
      _applySorting();
      
      // Cache the filtered result
      DataCache.saveFilteredCommodities(filteredCommodities);
    });
      // Save the filter preference globally
    DataCache.saveSelectedFilter(selectedFilter, "global").then((_) {
      print("✅ Saved global filter preference: $selectedFilter");
    });
  }    // Apply sorting to the filtered list
  void _applySorting() {
    if (selectedSort == "Name") {
      filteredCommodities.sort((a, b) {
        final nameA = COMMODITY_ID_TO_DISPLAY[a['id'].toString()]?['display_name'] ?? "";
        final nameB = COMMODITY_ID_TO_DISPLAY[b['id'].toString()]?['display_name'] ?? "";
        return nameA.compareTo(nameB);
      });
    } else if (selectedSort == "Price (Low to High)") {
      filteredCommodities.sort((a, b) {
        double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
        double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
        return priceA.compareTo(priceB);
      });
    } else if (selectedSort == "Price (High to Low)") {
      filteredCommodities.sort((a, b) {
        double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
        double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
        return priceB.compareTo(priceA);
      });
    }
      // Cache the sort preference globally
    DataCache.saveSelectedSort(selectedSort).then((_) {
      print("✅ Saved global sort preference: $selectedSort");
    });
  }// Fetch commodities from Firestore
  Future<void> fetchCommodities() async {
    try {
      print("🔄 Fetching commodities from Firestore...");
      
      // STEP 1: Get the latest global price date
      final globalDateInfo = await firestoreService.fetchLatestGlobalPriceDate();
      final String formattedGlobalDate = globalDateInfo['formattedDate'] ?? "";
      globalPriceDate = formattedGlobalDate; // Store for use in UI
        // STEP 2: Get all the latest prices in a single batch for all commodities
      print("🔄 Fetching all latest prices in one batch...");
      final allLatestPrices = await firestoreService.fetchAllLatestPrices(forecastPeriod: selectedForecast);
      print("✅ Fetched latest prices for ${allLatestPrices.length} commodities (Forecast: $selectedForecast)");
        // For forecast views, determine the forecast start date
      if (selectedForecast != "Now") {
        // Look for the earliest forecast entry date for the selected period
        Timestamp? earliestForecastDate;
        
        allLatestPrices.forEach((commodityId, priceData) {
          // For "Next Week" view, only look at Next Week forecasts
          // For "Two Weeks" view, prefer Next Week forecasts as the starting point
          if (priceData['is_forecast'] == true && 
             (priceData['forecast_period'] == selectedForecast || 
              (selectedForecast == "Two Weeks" && priceData['forecast_period'] == "Next Week"))) {
            final currentStartDate = priceData['start_date'] as Timestamp?;
            if (currentStartDate != null) {
              if (earliestForecastDate == null || currentStartDate.compareTo(earliestForecastDate!) < 0) {
                earliestForecastDate = currentStartDate;
              }
            }
          }
        });
        
        // Format the forecast start date if we found one
        if (earliestForecastDate != null) {
          final date = earliestForecastDate!.toDate();
          forecastStartDate = "${date.month}/${date.day}/${date.year}";
          print("📅 Forecast start date: $forecastStartDate");
        } else {
          forecastStartDate = "";
        }
      }
      
      // Fetch all commodity documents from Firestore
      final querySnapshot = await _firestore.collection('commodities').get();
      final List<Map<String, dynamic>> allCommodities = [];
      
      if (querySnapshot.docs.isEmpty) {
        print("⚠️ Warning: No commodities found in Firestore");
        return;
      }
        // Process each commodity document
      for (var doc in querySnapshot.docs) {
        final commodityId = doc.id; // This is the UUID
        final commodityData = doc.data(); // Get the actual document data
        
        // Create base commodity entry first (in case price fetching fails)
        Map<String, dynamic> commodityEntry = {
          'id': commodityId,
          'weekly_average_price': 0.0,
          'price_date': '',  // Empty string instead of 'No data'
          'is_forecast': false,  // Default to false
          // Add any other fields from the commodity document
          ...commodityData,
        };
        
        try {          // Get price from the batch fetch we did earlier
          if (allLatestPrices.containsKey(commodityId)) {            final latestPriceData = allLatestPrices[commodityId] as Map<String, dynamic>;
            final price = latestPriceData['price'] ?? 0.0;
            final formattedDate = latestPriceData['formatted_end_date'] ?? "";
            final isForecast = latestPriceData['is_forecast'] ?? false;
            final isGlobalDate = latestPriceData['is_global_date'] ?? false;
            final forecastPeriod = latestPriceData['forecast_period'] ?? "";
            
            // Add more specific date tag for forecasts if needed
            String dateDisplay = formattedDate;
            if (isForecast && selectedForecast != "Now") {
              // Use the actual forecast period from the data rather than the selectedForecast
              dateDisplay = "$formattedDate ($forecastPeriod)";
            }
              // Update commodity entry with price info
            // Only use this price if it matches our selected forecast period
            bool shouldUsePrice = false;
            if (selectedForecast == "Now" && !isForecast) {
              shouldUsePrice = true;
            } else if (selectedForecast == forecastPeriod) {
              // For forecast views, only use prices that match our selected period
              shouldUsePrice = true;
            }
            
            if (shouldUsePrice) {
              commodityEntry['weekly_average_price'] = price;
              commodityEntry['price_date'] = dateDisplay; // Use enhanced dateDisplay that includes forecast period
              commodityEntry['is_forecast'] = isForecast;
              commodityEntry['forecast_period'] = forecastPeriod; // Store the forecast period
              commodityEntry['is_global_date'] = isGlobalDate; // Store whether this price is from the global date
              
              print("💰 Selected price for ${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? commodityId}: ₱$price ($formattedDate) ${isForecast ? '(Forecast - $forecastPeriod)' : ''} ${isGlobalDate ? '[GLOBAL DATE]' : ''}");
            }
            
            print("💰 Price data for ${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? commodityId}: ₱$price ($formattedDate) ${isForecast ? '(Forecast - $forecastPeriod)' : ''} ${isGlobalDate ? '[GLOBAL DATE]' : ''}");
          } else {
            print("ℹ️ No price data found in batch for commodity $commodityId (${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? 'Unknown'})");
          }
        } catch (e) {
          print("⚠️ Error fetching price for $commodityId: $e");
        }
      
        allCommodities.add(commodityEntry);
      }      setState(() {
        // Store all commodities for reference
        commodities = allCommodities.where((commodity) {
          final itemId = commodity['id'].toString();
          return displayedCommoditiesIds.contains(itemId);
        }).toList();

        for (String favorite in favoriteCommodities) {
          if (!displayedCommoditiesIds.contains(favorite)) {
            displayedCommoditiesIds.add(favorite);
          }
        }
        
        filteredCommodities = _applyFilter(commodities, allCommodities);
        
        // Apply sorting to maintain the selected sort option
        _applySorting();
        
        // Debug log the commodity data
        if (kDebugMode) {
          DebugHelper.printCommodityDebug(
            commodities: commodities,
            displayedCommoditiesIds: displayedCommoditiesIds,
            filteredCommodities: filteredCommodities,
            globalPriceDate: globalPriceDate
          );
        }
      });
      
    // Cache data after successful fetch      await DataCache.saveCommodities(commodities);
      await DataCache.saveFilteredCommodities(filteredCommodities);
      await DataCache.saveSelectedForecast(selectedForecast);
      await DataCache.saveGlobalPriceDate(globalPriceDate);
      
      // Save forecast start date if applicable
      if (selectedForecast != "Now" && forecastStartDate.isNotEmpty) {
        await DataCache.saveForecastStartDate(forecastStartDate);
      }
      
      print("✅ Saved commodity data to cache");      // Save forecast data to specific forecast cache for all periods (including "Now")
      // But don't include sort/filter settings since they're now global
      final forecastData = {
        'commodities': commodities,
        'filteredCommodities': filteredCommodities,
        'globalPriceDate': globalPriceDate,
        'forecastStartDate': forecastStartDate,
      };
      
      await ForecastCacheManager.saveForecastData(selectedForecast, forecastData);
      print("✅ Saved forecast data to forecast-specific cache for $selectedForecast");
      
      // Verify the cache was saved
      final savedCache = await ForecastCacheManager.getCachedForecastData(selectedForecast);
      if (savedCache != null) {
        print("✅ Verified forecast cache exists for $selectedForecast containing ${savedCache['commodities']?.length ?? 0} commodities");
      } else {
        print("⚠️ Failed to verify forecast cache for $selectedForecast");
      }
    } catch (e) {
      print("❌ Error fetching commodities: $e");
    }
  }

  // Load displayed commodities from SharedPreferences
  Future<void> loadDisplayedCommodities() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCommodities = prefs.getStringList('displayedCommodities');
    setState(() {
      if (storedCommodities != null) {
        displayedCommoditiesIds = storedCommodities;
        filteredCommodities = commodities
            .where((commodity) => displayedCommoditiesIds.contains(commodity['id'].toString()))
            .toList();
      }
    });
  }

  // Save displayed commodities to SharedPreferences
  Future<void> saveDisplayedCommodities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('displayedCommodities', displayedCommoditiesIds);
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteCommodities', favoriteCommodities);
    print("Favorites saved: $favoriteCommodities");
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFavorites = prefs.getStringList('favoriteCommodities');
    setState(() {
      if (storedFavorites != null) {
        favoriteCommodities = storedFavorites;
        for (String favorite in favoriteCommodities) {
          if (!displayedCommoditiesIds.contains(favorite)) {
            displayedCommoditiesIds.add(favorite);
          }
        }
      }
    });
    print("Favorites loaded: $favoriteCommodities");
  }  Future<void> saveState() async {
    // Save filter and sort globally (not forecast-specific)
    // Always save actual values including "None" for both filter and sort
    final filterToSave = selectedFilter ?? "None";
    final sortToSave = selectedSort ?? "None";
    
    await DataCache.saveSelectedFilter(filterToSave, "global");
    await DataCache.saveSelectedSort(sortToSave);
    
    // Update state with the values we just saved
    setState(() {
      selectedFilter = filterToSave;
      selectedSort = sortToSave;
    });
    
    print("State saved globally: Filter = $filterToSave, Sort = $sortToSave");
  }Future<void> loadState() async {
    try {
      // Load filter globally
      final filterValue = await DataCache.getSelectedFilter("global");
      
      // For backwards compatibility, if no global filter is found,
      // try the old style filter setting
      String? finalFilterValue = filterValue;
      if (finalFilterValue == null) {
        final prefs = await SharedPreferences.getInstance();
        final legacyFilter = prefs.getString('selectedFilter');
        finalFilterValue = legacyFilter; // Always use the actual value including "None"
        
        // If we found a legacy filter, migrate it to the new global system
        if (finalFilterValue != null) {
          await DataCache.saveSelectedFilter(finalFilterValue, "global");
          print("✅ Migrated legacy filter setting to global filter system");
        }
      }
      
      // Load sort from DataCache
      final sortValue = await DataCache.getSelectedSort();
      
      setState(() {
        selectedFilter = finalFilterValue;
        selectedSort = sortValue;
        
        // Ensure we always have valid values (at least "None")
        if (selectedFilter == null) {
          selectedFilter = "None";
          DataCache.saveSelectedFilter("None", "global");
        }
        
        if (selectedSort == null) {
          selectedSort = "None";
          DataCache.saveSelectedSort("None");
        }
      });      
      print("State loaded globally: Filter = $selectedFilter, Sort = $selectedSort");
      
      // Apply the loaded filter and sort
      _applyFiltersOnly();
    } catch (e) {
      print("Error loading state: $e");
    }
  }

  void showFavoritesDialog() {
    String favoritesSearchText = ""; // Local search text for this dialog

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Select Favorites"),
              content: _buildDialogContent(
                favoritesSearchText,
                favoriteCommodities,
                (itemId, isChecked) {
                  setState(() {
                    if (isChecked) {
                      favoriteCommodities.add(itemId);
                    } else {
                      favoriteCommodities.remove(itemId);
                    }
                  });
                  saveFavorites();
                },
                (newSearchText) {
                  setState(() {
                    favoritesSearchText = newSearchText; // Update the search text
                  });
                },
              ),
              actions: [                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Apply filters to update the UI with new favorites
                    _applyFiltersOnly();
                    setState(() {}); // Force UI update
                  },
                  child: Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAddDialog() {
    String addCommoditiesSearchText = ""; // Local search text for this dialog
    List<String> tempSelectedItems = List.from(displayedCommoditiesIds); // Temporary list to track changes

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Manage Commodities"),
              content: _buildDialogContent(
                addCommoditiesSearchText,
                tempSelectedItems,
                (itemId, isChecked) {
                  setState(() {
                    if (isChecked) {
                      tempSelectedItems.add(itemId);
                    } else {
                      tempSelectedItems.remove(itemId);
                    }
                  });
                },
                (newSearchText) {
                  setState(() {
                    addCommoditiesSearchText = newSearchText; // Update the search text
                  });
                },
              ),
              actions: [                TextButton(
                  onPressed: () async {
                    setState(() {
                      displayedCommoditiesIds = List.from(tempSelectedItems); // Save changes to the main list
                    });
                    await saveDisplayedCommodities(); // Persist changes
                    
                    // Apply filters to reflect changes without fetching from Firestore
                    _applyFiltersOnly();
                    
                    Navigator.pop(context); // Close the dialog
                  },
                  child: Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // Dispose of the focus node to avoid memory leaks
    _searchFocusNode.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // Get commodities to display based on search text
    List<Map<String, dynamic>> displayedCommodities = searchText.isEmpty
        ? filteredCommodities
        : filteredCommodities.where((commodity) {
            // Get the display name from the mapping and then check if it contains the search text
            final displayName = COMMODITY_ID_TO_DISPLAY[commodity['id'].toString()]?['display_name'] ?? "";
            return displayName.toLowerCase().contains(searchText.toLowerCase());
          }).toList();
    
    // Always apply sorting to displayed commodities to maintain consistent ordering
    if (selectedSort != null && displayedCommodities.isNotEmpty) {
      _applySortToList(displayedCommodities);
    }return GestureDetector(
      onTap: () {
        if (isSearching) {
          setState(() {
            // Only unfocus the search field but keep the text and search visible
            isSearching = false;
            _searchFocusNode.unfocus();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kGreen,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectedCommodityId != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: AssetImage(
                    'assets/commodity_images/${getCommodityImage(selectedCommodityId!)}',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(                  child: Text(
                    COMMODITY_ID_TO_DISPLAY[selectedCommodityId!]?['display_name'] ?? "Unknown",
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: kBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[                Text(
                  "Select a Commodity",
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: kBlue,
                  ),
                ),
              ],
            ],
          ),
          actions: [            if (isSearching || searchText.isNotEmpty)
              Container(
                width: MediaQuery.of(context).size.width * 0.3,
                margin: EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: kBlue, fontSize: 16),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kBlue),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: kBlue),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.only(left: 8, bottom: 2, right: searchText.isNotEmpty ? 20 : 0),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(color: kBlue, fontSize: 16),
                    ),
                    if (searchText.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            searchText = '';
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          child: Icon(Icons.clear, color: kBlue, size: 16),
                        ),
                      ),
                  ],
                ),
              )
            else
              // Search button only (no refresh buttons)
              IconButton(
                icon: Icon(Icons.search, color: kBlue),
                onPressed: () {
                  setState(() {
                    isSearching = true; // Activate the search bar
                  });
                  _searchFocusNode.requestFocus(); // Automatically focus the search bar
                },
              ),
          ],        ),
        body: Stack(
          children: [
            Column(              children: [              // Global date display - centered
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.center,                  child: Text(
                    globalPriceDate.isEmpty 
                        ? "Updating price data..." 
                        : selectedForecast == "Now"
                            ? "Latest Price Watch Data: $globalPriceDate"
                            : selectedForecast == "Next Week"
                                ? forecastStartDate.isEmpty
                                    ? "Forecast Prices for Next Week"
                                    : "Forecast Prices for this Week (Starting $forecastStartDate)"
                                : forecastStartDate.isEmpty
                                    ? "Forecast Prices for Two Weeks"
                                    : "Forecast Prices Next Week (Starting $forecastStartDate)",
                    style: TextStyle(
                      color: kBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // No space or margin between containers
                Container(                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Adjusted padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: kPink.withOpacity(0.6),
                        blurRadius: 12,
                        offset: Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,                    children: [                      Container(
                        height: 230, // Return to more rectangular dimensions
                        width: MediaQuery.of(context).size.width * 0.9, // Use almost the full width
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, const Color(0xFFF8F8FF)],
                          ),
                    
                        ),
                        child: selectedCommodityId == null
                            ? Center(child: Text("Select a commodity to see price graph"))
                            : FutureBuilder<List<Map<String, dynamic>>>(
                                future: firestoreService.fetchWeeklyPrices(selectedCommodityId!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return Center(
                                      child: Text(
                                        "No price data available",
                                        style: TextStyle(fontSize: 14, color: Colors.grey),
                                      )
                                    );
                                  }

                                  // Filter for actual prices (is_forecast = false)
                                  final actualPrices = snapshot.data!
                                      .where((p) => p['is_forecast'] == false)
                                      .toList();
                                  
                                  if (actualPrices.isEmpty) {
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "No actual price data available",
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Column(
                                            children: [
                                              Text(
                                                "Latest price: -",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: kBlue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                "As of: -",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: kBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }                                  // Sort by end_date to find the most recent price
                                  actualPrices.sort((a, b) {
                                    final aDate = a['end_date'] as Timestamp;
                                    final bDate = b['end_date'] as Timestamp;
                                    return bDate.compareTo(aDate); // Sort descending (most recent first)
                                  });
                                  
                                  // Prepare the display prices based on selected forecast view
                                  List<Map<String, dynamic>> displayPrices = [];
                                    if (selectedForecast == "Now") {
                                    // For "Now", show past two weeks of actual prices
                                    // Sort all actual prices by date (ascending)
                                    actualPrices.sort((a, b) {
                                      final aDate = a['end_date'] as Timestamp;
                                      final bDate = b['end_date'] as Timestamp;
                                      return aDate.compareTo(bDate); // Sort ascending for chart
                                    });
                                    
                                    // Take the most recent 2-4 actual prices to show the past two weeks
                                    if (actualPrices.length > 2) {
                                      displayPrices = actualPrices.sublist(actualPrices.length - 4 > 0 ? 
                                                                          actualPrices.length - 4 : 0);
                                    } else {
                                      displayPrices = List.from(actualPrices);
                                    }
                                    
                                    print("📈 NOW view: Showing ${displayPrices.length} actual prices");                                  } else if (selectedForecast == "Next Week") {
                                    // For "Next Week", we need to show ONLY latest non-forecast price TO the one-week forecast
                                    displayPrices = [];
                                    
                                    // Add the most recent actual price
                                    if (actualPrices.isNotEmpty) {
                                      displayPrices.add(actualPrices.first); // Already sorted to have most recent first
                                    }                                    
                                    
                                    // Find forecasts for the Next Week period
                                    final allForecasts = snapshot.data!.where((p) => p['is_forecast'] == true).toList();
                                    
                                    // Debug log all forecasts for this commodity
                                    print("\n🔎 DEBUG - All forecasts for commodity ${selectedCommodityId}:");
                                    for (var f in allForecasts) {
                                      print("  - Date: ${f['formatted_end_date']}, Period: ${f['forecast_period'] ?? 'MISSING'}, Price: ${f['price']}");
                                    }
                                    
                                    // Check if any forecast periods are missing
                                    bool needsForecastPeriodFix = false;
                                    for (var f in allForecasts) {
                                      if (f['forecast_period'] == null || f['forecast_period'].toString().isEmpty) {
                                        needsForecastPeriodFix = true;
                                        print("⚠️ Found forecast with missing period: ${f['formatted_end_date']}, Price: ${f['price']}");
                                      }
                                    }
                                    
                                    List<Map<String, dynamic>> nextWeekForecasts = [];
                                    
                                    // Fix missing forecast periods if needed
                                    if (needsForecastPeriodFix) {
                                      print("🔧 Fixing missing forecast periods for commodity ${selectedCommodityId}");
                                        // Use the forecast helper to fix periods
                                      final fixedData = FixHelper.ForecastDebugHelper.ensureForecastPeriodsExist(snapshot.data!);
                                      
                                      // Get the fixed forecasts
                                      final fixedForecasts = fixedData.where((p) => p['is_forecast'] == true).toList();
                                      
                                      // Get Next Week forecasts
                                      nextWeekForecasts = fixedForecasts.where((p) => 
                                          p['forecast_period'] == "Next Week").toList();
                                      
                                      print("📊 After fix: Found ${nextWeekForecasts.length} 'Next Week' forecasts");
                                    } else {
                                      // If no fix needed, get forecasts normally
                                      nextWeekForecasts = allForecasts.where((p) => 
                                          p['forecast_period'] == "Next Week").toList();
                                    }
                                    
                                    if (nextWeekForecasts.isNotEmpty) {
                                      // Sort by date (ascending)
                                      nextWeekForecasts.sort((a, b) {
                                        final aDate = a['end_date'] as Timestamp;
                                        final bDate = b['end_date'] as Timestamp;
                                        return aDate.compareTo(bDate);
                                      });
                                      
                                      // Add the Next Week forecast to the display
                                      displayPrices.add(nextWeekForecasts.first);
                                      
                                      print("📈 NEXT WEEK view: Added forecast price: ${nextWeekForecasts.first['price']} for ${nextWeekForecasts.first['formatted_end_date']}");
                                    } else {
                                      print("⚠️ No 'Next Week' forecasts found for this commodity");
                                    }
                                    
                                    print("📈 NEXT WEEK view: Showing ${displayPrices.length} prices (actual + Next Week forecast)");
                                  } else {
                                    // For "Two Weeks", we need to show latest -> Next Week -> Two Weeks (all three points)
                                    displayPrices = [];
                                    
                                    // Add the most recent actual price
                                    if (actualPrices.isNotEmpty) {
                                      displayPrices.add(actualPrices.first);
                                      print("📈 TWO WEEKS view: Added latest actual price: ${actualPrices.first['price']} for ${actualPrices.first['formatted_end_date']}");
                                    }
                                    
                                    // Get all forecast prices
                                    final allForecasts = snapshot.data!.where((p) => p['is_forecast'] == true).toList();
                                    
                                    // Check if any forecast periods are missing and fix them if needed
                                    bool needsForecastPeriodFix = false;
                                    for (var f in allForecasts) {
                                      final period = f['forecast_period'];
                                      if (period == null || period.toString().isEmpty) {
                                        needsForecastPeriodFix = true;
                                        print("⚠️ Found forecast with missing period: ${f['formatted_end_date']}, Price: ${f['price']}");
                                      }
                                    }
                                    
                                    List<Map<String, dynamic>> fixedData = snapshot.data!;
                                    List<Map<String, dynamic>> nextWeekForecasts = [];
                                    List<Map<String, dynamic>> twoWeeksForecasts = [];
                                    
                                    // Fix forecast periods if needed
                                    if (needsForecastPeriodFix) {                                      print("🔧 Fixing missing forecast periods for commodity ${selectedCommodityId}");
                                      fixedData = FixHelper.ForecastDebugHelper.ensureForecastPeriodsExist(snapshot.data!);
                                      
                                      // Get fixed forecasts
                                      final fixedForecasts = fixedData.where((p) => p['is_forecast'] == true).toList();
                                      
                                      // Get Next Week and Two Weeks forecasts
                                      nextWeekForecasts = fixedForecasts.where((p) => 
                                          p['forecast_period'] == "Next Week").toList();
                                      
                                      twoWeeksForecasts = fixedForecasts.where((p) => 
                                          p['forecast_period'] == "Two Weeks").toList();
                                      
                                      print("📊 After fix: Found ${nextWeekForecasts.length} Next Week and ${twoWeeksForecasts.length} Two Weeks forecasts");
                                    } else {
                                      // If no fix needed, get forecasts normally
                                      nextWeekForecasts = allForecasts.where((p) => 
                                          p['forecast_period'] == "Next Week").toList();
                                      
                                      twoWeeksForecasts = allForecasts.where((p) => 
                                          p['forecast_period'] == "Two Weeks").toList();
                                    }
                                    
                                    // First add Next Week forecast if available
                                    if (nextWeekForecasts.isNotEmpty) {
                                      // Sort by date (ascending)
                                      nextWeekForecasts.sort((a, b) {
                                        final aDate = a['end_date'] as Timestamp;
                                        final bDate = b['end_date'] as Timestamp;
                                        return aDate.compareTo(bDate);
                                      });
                                      
                                      // Add the Next Week forecast
                                      displayPrices.add(nextWeekForecasts.first);
                                      print("📈 TWO WEEKS view: Added Next Week forecast: ${nextWeekForecasts.first['price']} for ${nextWeekForecasts.first['formatted_end_date']}");
                                    }
                                    
                                    // Then add Two Weeks forecast if available
                                    if (twoWeeksForecasts.isNotEmpty) {
                                      // Sort by date (ascending)
                                      twoWeeksForecasts.sort((a, b) {
                                        final aDate = a['end_date'] as Timestamp;
                                        final bDate = b['end_date'] as Timestamp;
                                        return aDate.compareTo(bDate);
                                      });
                                      
                                      // Add the Two Weeks forecast
                                      displayPrices.add(twoWeeksForecasts.first);
                                      print("📈 TWO WEEKS view: Added Two Weeks forecast: ${twoWeeksForecasts.first['price']} for ${twoWeeksForecasts.first['formatted_end_date']}");
                                    }
                                    
                                    print("📈 TWO WEEKS view: Showing ${displayPrices.length} points (actual + Next Week + Two Weeks)");
                                  }

                                  // Create chart spots
                                  final spots = <FlSpot>[];
                                  for (int i = 0; i < displayPrices.length; i++) {
                                    final price = double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0;
                                    spots.add(FlSpot(i.toDouble(), price));
                                  }                                  return Column(
                                    children: [
                                      Expanded(
                                        child: LineChart(                                          LineChartData(
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: spots,
                                                isCurved: true,
                                                curveSmoothness: 0.35, // Smoother curve
                                                barWidth: 3.5,
                                                color: kPink,
                                                isStrokeCapRound: true,
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      kPink.withOpacity(0.3),
                                                      kPink.withOpacity(0.02),
                                                    ],
                                                  ),
                                                ),
                                                // Highlight points with different colors based on forecast
                                                dotData: FlDotData(
                                                  show: true,
                                                  getDotPainter: (spot, percent, barData, index) {
                                                    final isForecast = index < displayPrices.length ? 
                                                        displayPrices[index]['is_forecast'] == true : false;
                                                    
                                                    // Highlight the latest actual price (current point)
                                                    final isLatestActual = index < displayPrices.length &&
                                                        displayPrices[index]['is_forecast'] != true &&
                                                        (selectedForecast != "Now" || index == displayPrices.length - 1);
                                                        
                                                    Color dotColor = isForecast ? kPink : kBlue;
                                                    Color strokeColor = Colors.white;
                                                    double dotSize = isLatestActual ? 6.5 : 5.0;
                                                    double strokeWidth = isLatestActual ? 2.0 : 1.5;
                                                    
                                                    return FlDotCirclePainter(
                                                      radius: dotSize,
                                                      color: dotColor,
                                                      strokeWidth: strokeWidth,
                                                      strokeColor: strokeColor,
                                                    );
                                                  }
                                                ),
                                              ),
                                            ],                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  interval: 20,
                                                  getTitlesWidget: (value, meta) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(right: 6),
                                                      child: Text(
                                                        '₱${value.toInt()}',
                                                        style: TextStyle(
                                                          color: kBlue.withOpacity(0.7),
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 25, // Add more space for the titles
                                                  getTitlesWidget: (value, meta) {
                                                    int idx = value.toInt();
                                                    if (idx < 0 || idx >= displayPrices.length) return Container();
                                                      // Get date from timestamp
                                                    final endDate = displayPrices[idx]['end_date'] as Timestamp;
                                                    final date = endDate.toDate();
                                                    
                                                    // Different format if it's a forecast
                                                    final isForecast = displayPrices[idx]['is_forecast'] == true;
                                                    final forecastPeriod = displayPrices[idx]['forecast_period'] ?? '';                                                    // Create date text with indicator for what type of point it is
                                                    String dateText = "${date.month}/${date.day}";
                                                    if (selectedForecast != "Now") {
                                                      // For forecast views, add labels to identify points
                                                      if (idx == 0) {
                                                        dateText = "Last";
                                                      } else if (forecastPeriod == "Next Week") {
                                                        // Use Week 1 for the Two Weeks view to prevent overflow
                                                        dateText = selectedForecast == "Two Weeks" ? "Current" : "Next\nWeek";
                                                      } else if (forecastPeriod == "Two Weeks") {
                                                        dateText = "Next Week";
                                                      }
                                                    }
                                                    
                                                    // Only show every other date if more than 3 dates and in "Now" view
                                                    if (selectedForecast == "Now" && displayPrices.length > 3 && idx % 2 != 0 && idx != displayPrices.length - 1) {
                                                      return Container(); // Skip every other date
                                                    }
                                                      return Padding(
                                                      padding: const EdgeInsets.only(top: 6.0),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: isForecast ? kPink.withOpacity(0.1) : kBlue.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          dateText, 
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: isForecast ? kPink : kBlue,
                                                            fontWeight: isForecast ? FontWeight.w600 : FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  interval: 1,
                                                ),
                                              ),
                                              topTitles: AxisTitles(
                                                sideTitles: SideTitles(showTitles: false)
                                              ),
                                              rightTitles: AxisTitles(
                                                sideTitles: SideTitles(showTitles: false)
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: true,
                                              border: Border.all(color: Colors.grey.shade300, width: 1),
                                            ),
                                            gridData: FlGridData(
                                              show: true,
                                              horizontalInterval: 20,
                                              verticalInterval: 1,
                                              drawVerticalLine: true,
                                              checkToShowHorizontalLine: (value) => true,
                                              getDrawingHorizontalLine: (value) {
                                                return FlLine(
                                                  color: Colors.grey.shade200,
                                                  strokeWidth: value % 40 == 0 ? 1.2 : 0.8,
                                                  dashArray: value % 40 == 0 ? null : [3, 3],
                                                );
                                              },
                                              getDrawingVerticalLine: (value) {
                                                return FlLine(
                                                  color: Colors.grey.shade100,
                                                  strokeWidth: 0.8,
                                                  dashArray: [4, 4],
                                                );
                                              },
                                            ),                                            lineTouchData: LineTouchData(
                                              touchTooltipData: LineTouchTooltipData(
                                                tooltipBgColor: Colors.white,
                                                tooltipRoundedRadius: 10,
                                                tooltipBorder: BorderSide(color: Colors.grey.shade200, width: 1),
                                                tooltipPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                fitInsideHorizontally: true,
                                                getTooltipItems: (touchedSpots) {
                                                  return touchedSpots.map((touchedSpot) {
                                                    final idx = touchedSpot.x.toInt();
                                                    if (idx < 0 || idx >= displayPrices.length) {
                                                      return LineTooltipItem("", TextStyle());
                                                    }
                                                    
                                                    final price = touchedSpot.y;
                                                    final isForecast = displayPrices[idx]['is_forecast'] == true;
                                                    final timestamp = displayPrices[idx]['end_date'] as Timestamp;
                                                    final date = timestamp.toDate();
                                                    final dateText = "${date.month}/${date.day}/${date.year}";
                                                    
                                                    String forecastType = "";
                                                    String daysDifference = "";
                                                    
                                                    if (isForecast && displayPrices.length > 1 && idx > 0) {
                                                      // Determine which forecast period this is
                                                      forecastType = displayPrices[idx]['forecast_period'] ?? 'Forecast';
                                                      
                                                      // Calculate days difference between latest price and forecast
                                                      if (displayPrices[0]['end_date'] != null) {
                                                        final latestDate = (displayPrices[0]['end_date'] as Timestamp).toDate();
                                                        final difference = date.difference(latestDate).inDays;
                                                        daysDifference = " ($difference days from latest)";
                                                      }
                                                    }
                                                    
                                                    return LineTooltipItem(
                                                      "${isForecast ? '($forecastType)' : 'Latest'} ₱${price.toStringAsFixed(2)}\n$dateText${daysDifference}",
                                                      TextStyle(
                                                        color: isForecast ? kPink : kBlue,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),                                        margin: const EdgeInsets.only(top: 8.0),
                                        child: Column(
                                          children: [                                            Text(
                                              "Price Trend",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: kBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),                                            // Add specific price values when in forecast modes
                                            if (selectedForecast != "Now" && displayPrices.length > 1)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 5.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // For Two Weeks view, only show Latest and Two Weeks forecasts
                                                    if (selectedForecast == "Two Weeks")
                                                      for (int i = 0; i < displayPrices.length; i++)
                                                        if (i == 0 || displayPrices[i]['forecast_period'] == "Two Weeks")
                                                          Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Container(
                                                                  width: 8,
                                                                  height: 8,
                                                                  decoration: BoxDecoration(
                                                                    shape: BoxShape.circle,
                                                                    color: displayPrices[i]['is_forecast'] == true ? kPink : kBlue,
                                                                  ),
                                                                ),
                                                                SizedBox(width: 3),
                                                                Text(
                                                                  i == 0 
                                                                    ? "Latest: ₱${(double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0).toStringAsFixed(2)}"
                                                                    : displayPrices[i]['forecast_period'] == "Two Weeks"
                                                                      ? "Two Weeks: ₱${(double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0).toStringAsFixed(2)}"
                                                                      : "${displayPrices[i]['forecast_period'] ?? 'Forecast'}: ₱${(double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0).toStringAsFixed(2)}",
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: displayPrices[i]['is_forecast'] == true ? kPink : kBlue,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                    // For other views, show all forecast points
                                                    if (selectedForecast != "Two Weeks")
                                                      for (int i = 0; i < displayPrices.length; i++)
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Container(
                                                                width: 8,
                                                                height: 8,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  color: displayPrices[i]['is_forecast'] == true ? kPink : kBlue,
                                                                ),
                                                              ),
                                                              SizedBox(width: 3),
                                                              Text(
                                                                i == 0 
                                                                  ? "Latest: ₱${(double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0).toStringAsFixed(2)}"
                                                                  : "${displayPrices[i]['forecast_period'] ?? 'Forecast'}: ₱${(double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0).toStringAsFixed(2)}",
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: displayPrices[i]['is_forecast'] == true ? kPink : kBlue,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [                          Text(
                            "See:",
                            style: TextStyle(
                              fontFamily: 'Raleway',
                              fontWeight: FontWeight.bold,
                              color: kBlue,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8), // Space after "See:"
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _forecastButton("Now", displayText: "Last Week"),
                                  SizedBox(width: 8), // Reduced spacing between buttons
                                  _forecastButton("Next Week", displayText: "Current"),
                                  SizedBox(width: 8), // Reduced spacing between buttons
                                  _forecastButton("Two Weeks", displayText: "Next Week"),
                                ],
                              ),
                            ),
                          ),
                        ],                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Sort by Dropdown
                          Flexible(
                            flex: 1,
                            child: DropdownButton<String>(
                              value: selectedSort,
                              hint: Text(
                                "Sort by",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: kBlue,
                                  fontSize: 12,
                                ),
                              ),
                              items: [
                                "None",
                                "Name",
                                "Price (Low to High)",
                                "Price (High to Low)"
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: kBlue, // Match the color with "Filter by"
                                    ),
                                  ),
                                );
                              }).toList(),                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedSort = newValue;
                                  
                                  if (newValue == "None") {
                                    selectedSort = null;
                                    // Just reapply the filter without sorting
                                    filteredCommodities = List.from(commodities);
                                    _applyFiltersOnly();
                                  } else {
                                    // Apply the new sort to the filtered commodities
                                    _applySorting();
                                  }
                                  
                                  // Cache the sorted filtered commodities
                                  DataCache.saveFilteredCommodities(filteredCommodities);
                                  saveState(); // Save sort preference
                                });
                              },
                              dropdownColor: Colors.white, // Match the dropdown background color
                              isExpanded: true,
                              menuMaxHeight: 200, // Limit the dropdown height to make it scrollable
                            ),
                          ),
                          SizedBox(width: 8),
                          // Filter by Dropdown
                          Flexible(
                            flex: 1,
                            child: DropdownButton<String>(
                              value: selectedFilter,
                              hint: Text(
                                "Filter by",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: kBlue,
                                  fontSize: 12,
                                ),
                              ),
                              items: [
                                "None",
                                "Favorites",
                                "KADIWA RICE-FOR-ALL",
                                "IMPORTED COMMERCIAL RICE",
                                "LOCAL COMMERCE RICE",
                                "CORN",
                                "FISH",
                                "LIVESTOCK & POULTRY PRODUCTS",
                                "LOWLAND VEGETABLES",
                                "HIGHLAND VEGETABLES",
                                "SPICES",
                                "FRUITS",
                                "OTHER BASIC COMMODITIES"
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: kBlue, // Match the color with "Sort by"
                                    ),
                                  ),
                                );
                              }).toList(),                              onChanged: (String? newValue) {
                                setState(() {
                                  if (newValue == "None") {
                                    selectedFilter = null; // Reset to default
                                    filteredCommodities = List.from(commodities); // Show all commodities
                                  } else if (newValue == "Favorites") {
                                    selectedFilter = newValue;
                                    // Update the filter logic for "Favorites"
                                    filteredCommodities = commodities.where((commodity) {
                                      final commodityId = commodity['id'].toString();
                                      return favoriteCommodities.contains(commodityId);
                                    }).toList();
                                  } else {
                                    selectedFilter = newValue;
                                    // Update filter logic for commodity types - now using category
                                    filteredCommodities = commodities.where((commodity) {
                                      final commodityId = commodity['id'].toString();
                                      final category = COMMODITY_ID_TO_DISPLAY[commodityId]?['category']?.toLowerCase() ?? "";
                                      return category == newValue?.toLowerCase();
                                    }).toList();
                                  }
                                  
                                  // Cache filtered commodities after applying the filter
                                  DataCache.saveFilteredCommodities(filteredCommodities);
                                  saveState(); // Save the updated state
                                  print("Filtered Commodities after filter change: ${filteredCommodities.length}");
                                });
                              },
                              dropdownColor: Colors.white,
                              isExpanded: true,
                              menuMaxHeight: 200, // Limit the dropdown height to make it scrollable
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.star, color: kPink),
                            onPressed: showFavoritesDialog,
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: kPink),                            onPressed: showAddDialog,
                          ),
                        ],
                      ),                      // Total items count (minimal display)
                      Container(
                        padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Total: ${displayedCommodities.length}",
                          style: TextStyle(
                            fontSize: 8,
                            color: const Color.fromARGB(255, 131, 131, 131),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayedCommodities.isEmpty
                      ? Center(
                          child: Text(
                            "No commodities found.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 70),
                          itemCount: displayedCommodities.length,
                          itemBuilder: (context, index) {
                            final commodity = displayedCommodities[index];
                            final commodityId = commodity['id'].toString();

                            return GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  isHoldMode = true;
                                  heldCommodities.add(commodityId); // Use ID
                                  selectedCommodityId = null;
                                });
                              },
                              onTap: () {
                                if (isHoldMode) {
                                  setState(() {
                                    if (heldCommodities.contains(commodityId)) {
                                      heldCommodities.remove(commodityId);
                                      if (heldCommodities.isEmpty) {
                                        isHoldMode = false;
                                      }
                                    } else {
                                      heldCommodities.add(commodityId);
                                    }
                                  });
                                } else {                                  setState(() {
                                    if (selectedCommodityId == commodityId) {
                                      selectedCommodityId = null;
                                    } else {
                                      selectedCommodityId = commodityId;
                                      
                                      // Cache the selected commodity details to prevent price reset
                                      final selectedCommodity = filteredCommodities.firstWhere(
                                        (c) => c['id'].toString() == commodityId,
                                        orElse: () => commodities.firstWhere(
                                          (c) => c['id'].toString() == commodityId,
                                          orElse: () => {},
                                        ),
                                      );
                                      
                                      if (selectedCommodity.isNotEmpty) {
                                        DataCache.saveSelectedCommodityDetails(selectedCommodity);
                                      }
                                    }
                                  });
                                }
                              },
                              child: _buildCommodityItem(
                                commodity,
                                isSelected: selectedCommodityId == commodityId,
                                isHeld: heldCommodities.contains(commodityId),
                                index: index,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            if (isHoldMode)
              Positioned(
                top: 7, // Adjusted position to move closer to the bottom of the header
                right: 7, // Align to the right
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        heldCommodities.clear(); // Clear all selected commodities
                        isHoldMode = false; // Exit "hold mode"
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "Deselect All",
                        style: TextStyle(
                          color: kPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showTutorial)
              TutorialOverlay(
                onClose: _closeTutorial, // Ensure the close method is used
              ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(), // Use the reusable bottom navigation bar
      ),
    );
  }  Widget _forecastButton(String identifier, {String? displayText, double height = 25}) {
    final textToDisplay = displayText ?? identifier;
    
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 100, maxWidth: 130), // Increased min and max width
      child: SizedBox(
        height: height,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: selectedForecast == identifier ? kPink : kDivider),
            backgroundColor: selectedForecast == identifier ? kPink.withOpacity(0.2) : Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),          onPressed: () async {
            if (selectedForecast != identifier) {
              // Save current commodity selection before changing forecast
              final currentCommodityId = selectedCommodityId;
              // Save current sort and filter selections explicitly
              final currentSort = selectedSort;
              final currentFilter = selectedFilter;
              
              setState(() {
                selectedForecast = identifier;
                // Don't clear selections to preserve across forecast changes
                // selectedCommodityId, selectedFilter and selectedSort remain unchanged
              });
              
              // Explicitly save sort and filter preferences to cache
              if (currentSort != null) {
                await DataCache.saveSelectedSort(currentSort);
              }
              if (currentFilter != null) {
                await DataCache.saveSelectedFilter(currentFilter, "global");
              }
              
              // Explicitly save selected commodity details, if any
              if (currentCommodityId != null) {
                final selectedCommodity = filteredCommodities.firstWhere(
                  (c) => c['id'].toString() == currentCommodityId,
                  orElse: () => commodities.firstWhere(
                    (c) => c['id'].toString() == currentCommodityId,
                    orElse: () => {},
                  ),
                );
                
                if (selectedCommodity.isNotEmpty) {
                  await DataCache.saveSelectedCommodityDetails(selectedCommodity);
                }
              }
              
              // Save selected forecast to cache immediately
              await DataCache.saveSelectedForecast(identifier);
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPink),
                    ),
                  );
                }
              );
                try {
                // First check if we have valid cache for this forecast period
                final forecastCache = await ForecastCacheManager.getCachedForecastData(identifier);
                if (forecastCache != null) {
                  print("✅ Using cached forecast data for $identifier");
                  // Load from cache instead of fetching from Firestore
                  bool loadedFromCache = await _loadFromCache();
                  if (!loadedFromCache) {
                    // Only fetch from Firestore if cache loading failed
                    print("❌ Failed to load from forecast cache, fetching from Firestore");
                    await fetchCommodities();
                  } else {
                    print("✅ Successfully loaded from cache for forecast period: $identifier");
                    
                    // Make sure selected commodity is preserved after loading from cache
                    if (currentCommodityId != null) {
                      setState(() {
                        selectedCommodityId = currentCommodityId;
                      });
                      print("✅ Preserved selected commodity after forecast change: $currentCommodityId");
                    }
                  }
                } else {
                  // No valid cache for this forecast period, fetch from Firestore
                  print("🔄 No valid cache for $identifier, fetching from Firestore...");
                  await fetchCommodities();
                  
                  // Also preserve commodity selection after Firestore fetch
                  if (currentCommodityId != null) {
                    setState(() {
                      selectedCommodityId = currentCommodityId;
                    });
                    print("✅ Preserved selected commodity after Firestore fetch: $currentCommodityId");
                  }
                }
              } finally {
                // Hide loading indicator
                Navigator.of(context).pop();
              }
            }
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              textToDisplay,
              style: TextStyle(
                color: selectedForecast == identifier ? kPink : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),            ),
          ),
        ),
      ));
  }
  Widget _buildCommodityItem(Map<String, dynamic> commodity, {required bool isSelected, required bool isHeld, required int index}) {
    final String commodityId = commodity['id'].toString();
    
    // Use your mapping for display name and other details
    final display = COMMODITY_ID_TO_DISPLAY[commodityId] ?? {};
    final String displayName = display['display_name'] ?? "Unknown Commodity";
    // Unit is not directly used in this method but may be needed for tooltips elsewhere
    final String specification = display["specification"] ?? "-";
    final String category = display["category"] ?? "-";
    
    // Get the price and date
    final price = commodity['weekly_average_price'];
    final priceDate = commodity['price_date'] ?? '';
    final isForecast = commodity['is_forecast'] ?? false;
    
    // Handle empty price display
    final bool hasPriceData = price != null && price.toString().isNotEmpty && price != 0.0;
    final String formattedPrice = !hasPriceData 
        ? "-" 
        : (price is double) 
            ? price.toStringAsFixed(2) 
            : (double.tryParse(price.toString()) ?? 0.0).toStringAsFixed(2);
            
    // Check for last historical price (for "Now" view with no latest price)
    final bool hasHistoricalPrice = selectedForecast == "Now" && !hasPriceData && 
                          commodity['last_historical_price'] != null &&
                          commodity['last_historical_price'].toString().isNotEmpty &&
                          commodity['last_historical_price'] != 0.0;
                            final String historicalPrice = hasHistoricalPrice
      ? (commodity['last_historical_price'] is double)
          ? commodity['last_historical_price'].toStringAsFixed(2)
          : (double.tryParse(commodity['last_historical_price'].toString()) ?? 0.0).toStringAsFixed(2)
      : "-";

    // Alternate background color based on index
    final backgroundColor = index % 2 == 0 ? Colors.white : kAltGray;
    
    // Hide category when user filtered by a specific category (not "None" or "Favorites")
    final bool showCategory = selectedFilter == null || selectedFilter == "Favorites";

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: 100,
      decoration: BoxDecoration(
        gradient: isHeld
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [kPink, Color(0xFFFFE4E1)],
                stops: [0.0, 0.56],
              )
            : isSelected
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [kGreen, Color(0xFFEBF8BB)],
                    stops: [0.0, 0.56],
                  )
                : null,
        color: isSelected || isHeld ? null : backgroundColor,
        border: Border(
          top: BorderSide(color: kDivider),
          bottom: BorderSide(color: kDivider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Commodity image (re-added)
            CircleAvatar(
              backgroundImage: AssetImage(
                'assets/commodity_images/${getCommodityImage(commodityId)}',
              ),
              radius: 24,
            ),
            SizedBox(width: 12),
            // Commodity details (left side)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    specification,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showCategory) ...[
                    SizedBox(height: 4),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 5),
            // Price and date (right side)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hasPriceData 
                    ? "₱$formattedPrice" 
                    : (hasHistoricalPrice && selectedForecast == "Now") 
                      ? "₱$historicalPrice" 
                      : "₱-",
                  style: TextStyle(
                    fontWeight: (hasPriceData || (hasHistoricalPrice && selectedForecast == "Now")) ? FontWeight.w500 : FontWeight.normal, 
                    fontSize: 20,
                    color: (hasPriceData || (hasHistoricalPrice && selectedForecast == "Now")) ? null : Colors.grey
                  ),
                ),
                // Show data status
                if (!hasPriceData && !hasHistoricalPrice)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      selectedForecast != "Now" ? "Insufficient data" : "No data",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  )
                // Show forecast indicator or date
                else if (isForecast)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPink.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      "Forecast",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: kPink,
                      ),
                    ),
                  )                // Show date only for non-global prices in "Now" view
                else if (selectedForecast == "Now" && hasPriceData && priceDate.isNotEmpty && 
                        !(commodity['is_global_date'] ?? false))
                  Text(
                    "As of $priceDate",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  List<String> getAllCommodities() {
    List<String> allCommodities = [];
    COMMODITY_ID_TO_DISPLAY.forEach((id, details) {
      allCommodities.add(id);
    });
    return allCommodities;
  }  // Helper to apply filters
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> displayedCommodities,
      List<Map<String, dynamic>> allCommodities) {
    List<Map<String, dynamic>> result;
    
    if (selectedFilter == null || selectedFilter == "None") {
      result = List.from(displayedCommodities);
      // Ensure "None" is saved properly
      if (selectedFilter == null) {
        DataCache.saveSelectedFilter("None", "global");
        selectedFilter = "None";
      }
    } else if (selectedFilter == "Favorites") {
      result = allCommodities.where((commodity) {
        final commodityId = commodity['id'].toString();
        return favoriteCommodities.contains(commodityId);
      }).toList();
    } else {
      result = displayedCommodities.where((commodity) {
        final commodityId = commodity['id'].toString();
        final typeInfo = COMMODITY_ID_TO_DISPLAY[commodityId];
        if (typeInfo == null) return false;
        
        final category = typeInfo['category'] ?? "";
        return category.toLowerCase() == selectedFilter?.toLowerCase();
      }).toList();
    }
    
    // Apply the current sort setting to the filtered results
    if (selectedSort != null) {
      _applySortToList(result);
    }
    
    // Cache the filtered result after applying filter
    Future.microtask(() => DataCache.saveFilteredCommodities(result));
    
    return result;
   }
    // Helper function to apply the current sort to any list
  void _applySortToList(List<Map<String, dynamic>> listToSort) {
    // If sorting is explicitly set to "None" or null, handle accordingly
    if (selectedSort == null) {
      // Ensure "None" is saved properly
      DataCache.saveSelectedSort("None");
      selectedSort = "None";
      return; // Don't apply any sorting
    } else if (selectedSort == "None") {
      return; // Don't apply any sorting
    } else if (selectedSort == "Name") {
      listToSort.sort((a, b) {
        final nameA = COMMODITY_ID_TO_DISPLAY[a['id'].toString()]?['display_name'] ?? "";
        final nameB = COMMODITY_ID_TO_DISPLAY[b['id'].toString()]?['display_name'] ?? "";
        return nameA.compareTo(nameB);
      });
    } else if (selectedSort == "Price (Low to High)") {
      listToSort.sort((a, b) {
        double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
        double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
        return priceA.compareTo(priceB);
      });
    } else if (selectedSort == "Price (High to Low)") {
      listToSort.sort((a, b) {
        double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
        double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
        return priceB.compareTo(priceA);
      });
    }
  }

  // Fix the FutureBuilder closing in _buildDialogContent
  Widget _buildDialogContent(
      String searchText,
      List<String> selectedItems,
      Function(String, bool) onItemChanged,
      Function(String) onSearchChanged) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          // Search TextField
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search, color: kBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kBlue),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                onSearchChanged(value.toLowerCase());
              },
            ),
          ),
          SizedBox(height: 8),
          // Check/Uncheck All buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [              TextButton(
                onPressed: () {
                  // Use cached commodities instead of fetching from Firestore
                  final allCommodities = commodities.map((c) => c['id'].toString()).toList();
                    
                  for (String commodityId in allCommodities) {
                    if (!selectedItems.contains(commodityId)) {
                      onItemChanged(commodityId, true);
                    }
                  }
                },
                child: Text("Check All"),
              ),
              TextButton(
                onPressed: () {
                  List<String> itemsToRemove = List.from(selectedItems);
                  for (String item in itemsToRemove) {
                    onItemChanged(item, false);
                  }
                },
                child: Text("Uncheck All"),
              ),
            ],
          ),          Expanded(
            child: Builder(
              builder: (context) {
                // Use cached commodities instead of fetching from Firestore
                final cachedCommodityIds = commodities.map((c) => c['id'].toString()).toList();
                
                // Group commodities by category
                Map<String, List<String>> groupedCommodities = {};
                
                // Initialize with empty lists for each category to preserve order
                for (String category in COMMODITY_CATEGORIES) {
                  groupedCommodities[category] = [];
                }
                
                // Use the cached commodity IDs instead of Firestore docs
                for (String commodityId in cachedCommodityIds) {
                  final displayData = COMMODITY_ID_TO_DISPLAY[commodityId];
                  
                  if (displayData == null) continue;
                  
                  final category = displayData['category'] ?? "Other";
                  
                  // Skip items that don't match search
                  if (searchText.isNotEmpty) {
                    final displayName = displayData['display_name'] ?? "";
                    if (!displayName.toLowerCase().contains(searchText.toLowerCase())) {
                      continue;
                    }
                  }
                  
                  if (!groupedCommodities.containsKey(category)) {
                    groupedCommodities[category] = [];
                  }
                  
                  groupedCommodities[category]!.add(commodityId);
                }
                
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: COMMODITY_CATEGORIES.where((category) => 
                      groupedCommodities[category] != null && 
                      groupedCommodities[category]!.isNotEmpty).map((category) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              category, // Category name
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kBlue,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          ...groupedCommodities[category]!.map((commodityId) {
                            final displayData = COMMODITY_ID_TO_DISPLAY[commodityId] ?? {};
                            final displayName = displayData['display_name'] ?? "Unknown";
                            final specification = displayData['specification'] != "-" 
                                ? " (${displayData['specification']})" 
                                : "";
                            
                            return CheckboxListTile(
                              title: Text(displayName + specification),
                              dense: true,
                              value: selectedItems.contains(commodityId),
                              onChanged: (bool? value) {
                                onItemChanged(commodityId, value ?? false);
                              },
                            );
                          }).toList(),
                          Divider(),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Method to manually refresh data from Firestore
  Future<void> refreshDataFromFirestore() async {
    print("🔄 Manual refresh requested");
    setState(() {
      _dataInitialized = false; // Force a full refresh
    });
    
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPink),
          ),
        );
      }
    );
    
    try {
      // Force cache invalidation
      await DataCache.invalidateCache();
      
      // Fetch fresh data
      await fetchCommodities();
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data refreshed successfully'),
          backgroundColor: kGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh data: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}