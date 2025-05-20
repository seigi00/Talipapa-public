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
  Set<String> heldCommodities = {};
  String? deviceUUID;
  String globalPriceDate = ""; // Store the latest global price date
  bool _dataInitialized = false; // Track if data has been initialized
  bool _fetchInProgress = false; // Track if a fetch operation is in progress
  @override
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
    loadCachedDataAndFetch();
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
          print("✅ Loaded selected commodity from cache: $commodityId");
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
      
      // Load from forecast-specific cache for all periods including "Now"
      final forecastCache = await ForecastCacheManager.getCachedForecastData(forecastPeriod);
      if (forecastCache != null && forecastCache['commodities'] != null) {
        final List<dynamic> tempCommodities = forecastCache['commodities'];
        final List<Map<String, dynamic>> typedCommodities = tempCommodities.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Log forecast data to verify it's loaded correctly
        print("🔍 Loaded forecast commodities for $forecastPeriod: ${typedCommodities.length}");
        
        // Get filtered commodities from the cache
        final List<dynamic> tempFilteredCommodities = forecastCache['filteredCommodities'] ?? tempCommodities;
        final List<Map<String, dynamic>> typedFilteredCommodities = tempFilteredCommodities.map((item) => Map<String, dynamic>.from(item)).toList();
        
        // Update the UI
        final cachedSort = await DataCache.getSelectedSort();
        setState(() {
          commodities = typedCommodities;
          filteredCommodities = typedFilteredCommodities;
          globalPriceDate = forecastCache['globalPriceDate'] ?? "";
          selectedForecast = forecastPeriod;
          selectedSort = forecastCache['selectedSort'] ?? cachedSort;
        });
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
      
      // Try to load from cache first if forecast period changed
      if (_lastUsedForecast != selectedForecast) {
        ForecastCacheManager.hasForecastCache(selectedForecast).then((hasCachedForecast) {
          if (hasCachedForecast) {
            print("🔍 Found forecast data in cache for $selectedForecast, loading from cache");
            _loadFromCache().then((loadedFromCache) {
              if (!loadedFromCache) {
                // If cache loading failed, fetch from Firestore
                print("❌ Failed to load from forecast cache, fetching from Firestore");
                fetchCommodities();
              }
            });
          } else {
            // No cache for this forecast period, fetch from Firestore
            print("🔄 No forecast cache for $selectedForecast, fetching from Firestore");
            fetchCommodities();
          }
        });      } else {
        // First load without a forecast change - still check cache first
        print("🔄 First initialization - checking cache before fetching");
        _loadFromCache().then((loadedFromCache) {
          if (!loadedFromCache) {
            // If cache loading failed, fetch from Firestore
            print("❌ No valid cache found on first load, fetching from Firestore");
            fetchCommodities();
          } else {
            print("✅ Successfully loaded data from cache on first load");
          }
        });
      }
      
      _dataInitialized = true;
      _lastUsedForecast = selectedForecast;
    } else {
      // Just apply filter without fetching from Firestore
      _applyFiltersOnly();
    }
  }
  // Apply filters without fetching data from Firestore
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
  }
    // Apply sorting to the filtered list
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
    
    // Cache the sort preference
    DataCache.saveSelectedSort(selectedSort);
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
      
    // Cache data after successful fetch
      await DataCache.saveCommodities(commodities);
      await DataCache.saveFilteredCommodities(filteredCommodities);
      await DataCache.saveSelectedForecast(selectedForecast);
      await DataCache.saveGlobalPriceDate(globalPriceDate);
      print("✅ Saved commodity data to cache");
        // Save forecast data to specific forecast cache for all periods (including "Now")
      final forecastData = {
        'commodities': commodities,
        'filteredCommodities': filteredCommodities,
        'globalPriceDate': globalPriceDate,
        'selectedSort': selectedSort,
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
  }
  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedFilter', selectedFilter ?? "None");
    
    // Save sort using the DataCache method instead
    await DataCache.saveSelectedSort(selectedSort);
    
    print("State saved: Filter = $selectedFilter, Sort = $selectedSort");
  }  Future<void> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load filter from SharedPreferences (keeping compatibility with old implementation)
      final filterValue = prefs.getString('selectedFilter');
      
      // Load sort from DataCache (new implementation)
      final sortValue = await DataCache.getSelectedSort();
      
      setState(() {
        selectedFilter = filterValue == "None" ? null : filterValue;
        selectedSort = sortValue;
      });

      print("State loaded: Filter = $selectedFilter, Sort = $selectedSort");
      
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
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await fetchCommodities(); // Reload the list
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
              actions: [
                TextButton(
                  onPressed: () async {
                    setState(() {
                      displayedCommoditiesIds = List.from(tempSelectedItems); // Save changes to the main list
                    });
                    await saveDisplayedCommodities(); // Persist changes
                    await fetchCommodities(); // Reload the main list
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
                Expanded(
                  child: Text(
                    COMMODITY_ID_TO_DISPLAY[selectedCommodityId!]?['display_name'] ?? "Unknown",
                    style: TextStyle(
                      fontFamily: 'CourierPrime',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: kBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Text(
                  "Select a Commodity",
                  style: TextStyle(
                    fontFamily: 'CourierPrime',
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
            else              Row(
                children: [
                  // Refresh button
                  IconButton(
                    icon: Icon(Icons.refresh, color: kBlue),
                    onPressed: refreshDataFromFirestore,
                    tooltip: 'Refresh data',
                  ),
                  // Force refresh button - always fetch from Firestore regardless of cache
                  IconButton(
                    icon: Icon(Icons.update, color: kBlue),
                    onPressed: () {
                      // Clear the forecast cache for the current period first
                      ForecastCacheManager.invalidateForecastCache(selectedForecast).then((_) {
                        // Then fetch from Firestore
                        print("🔄 Forced refresh requested. Cache cleared for $selectedForecast");
                        fetchCommodities();
                      });
                    },
                    tooltip: 'Force refresh from Firestore',
                  ),
                  // Search button
                  IconButton(
                    icon: Icon(Icons.search, color: kBlue),
                    onPressed: () {
                      setState(() {
                        isSearching = true; // Activate the search bar
                      });
                      _searchFocusNode.requestFocus(); // Automatically focus the search bar
                    },
                  ),
                ],
              ),
          ],        ),
        body: Stack(
          children: [
            Column(
              children: [              // Global date display - left aligned
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    globalPriceDate.isEmpty 
                        ? "Updating price data..." 
                        : "Latest price watch data: $globalPriceDate",
                    style: TextStyle(
                      color: kBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
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
                        height: 200, // Return to more rectangular dimensions
                        width: MediaQuery.of(context).size.width * 0.95, // Use almost the full width
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, const Color(0xFFF8F8FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
                                  }

                                  // Sort by end_date to find the most recent price
                                  actualPrices.sort((a, b) {
                                    final aDate = a['end_date'] as Timestamp;
                                    final bDate = b['end_date'] as Timestamp;
                                    return bDate.compareTo(aDate); // Sort descending (most recent first)
                                  });
                                  
                                  // Get the most recent date and price
                                  final latestPrice = actualPrices.first; // First item after descending sort
                                  final price = latestPrice['price'] ?? 0.0;
                                  final formattedDate = latestPrice['formatted_end_date'] ?? "-";                                  // Prepare the display prices based on selected forecast view
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
                                  } else if (selectedForecast == "Next Week") {
                                    // For "Next Week", show current price and one-week forecast only
                                    displayPrices = [];
                                    
                                    // Add the most recent actual price
                                    if (actualPrices.isNotEmpty) {
                                      displayPrices.add(actualPrices.first); // Already sorted to have most recent first
                                    }
                                    
                                    // Add one-week forecast
                                    final oneWeekForecasts = snapshot.data!
                                        .where((p) => p['is_forecast'] == true)
                                        .toList();
                                        
                                    // Filter to get only "Next Week" forecasts
                                    final nextWeekForecasts = oneWeekForecasts.where((p) {
                                      // Check if forecast is for next week based on date
                                      if (p['end_date'] != null) {
                                        final forecastDate = (p['end_date'] as Timestamp).toDate();
                                        final today = DateTime.now();
                                        final daysDifference = forecastDate.difference(today).inDays;
                                        return daysDifference <= 7; // Within a week
                                      }
                                      return false;
                                    }).toList();
                                    
                                    if (nextWeekForecasts.isNotEmpty) {
                                      // Sort forecasts by date
                                      nextWeekForecasts.sort((a, b) {
                                        final aDate = a['end_date'] as Timestamp;
                                        final bDate = b['end_date'] as Timestamp;
                                        return aDate.compareTo(bDate);
                                      });
                                      
                                      // Add first next week forecast
                                      displayPrices.add(nextWeekForecasts.first);
                                    }
                                  } else {
                                    // For "Two Weeks", show current + one-week + two-weeks forecasts
                                    displayPrices = [];
                                    
                                    // Add the most recent actual price
                                    if (actualPrices.isNotEmpty) {
                                      displayPrices.add(actualPrices.first);
                                    }
                                    
                                    // Add all forecast prices
                                    final forecastPrices = snapshot.data!
                                        .where((p) => p['is_forecast'] == true)
                                        .toList();
                                    
                                    // Sort forecasts by date
                                    forecastPrices.sort((a, b) {
                                      final aDate = a['end_date'] as Timestamp;
                                      final bDate = b['end_date'] as Timestamp;
                                      return aDate.compareTo(bDate);
                                    });
                                    
                                    // Add forecasts (limit to 2 to show one-week and two-weeks)
                                    if (forecastPrices.isNotEmpty) {
                                      for (int i = 0; i < (forecastPrices.length > 2 ? 2 : forecastPrices.length); i++) {
                                        displayPrices.add(forecastPrices[i]);
                                      }                                    }
                                  }

                                  // Create chart spots
                                  final spots = <FlSpot>[];
                                  for (int i = 0; i < displayPrices.length; i++) {
                                    final price = double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0;
                                    spots.add(FlSpot(i.toDouble(), price));
                                  }                                  return Column(
                                    children: [                                      // Add "As of" date above the chart with nicer styling
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: kBlue.withOpacity(0.07),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: kBlue.withOpacity(0.2), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min, // Compact size for centered row
                                          children: [
                                            Icon(Icons.calendar_today, size: 12, color: kBlue.withOpacity(0.7)),
                                            SizedBox(width: 4),
                                            Text(
                                              "As of: $formattedDate",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: kBlue.withOpacity(0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
                                                    final dateText = "${date.month}/${date.day}";
                                                    
                                                    // Only show every other date if more than 3 dates
                                                    if (displayPrices.length > 3 && idx % 2 != 0 && idx != displayPrices.length - 1) {
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
                                                    
                                                    return LineTooltipItem(
                                                      "${isForecast ? '(Forecast) ' : ''}₱${price.toStringAsFixed(2)}\n$dateText",
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
                                        ),
                                        margin: const EdgeInsets.only(top: 8.0),                                        child: Column(
                                          children: [                                            Text(
                                              "${selectedForecast == 'Now' ? 'Latest price' : selectedForecast + ' price'}: ₱${price is double ? price.toStringAsFixed(2) : (double.tryParse(price.toString()) ?? 0.0).toStringAsFixed(2)}",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: kBlue,
                                                fontWeight: FontWeight.bold,
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
                        children: [
                          Text(
                            "See:",
                            style: TextStyle(
                              fontFamily: 'CourierPrime',
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
                                  _forecastButton("Now"),
                                  SizedBox(width: 8), // Reduced spacing between buttons
                                  _forecastButton("Next Week"),
                                  SizedBox(width: 8), // Reduced spacing between buttons
                                  _forecastButton("Two Weeks"),
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
  }  Widget _forecastButton(String text, {double height = 25}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 100, maxWidth: 130), // Increased min and max width
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
          ),
          onPressed: () async {
            if (selectedForecast != text) {
              setState(() {
                selectedForecast = text;
                // Clear selected commodity when forecast changes
                selectedCommodityId = null;
              });
              
              // Save selected forecast to cache immediately
              await DataCache.saveSelectedForecast(text);
              
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
                final forecastCache = await ForecastCacheManager.getCachedForecastData(text);
                if (forecastCache != null) {
                  print("✅ Using cached forecast data for $text");
                  // Load from cache instead of fetching from Firestore
                  bool loadedFromCache = await _loadFromCache();
                  if (!loadedFromCache) {
                    // Only fetch from Firestore if cache loading failed
                    print("❌ Failed to load from forecast cache, fetching from Firestore");
                    await fetchCommodities();
                  } else {
                    print("✅ Successfully loaded from cache for forecast period: $text");
                  }
                } else {
                  // No valid cache for this forecast period, fetch from Firestore
                  print("🔄 No valid cache for $text, fetching from Firestore...");
                  await fetchCommodities();
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
              text,
              style: TextStyle(
                color: selectedForecast == text ? kPink : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),            ),
          ),
        ),
      ),
    );
  }
  Widget _buildCommodityItem(Map<String, dynamic> commodity, {required bool isSelected, required bool isHeld, required int index}) {
    final String commodityId = commodity['id'].toString();
    
    // Use your mapping for display name and other details
    final display = COMMODITY_ID_TO_DISPLAY[commodityId] ?? {};
    final String displayName = display['display_name'] ?? "Unknown Commodity";
    final String unit = display['unit'] ?? "kg";
    final String specification = display["specification"] ?? "-";
    final String category = display["category"] ?? "-";

    // Get the price (handle different formats)
    final price = commodity['weekly_average_price'];
    final formattedPrice = (price is double) 
        ? price.toStringAsFixed(2) 
        : (double.tryParse(price.toString()) ?? 0.0).toStringAsFixed(2);

    // Alternate background color based on index
    final backgroundColor = index % 2 == 0 ? Colors.white : kAltGray;

    // Determine if we should show the category text
    // Hide category when user filtered by a specific category (not "None" or "Favorites")
    final bool showCategory = selectedFilter == null || selectedFilter == "Favorites";

    // Get forecast period for display
    final bool isForecast = commodity['is_forecast'] == true;
    final String forecastPeriod = commodity['forecast_period'] ?? "";
    final String forecastText = isForecast 
        ? (forecastPeriod.isNotEmpty ? "(Forecast - $forecastPeriod)" : "(Forecast)")
        : "";

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
            // Display the commodity image
            CircleAvatar(
              radius: 24,
              backgroundImage: AssetImage(
                'assets/commodity_images/${getCommodityImage(commodityId)}',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Commodity name with unit
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "($unit)",
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Display specification (and category if not filtered by category)
                  Text(
                    showCategory ? "$category · $specification" : specification,
                    style: TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 5),
            // Price and date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "₱$formattedPrice",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
                ),
                // Always show date for non-global date prices to ensure context for older prices
                if (commodity['price_date'] != null && 
                    commodity['price_date'].toString().isNotEmpty && 
                    commodity['is_global_date'] == false)
                  Text(
                    "as of: ${commodity['price_date']}",
                    style: TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                      color: kBlue,
                    ),
                  ),
                // Show forecast indicator with specific forecast period
                if (isForecast)
                  Text(
                    forecastText,
                    style: TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                      color: Colors.orange,
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
    if (selectedSort == "Name") {
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
            children: [
              TextButton(
                onPressed: () async {
                  final querySnapshot = await _firestore.collection('commodities').get();
                  final allCommodities = querySnapshot.docs
                    .map((doc) => doc.id)
                    .toList();
                    
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
          ),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('commodities').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No commodities found"));
                }
                
                // Group commodities by category
                Map<String, List<String>> groupedCommodities = {};
                
                // Initialize with empty lists for each category to preserve order
                for (String category in COMMODITY_CATEGORIES) {
                  groupedCommodities[category] = [];
                }
                
                // First, gather all the commodity IDs
                for (var doc in snapshot.data!.docs) {
                  final commodityId = doc.id;
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