// chatbot header too big. try center setting options, change font of settings text

import 'package:Talipapa/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:math'; // Add import for min function
// Firestore
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Local imports
import 'chatbot_page.dart';
import 'settings_page.dart';
import 'custom_bottom_navbar.dart';
import 'constants.dart'; // Make sure this contains COMMODITY_ID_TO_NAME
import 'image_mapping.dart';
import 'services/firestore_service.dart';
import 'utils/commodity_debug.dart'; // Add import for debug helper
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
  String? deviceUUID;  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && isSearching) {
        setState(() {
          isSearching = false;
        });
      }
    });
    
    // Initialize in proper sequence
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeUUID();
      await _checkFirstLaunch();
      await loadDisplayedCommodities(); // Load which commodities to display
      await loadFavorites(); // Load favorites
      await loadState(); // Load filter/sort state
      await fetchCommodities(); // Load actual commodity data
      
      print("✅ App initialization complete");
    } catch (e) {
      print("❌ Error during app initialization: $e");
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Fetch commodities and repopulate filteredCommodities
    fetchCommodities();

    // Repopulate filteredCommodities based on the current filter
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
    });
  }  // Fetch commodities from Firestore
  Future<void> fetchCommodities() async {
    try {
      print("🔄 Fetching commodities from Firestore...");
      
      // First, ensure displayedCommoditiesIds is properly initialized
      if (displayedCommoditiesIds.isEmpty) {
        print("⚠️ displayedCommoditiesIds is empty, initializing...");
        await _initializeWithAllCommodities();
      }

      // Fetch all commodity documents from Firestore
      final querySnapshot = await _firestore.collection('commodities').get();
      final List<Map<String, dynamic>> allCommodities = [];
      
      print("✅ Fetched ${querySnapshot.docs.length} commodities from Firestore");
      
      if (querySnapshot.docs.isEmpty) {
        print("⚠️ Warning: No commodities found in Firestore");
        return;
      }
      
      // Debug: Print first document
      if (querySnapshot.docs.isNotEmpty) {
        final firstDoc = querySnapshot.docs.first;
        print("🔍 Sample commodity document: ID=${firstDoc.id}, fields=${firstDoc.data().keys.join(', ')}");
      }
      
      // Process each commodity document
      for (var doc in querySnapshot.docs) {
        final commodityId = doc.id; // This is the UUID
        final commodityData = doc.data(); // Get the actual document data
          // Verify if this commodity has display info
        final hasDisplayData = COMMODITY_ID_TO_DISPLAY.containsKey(commodityId);
        if (!hasDisplayData) {
          print("⚠️ Warning: No display data for commodity $commodityId");
        } else {
          print("✓ Found display data for commodity $commodityId: ${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name']}");
        }
        
        // Create base commodity entry first (in case price fetching fails)
        Map<String, dynamic> commodityEntry = {
          'id': commodityId,
          'weekly_average_price': 0.0,
          'price_date': 'No data',
          // Add any other fields from the commodity document
          ...commodityData,
        };
        
        try {
          // Get the most recent price for this commodity
          final pricesSnapshot = await _firestore
              .collection('price_entries') // Make sure this collection name is correct
              .where('commodity_id', isEqualTo: commodityId)
              .where('is_forecast', isEqualTo: false)
              .orderBy('end_date', descending: true)
              .limit(1)
              .get();
        
          // Add price data if available
          if (pricesSnapshot.docs.isNotEmpty) {
            final priceData = pricesSnapshot.docs.first.data();
            final price = priceData['price'] ?? 0.0;
          
            // Format date for display
            final endDate = priceData['end_date'] as Timestamp?;
            final formattedDate = endDate != null ? 
                "${endDate.toDate().month}/${endDate.toDate().day}/${endDate.toDate().year}" : 
                "No date";
          
            // Update commodity entry with price info
            commodityEntry['weekly_average_price'] = price;
            commodityEntry['price_date'] = formattedDate;
            
            print("💰 Price data for ${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? commodityId}: ₱$price ($formattedDate)");
          } else {
            print("ℹ️ No price data for commodity $commodityId (${COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? 'Unknown'})");
          }
        } catch (e) {
          print("⚠️ Error fetching price for $commodityId: $e");
          
          // Display special message if it's a missing index error
          if (e.toString().contains("requires an index")) {
            print("📢 IMPORTANT: You need to create a Firestore index for price_entries collection.");
            print("📢 Please click the link in the error message above or go to Firebase console to create the required index.");
          }
        }
      
        allCommodities.add(commodityEntry);
      }      setState(() {
        // First, store all commodities for reference
        commodities = allCommodities;
        
        print("📊 Total commodities from Firestore: ${allCommodities.length}");
        print("📋 Total displayed IDs: ${displayedCommoditiesIds.length}");
        
        // DEBUG: List a few commodity IDs and names to verify data
        if (allCommodities.isNotEmpty) {
          print("\n📋 SAMPLE COMMODITIES:");
          for (int i = 0; i < min(3, allCommodities.length); i++) {
            final commodity = allCommodities[i];
            final id = commodity['id'];
            final displayInfo = COMMODITY_ID_TO_DISPLAY[id];
            final name = displayInfo?['display_name'] ?? 'Unknown';
            print("🔹 Commodity #$i: $name (ID: $id)");
          }
        }

        // Check which display IDs exist in our fetched data
        final Set<String> allCommodityIds = allCommodities.map((c) => c['id'].toString()).toSet();
        final List<String> missingIds = [];
        for (String id in displayedCommoditiesIds.take(5)) { // Check first 5
          if (!allCommodityIds.contains(id)) {
            missingIds.add(id);
          }
        }
        
        if (missingIds.isNotEmpty) {
          print("⚠️ Some display IDs not found in fetched data: ${missingIds.join(', ')}");
        }

        // Reset filteredCommodities if it's empty or null
        if (filteredCommodities.isEmpty && allCommodities.isNotEmpty) {
          filteredCommodities = List.from(allCommodities);
          print("🔄 Reset filteredCommodities with all commodities");
        }

        // Make sure favorites are included
        for (String favorite in favoriteCommodities) {
          if (!displayedCommoditiesIds.contains(favorite)) {
            displayedCommoditiesIds.add(favorite);
            print("⭐ Added favorite $favorite to displayed IDs");
          }
        }

        // Print out debug info
        print("📊 All fetched commodities: ${allCommodities.length}");
        print("📊 Displayed commodities: ${commodities.length}");
        print("📊 Displayed IDs: ${displayedCommoditiesIds.length}");
        
        // Sample a few commodities to verify content
        if (commodities.isNotEmpty) {
          final sampleCommodity = commodities.first;
          print("📝 Sample commodity: ID=${sampleCommodity['id']}, Price=${sampleCommodity['weekly_average_price']}");
        } else {
          print("⚠️ No commodities to display!");
        }
          
        // Apply filter to update displayed commodities
        filteredCommodities = _applyFilter(commodities, allCommodities);
        print("📊 Filtered commodities: ${filteredCommodities.length}");
        
        // Log detailed debug info
        if (commodities.isNotEmpty) {
          CommodityDebugHelper.logCommodityLoading(
            commodities: commodities,
            displayedIds: displayedCommoditiesIds,
            filteredCommodities: filteredCommodities,
          );
        }
        
        // Force UI update
        if (mounted) setState(() {});
      });
    } catch (e) {
      print("❌ Error fetching commodities: $e");
      // Print stack trace for debugging
      print(e.toString());
    }
  }
  // Load displayed commodities from SharedPreferences
  Future<void> loadDisplayedCommodities() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCommodities = prefs.getStringList('displayedCommodities');
    
    // Print debug info
    print("🔍 Loading displayed commodities from storage: ${storedCommodities?.length ?? 0}");
    
    if (storedCommodities != null && storedCommodities.isNotEmpty) {
      setState(() {
        displayedCommoditiesIds = storedCommodities;
      });
      
      // Debug print first few IDs
      if (displayedCommoditiesIds.isNotEmpty) {
        final previewIds = displayedCommoditiesIds.take(3).join(", ");
        print("📋 First 3 IDs: $previewIds");
      }
    } else {
      print("⚠️ No stored commodities found, initializing with all");
      // If nothing is stored, initialize with all commodity IDs
      await _initializeWithAllCommodities();
    }
  }  // Add this method to initialize with all commodities if empty
  Future<void> _initializeWithAllCommodities() async {
    try {
      print("🔄 Initializing all commodities list...");
      
      // Get all commodity IDs from Firestore
      final querySnapshot = await _firestore.collection('commodities').get();
      
      if (querySnapshot.docs.isEmpty) {
        print("⚠️ No commodities found in Firestore during initialization");
        return;
      }
      
      // Extract the IDs
      final allIds = querySnapshot.docs.map((doc) => doc.id).toList();
      
      // Store all commodity IDs
      setState(() {
        displayedCommoditiesIds = allIds;
      });
      
      // Save this list for next time
      await saveDisplayedCommodities();
      
      print("✅ Initialized with all commodities: ${displayedCommoditiesIds.length}");
      
      // Debug print some of the IDs
      if (displayedCommoditiesIds.isNotEmpty) {
        final previewIds = displayedCommoditiesIds.take(5).join(", ");
        print("📋 First 5 commodity IDs: $previewIds");
        
        // Verify mapping exists for IDs
        for (var id in displayedCommoditiesIds.take(5)) {
          final hasMapping = COMMODITY_ID_TO_DISPLAY.containsKey(id);
          final name = COMMODITY_ID_TO_DISPLAY[id]?['display_name'] ?? 'Unknown';
          print("ID: $id, Has mapping: $hasMapping, Name: $name");
        }
      }
    } catch (e) {
      print("❌ Error initializing commodities: $e");
      // Print stack trace for debugging
      print(e.toString());
    }
  }  // Save displayed commodities to SharedPreferences
  Future<void> saveDisplayedCommodities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Make sure displayedCommoditiesIds is not null or empty
      if (displayedCommoditiesIds.isEmpty) {
        print("⚠️ Warning: No commodities selected to save, initializing with defaults");
        await _initializeWithAllCommodities();
        return; // Return to avoid recursion
      }
      
      print("💾 Saving ${displayedCommoditiesIds.length} displayed commodities to preferences");
      
      // Check if we're trying to save empty IDs
      if (displayedCommoditiesIds.any((id) => id.isEmpty)) {
        print("⚠️ Warning: Some IDs are empty strings! Cleaning up...");
        displayedCommoditiesIds.removeWhere((id) => id.isEmpty);
      }
      
      await prefs.setStringList('displayedCommodities', displayedCommoditiesIds);
      
      // Debug check to verify data was saved
      final saved = prefs.getStringList('displayedCommodities');
      print("✅ Verified saved ${saved?.length ?? 0} commodities");
      
      if (saved != null && saved.isNotEmpty) {
        print("💾 First few saved IDs: ${saved.take(3).join(', ')}");
      }
    } catch (e) {
      print("❌ Error saving displayed commodities: $e");
      print(e.toString());
    }
  }

  Future<void> saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favoriteCommodities', favoriteCommodities);
      print("✅ Favorites saved: ${favoriteCommodities.length} items");
    } catch (e) {
      print("❌ Error saving favorites: $e");
    }
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
    await prefs.setString('selectedSort', selectedSort ?? "None");
    print("State saved: Filter = $selectedFilter, Sort = $selectedSort");
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFilter = prefs.getString('selectedFilter') == "None" ? null : prefs.getString('selectedFilter');
      selectedSort = prefs.getString('selectedSort') == "None" ? null : prefs.getString('selectedSort');
    });

    // Apply the loaded filter and sort
    if (selectedFilter == null) {
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

    print("State loaded: Filter = $selectedFilter, Sort = $selectedSort");
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
  }  void showAddDialog() {
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
                      if (!tempSelectedItems.contains(itemId)) {
                        tempSelectedItems.add(itemId);
                        print("➕ Added commodity $itemId to temp selection");
                      }
                    } else {
                      tempSelectedItems.remove(itemId);
                      print("➖ Removed commodity $itemId from temp selection");
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
                    try {
                      // Save changes to the main list and persist them
                      this.setState(() {
                        displayedCommoditiesIds = List.from(tempSelectedItems);
                      });
                      
                      print("✅ Saved ${displayedCommoditiesIds.length} commodity IDs from dialog");
                      
                      // If no commodities are selected, initialize with all
                      if (displayedCommoditiesIds.isEmpty) {
                        print("⚠️ No commodities selected, initializing with all");
                        await _initializeWithAllCommodities();
                      } else {
                        await saveDisplayedCommodities(); // Persist changes
                      }
                      
                      await fetchCommodities(); // Reload the main list
                      Navigator.pop(context); // Close the dialog
                    } catch (e) {
                      print("❌ Error saving commodities from dialog: $e");
                    }
                  },
                  child: Text("Save"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close without saving
                  },
                  child: Text("Cancel"),
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
    final displayedCommodities = searchText.isEmpty
        ? filteredCommodities
        : filteredCommodities.where((commodity) {
            // Get the display name from the mapping and then check if it contains the search text
            final displayName = COMMODITY_ID_TO_DISPLAY[commodity['id'].toString()]?['display_name'] ?? "";
            return displayName.toLowerCase().contains(searchText.toLowerCase());
          }).toList();

    return GestureDetector(
      onTap: () {
        if (isSearching) {
          setState(() {
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
          actions: [
            if (isSearching)
              Container(
                width: MediaQuery.of(context).size.width * 0.3,
                margin: EdgeInsets.only(right: 8),
                child: TextField(
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
                    contentPadding: EdgeInsets.only(left: 8, bottom: 2),
                  ),
                  style: TextStyle(color: kBlue, fontSize: 16),
                ),
              )
            else
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
        body: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: kPink.withOpacity(0.6),
                        blurRadius: 12,
                        offset: Offset(0, 12),
                      )
                    ],
                  ),                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (selectedCommodityId != null) ...[
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: firestoreService.fetchWeeklyPrices(selectedCommodityId!),
                          builder: (context, snapshot) {
                            String formattedDate = "Loading date...";
                            
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              // Find actual prices (not forecasts)
                              final actualPrices = snapshot.data!
                                  .where((price) => price['is_forecast'] != true)
                                  .toList();
                                  
                              if (actualPrices.isNotEmpty) {
                                // Sort by end_date to find the most recent price
                                actualPrices.sort((a, b) {
                                  final aDate = a['end_date'] as Timestamp;
                                  final bDate = b['end_date'] as Timestamp;
                                  return bDate.compareTo(aDate); // Sort descending
                                });
                                
                                formattedDate = actualPrices.first['formatted_end_date'] ?? "-";
                              }
                            }
                            
                            return Text(
                              "As of: $formattedDate",
                              style: TextStyle(
                                fontSize: 13,
                                color: kBlue,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 12),
                      ],
                      Container(
                        height: 200,
                        width: MediaQuery.of(context).size.width * 0.85,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: selectedCommodityId == null
                            ? Center(child: Text("Select a commodity to see price graph"))
                            : FutureBuilder<List<Map<String, dynamic>>>(
                                future: firestoreService.fetchWeeklyPrices(selectedCommodityId!),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  
                                  if (snapshot.hasError) {
                                    print("❌ Error: ${snapshot.error}");
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                                            SizedBox(height: 16),
                                            Text(
                                              "Error loading price data",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                            ),
                                            SizedBox(height: 8),
                                            if (snapshot.error.toString().contains("index")) 
                                              Text(
                                                "This may be due to a missing Firestore index. Please check the console for more information.",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                              )
                                          ],
                                        ),
                                      )
                                    );
                                  }
                                  
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return Center(
                                      child: Text(
                                        "No price data available",
                                        style: TextStyle(fontSize: 14, color: Colors.grey),
                                      )
                                    );
                                  }                                  // Filter for actual prices (is_forecast = false)
                                  final actualPrices = snapshot.data!
                                      .where((p) => p['is_forecast'] == false)
                                      .toList();
                                  
                                  print("📊 Found ${actualPrices.length} actual prices out of ${snapshot.data!.length} total");
                                  
                                  // Debug each price entry to check values
                                  if (actualPrices.isNotEmpty) {
                                    print("🔍 First few actual prices:");
                                    final samplesToShow = actualPrices.length > 3 ? 3 : actualPrices.length;
                                    for (int i = 0; i < samplesToShow; i++) {
                                      final entry = actualPrices[i];
                                      print("  [$i] Price: ${entry['price']}, Date: ${entry['formatted_end_date']}, Forecast: ${entry['is_forecast']}");
                                    }
                                  }
                                  
                                  if (actualPrices.isEmpty) {
                                    // Check if we have any data at all
                                    final anyData = snapshot.data!.isNotEmpty;
                                    
                                    if (anyData) {
                                      print("⚠️ Only forecast data available (${snapshot.data!.length} entries)");
                                      
                                      // Use the forecast data as fallback
                                      final forecastPrices = snapshot.data!
                                          .where((p) => p['is_forecast'] == true)
                                          .toList();
                                          
                                      if (forecastPrices.isNotEmpty) {
                                        // Sort forecast prices
                                        forecastPrices.sort((a, b) {
                                          final aDate = a['end_date'] as Timestamp;
                                          final bDate = b['end_date'] as Timestamp;
                                          return bDate.compareTo(aDate); // Most recent first
                                        });
                                        
                                        final latestForecast = forecastPrices.first;
                                        final forecastPrice = latestForecast['price'] ?? 0.0;
                                        final forecastDate = latestForecast['formatted_end_date'] ?? "-";
                                        
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "No actual price data available, showing forecast",
                                              style: TextStyle(fontSize: 14, color: Colors.grey),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    "Forecast price: ₱${_formatPrice(forecastPrice)}",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: kPink,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    "Forecast date: $forecastDate",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: kPink,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    }
                                    
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
                                  
                                  // Get the most recent date and price
                                  final latestPrice = actualPrices.first; // First item after descending sort
                                  final price = latestPrice['price'] ?? 0.0;
                                  final formattedDate = latestPrice['formatted_end_date'] ?? "-";
                                  
                                  // Print debug info
                                  print("📊 Latest price data for ${selectedCommodityId}: ₱$price ($formattedDate)");
                                  
                                  // Prepare the display prices based on selected forecast view
                                  List<Map<String, dynamic>> displayPrices = [];
                                    if (selectedForecast == "Now") {
                                    // For "Now" option, make sure we're using the most recent actual price
                                    print("🔍 'Now' option selected, using most recent actual price");
                                    print("📅 Date: ${latestPrice['formatted_end_date']}, Price: ${latestPrice['price']}");
                                    displayPrices = [latestPrice];
                                  } else if (selectedForecast == "Next Week") {
                                    // Show all available actual prices plus 1-week forecasts
                                    displayPrices = List.from(actualPrices);
                                    
                                    // Add forecast data if needed
                                    final forecastPrices = snapshot.data!
                                        .where((p) => p['is_forecast'] == true)
                                        .toList();
                                    
                                    if (forecastPrices.isNotEmpty) {
                                      displayPrices.addAll(forecastPrices);
                                      
                                      // Sort by date for proper display
                                      displayPrices.sort((a, b) {
                                        final aDate = a['start_date'] as Timestamp;
                                        final bDate = b['start_date'] as Timestamp;
                                        return aDate.compareTo(bDate); // Sort ascending for chart
                                      });
                                    }
                                  } else {
                                    // Two Weeks - show all prices plus forecasts
                                    displayPrices = List.from(snapshot.data!);
                                    
                                    // Sort by date for proper display
                                    displayPrices.sort((a, b) {
                                      final aDate = a['start_date'] as Timestamp;
                                      final bDate = b['start_date'] as Timestamp;
                                      return aDate.compareTo(bDate); // Sort ascending for chart
                                    });
                                  }

                                  // Create chart spots
                                  final spots = <FlSpot>[];
                                  for (int i = 0; i < displayPrices.length; i++) {
                                    final price = double.tryParse(displayPrices[i]['price'].toString()) ?? 0.0;
                                    spots.add(FlSpot(i.toDouble(), price));
                                  }

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: LineChart(
                                          LineChartData(
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: spots,
                                                isCurved: true,
                                                barWidth: 3,
                                                color: kPink,
                                                dotData: FlDotData(show: true),
                                              ),
                                            ],
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 30,
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (value, meta) {
                                                    int idx = value.toInt();
                                                    if (idx < 0 || idx >= displayPrices.length) return Container();
                                                    
                                                    // Get date from timestamp
                                                    final endDate = displayPrices[idx]['end_date'] as Timestamp;
                                                    final date = endDate.toDate();
                                                    
                                                    // Different format if it's a forecast
                                                    final isForecast = displayPrices[idx]['is_forecast'] == true;
                                                    final dateText = "${date.month}/${date.day}";
                                                    
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 5.0),
                                                      child: Text(
                                                        dateText, 
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isForecast ? kPink : kBlue,
                                                          fontWeight: isForecast ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  interval: 1,
                                                ),
                                              ),
                                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            borderData: FlBorderData(show: false),
                                            gridData: FlGridData(
                                              show: true,
                                              horizontalInterval: 20,
                                              drawVerticalLine: false,
                                            ),
                                            lineTouchData: LineTouchData(
                                              touchTooltipData: LineTouchTooltipData(
                                                tooltipBgColor: Colors.white.withOpacity(0.8),
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
                                      ),                                      Container(
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
                                        margin: const EdgeInsets.only(top: 8.0),
                                        child: Column(
                                          children: [                                            Text(
                                              "Latest price: ₱${_formatPrice(price)}",
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
                        ],
                      ),
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
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedSort = newValue;

                                  if (newValue == "Name") {
                                    filteredCommodities.sort((a, b) => a['commodity'].toString().compareTo(b['commodity'].toString()));
                                  } else if (newValue == "Price (Low to High)") {
                                    filteredCommodities.sort((a, b) {
                                      double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
                                      double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
                                      return priceA.compareTo(priceB);
                                    });
                                  } else if (newValue == "Price (High to Low)") {
                                    filteredCommodities.sort((a, b) {
                                      double priceA = double.tryParse(a['weekly_average_price'].toString()) ?? 0.0;
                                      double priceB = double.tryParse(b['weekly_average_price'].toString()) ?? 0.0;
                                      return priceB.compareTo(priceA);
                                    });
                                  } else {
                                    filteredCommodities = List.from(commodities);
                                    selectedSort = null;
                                  }
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
                              }).toList(),
                              onChanged: (String? newValue) {
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
                            icon: Icon(Icons.add, color: kPink),
                            onPressed: showAddDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),                Expanded(
                  child: displayedCommodities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "No commodities found",
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  await _initializeWithAllCommodities();
                                  await fetchCommodities();
                                },
                                child: Text("Reset Commodity List"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPink,
                                  foregroundColor: Colors.white,
                                ),
                              )
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Debug info bar
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              color: Colors.amber.withOpacity(0.2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total: ${displayedCommodities.length}", 
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text("IDs: ${displayedCommoditiesIds.length}",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text("All: ${commodities.length}",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Actual commodity list
                            Expanded(
                              child: ListView.builder(
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
                                      } else {
                                        setState(() {
                                          if (selectedCommodityId == commodityId) {
                                            selectedCommodityId = null;
                                          } else {
                                            selectedCommodityId = commodityId;
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
  }

  Widget _forecastButton(String text, {double height = 25}) {
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
          onPressed: () {
            setState(() {
              selectedForecast = text;
            });
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
          children: [            // Display the commodity image
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              backgroundImage: AssetImage(
                'assets/commodity_images/${getCommodityImage(commodityId)}',
              ),
              onBackgroundImageError: (e, stackTrace) {
                print("⚠️ Error loading image for commodity $commodityId: $e");
              },
              child: getCommodityImage(commodityId) == "default.jpg" ? 
                Text(displayName.substring(0, 1).toUpperCase()) : null,
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
            SizedBox(width: 5),            // Price and date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "₱$formattedPrice",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
                ),
                // Add price date
                Text(
                  commodity['price_date'] != null ? "as of ${commodity['price_date']}" : "",
                  style: TextStyle(
                    fontWeight: FontWeight.w300, 
                    fontSize: 11,
                    color: Colors.grey[600],
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
    COMMODITY_TYPES.forEach((key, commodities) {
      for (String commodity in (commodities as List<String>)) {
        if (key.toLowerCase().contains('rice')) {
          allCommodities.add('${commodity}_$key');
        } else {
          allCommodities.add(commodity);
        }
      }
    });
    return allCommodities;
  }
  // Helper to apply filters
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> displayedCommodities,
      List<Map<String, dynamic>> allCommodities) {
    
    print("🔍 Applying filter: $selectedFilter");
    
    if (selectedFilter == null || selectedFilter == "None") {
      print("🔍 No filter selected, showing all ${displayedCommodities.length} commodities");
      return List.from(displayedCommodities);
    } else if (selectedFilter == "Favorites") {
      final filtered = allCommodities.where((commodity) {
        final commodityId = commodity['id'].toString();
        return favoriteCommodities.contains(commodityId);
      }).toList();
      
      print("⭐ Showing ${filtered.length} favorites");
      return filtered;
    } else {
      // Filter by category
      final filtered = displayedCommodities.where((commodity) {
        final commodityId = commodity['id'].toString();
        final typeInfo = COMMODITY_ID_TO_DISPLAY[commodityId];
        if (typeInfo == null) {
          print("⚠️ No type info for commodity $commodityId");
          return false;
        }
        
        final category = typeInfo['category'] ?? "";
        final match = category.toLowerCase() == selectedFilter?.toLowerCase();
        
        // Debug mismatches
        if (!match && selectedFilter != null) {
          print("🔍 Category mismatch for ${typeInfo['display_name']}: '$category' vs filter: '$selectedFilter'");
        }
        
        return match;
      }).toList();
      
      print("🔍 Filter by category '$selectedFilter' resulted in ${filtered.length} commodities");
      
      if (filtered.isEmpty && displayedCommodities.isNotEmpty) {
        print("⚠️ WARNING: Filter resulted in empty list, checking case sensitivity...");
        
        // Try case-insensitive matching
        final caseInsensitiveFiltered = displayedCommodities.where((commodity) {
          final commodityId = commodity['id'].toString();
          final typeInfo = COMMODITY_ID_TO_DISPLAY[commodityId];
          if (typeInfo == null) return false;
          
          final category = typeInfo['category'] ?? "";
          return category.toLowerCase() == selectedFilter?.toLowerCase();
        }).toList();
        
        if (caseInsensitiveFiltered.isNotEmpty) {
          print("✅ Found ${caseInsensitiveFiltered.length} commodities with case-insensitive matching");
          return caseInsensitiveFiltered;
        }
        
        print("⚠️ Returning all commodities as fallback");
        return List.from(displayedCommodities); // Fallback to all 
      }
      
      return filtered;
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
                  try {
                    final querySnapshot = await _firestore.collection('commodities').get();
                    final allCommodities = querySnapshot.docs
                      .map((doc) => doc.id)
                      .toList();
                      
                    print("✅ Checking all ${allCommodities.length} commodities");
                    for (String commodityId in allCommodities) {
                      if (!selectedItems.contains(commodityId)) {
                        onItemChanged(commodityId, true);
                      }
                    }
                  } catch (e) {
                    print("❌ Error checking all commodities: $e");
                  }
                },
                child: Text("Check All", style: TextStyle(color: kBlue)),
              ),
              TextButton(
                onPressed: () {
                  try {
                    List<String> itemsToRemove = List.from(selectedItems);
                    print("✅ Removing all ${itemsToRemove.length} selected commodities");
                    for (String item in itemsToRemove) {
                      onItemChanged(item, false);
                    }
                  } catch (e) {
                    print("❌ Error unchecking all commodities: $e");
                  }
                },
                child: Text("Uncheck All", style: TextStyle(color: kBlue)),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 48),
                        SizedBox(height: 16),
                        Text("No commodities found", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
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
                  
                  if (displayData == null) {
                    print("⚠️ No display data for commodity: $commodityId");
                    continue;
                  }
                  
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
  // Helper method to format price as a string with 2 decimal places
  String _formatPrice(dynamic price) {
    print("💲 Formatting price: $price (type: ${price.runtimeType})");
    
    if (price is double) {
      return price.toStringAsFixed(2);
    } else if (price is num) {
      return price.toDouble().toStringAsFixed(2);
    } else {
      final formattedValue = (double.tryParse(price.toString()) ?? 0.0).toStringAsFixed(2);
      print("💲 Converted price to: $formattedValue");
      return formattedValue;
    }
  }
}