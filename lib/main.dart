// chatbot header too big. try center setting options, change font of settings text

import 'package:Talipapa/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Firestore
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Local imports
import 'chatbot_page.dart';
import 'settings_page.dart';
import 'custom_bottom_navbar.dart';
import 'constants.dart';
import 'image_mapping.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
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
  String selectedForecast = "One Week";
  String searchText = "";
  bool isSearching = false; // Track whether the search bar is active
  static bool _hasShownTutorial = false; // Static variable to persist across widget rebuilds
  bool showTutorial = false;
  int? selectedIndex;
  String? selectedSort;
  String? selectedFilter;
  String? selectedCommodity; // Track the selected commodity by its name
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // FocusNode for the search bar

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lists to store commodities
  List<Map<String, dynamic>> commodities = [];
  List<Map<String, dynamic>> filteredCommodities = [];
  List<String> favoriteCommodities = []; // List to store favorite commodities
  List<String> displayedCommoditiesNames = []; // List to manage displayed commodities
  bool isHoldMode = false; // Track whether the app is in "hold mode"
  Set<String> heldCommodities = {}; // Track selected commodities in "hold mode"

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    fetchCommodities(); // Fetch data when the widget is initialized
    loadDisplayedCommodities(); // Load displayed commodities from local storage
    loadFavorites(); // Load favorite commodities from persistent storage
    loadState(); // Load saved state (filters, sorts, etc.)
  }

  Future<void> _checkFirstLaunch() async {
    // If we've already shown the tutorial this session, don't show it again
    if (_hasShownTutorial) return;

    final prefs = await SharedPreferences.getInstance();
    bool shouldShowTutorial = prefs.getBool('showTutorial') ?? true;

    if (mounted && shouldShowTutorial) {
      setState(() {
        showTutorial = true;
        _hasShownTutorial = true; // Mark tutorial as shown for this session
      });
    }
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
        filteredCommodities = commodities.where((commodity) {
          final commodityName = commodity['commodity'].toString();
          final commodityType = commodity['commodity_type'].toString();
          if (commodityType.toLowerCase().contains('rice')) {
            return favoriteCommodities.contains('${commodityName}_${commodityType}');
          } else {
            return favoriteCommodities.contains(commodityName);
          }
        }).toList();
      } else {
        filteredCommodities = commodities.where((commodity) {
          final commodityType = commodity['commodity_type']?.toString().toLowerCase() ?? "";
          return commodityType == selectedFilter?.toLowerCase();
        }).toList();
      }
    });
  }

  // Fetch commodities from Firestore
  Future<void> fetchCommodities() async {
    try {
      final querySnapshot = await _firestore.collection('commodities').get();
      final allCommodities = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        // Filter by displayed commodities
        commodities = allCommodities.where((commodity) {
          final itemId = _getItemId(commodity);
          return displayedCommoditiesNames.contains(itemId);
        }).toList();

        // Automatically add favorited items to displayed commodities
        for (String favorite in favoriteCommodities) {
          if (!displayedCommoditiesNames.contains(favorite)) {
            displayedCommoditiesNames.add(favorite);
          }
        }

        // Apply the selected filter
        filteredCommodities = _applyFilter(commodities, allCommodities);
      });
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
        displayedCommoditiesNames = storedCommodities;
        filteredCommodities = commodities
            .where((commodity) => displayedCommoditiesNames.contains(commodity['commodity'].toString()))
            .toList();
      }
    });
  }

  // Save displayed commodities to SharedPreferences
  Future<void> saveDisplayedCommodities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('displayedCommodities', displayedCommoditiesNames);
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

        // Automatically add favorited items to displayed commodities
        for (String favorite in favoriteCommodities) {
          if (!displayedCommoditiesNames.contains(favorite)) {
            displayedCommoditiesNames.add(favorite);
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
      filteredCommodities = commodities.where((commodity) {
        final commodityName = commodity['commodity'].toString();
        final commodityType = commodity['commodity_type'].toString();
        if (commodityType.toLowerCase().contains('rice')) {
          return favoriteCommodities.contains('${commodityName}_${commodityType}');
        } else {
          return favoriteCommodities.contains(commodityName);
        }
      }).toList();
    } else {
      filteredCommodities = commodities.where((commodity) {
        final commodityType = commodity['commodity_type']?.toString().toLowerCase() ?? "";
        return commodityType == selectedFilter?.toLowerCase();
      }).toList();
    }

    if (selectedSort == "Name") {
      filteredCommodities.sort((a, b) => a['commodity'].toString().compareTo(b['commodity'].toString()));
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
  }

  void showAddDialog() {
    String addCommoditiesSearchText = ""; // Local search text for this dialog
    List<String> tempSelectedItems = List.from(displayedCommoditiesNames); // Temporary list to track changes

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
                      displayedCommoditiesNames = List.from(tempSelectedItems); // Save changes to the main list
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
  Widget build(BuildContext context) {
    final displayedCommodities = searchText.isEmpty
        ? filteredCommodities
        : filteredCommodities.where((commodity) {
            return commodity['commodity']
                .toString()
                .toLowerCase()
                .contains(searchText.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kGreen,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
          children: [
            if (selectedCommodity != null) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: AssetImage(
                  selectedCommodity != null
                      ? 'assets/commodity_images/${getCommodityImage(selectedCommodity!, commodityType: null, specification: null)}'
                      : 'assets/commodity_images/default_image.jpg',
                ),
              ),
              SizedBox(width: 8), // Add spacing between the image and the text
              Expanded( // Ensure the text doesn't overflow
                child: Text(
                  selectedCommodity!,
                  style: TextStyle(
                    fontFamily: 'CourierPrime',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: kBlue,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle long text gracefully
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
              width: MediaQuery.of(context).size.width * 0.3, // Adjusted width for the search bar
              margin: EdgeInsets.only(right: 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode, // Attach the FocusNode
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
                  contentPadding: EdgeInsets.only(left: 8, bottom: 2), // Adjust padding for better alignment
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                      child: Center(child: Text("Forecast Graph")),
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
                        SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _forecastButton("One Week"),
                                _forecastButton("Two Weeks"),
                                _forecastButton("One Month"),
                                _forecastButton("Two Months"),
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
                                  filteredCommodities = commodities.where((commodity) {
                                    final commodityName = commodity['commodity'].toString();
                                    final commodityType = commodity['commodity_type'].toString();
                                    if (commodityType.toLowerCase().contains('rice')) {
                                      return favoriteCommodities.contains('${commodityName}_${commodityType}');
                                    } else {
                                      return favoriteCommodities.contains(commodityName);
                                    }
                                  }).toList();
                                } else {
                                  selectedFilter = newValue;
                                  filteredCommodities = commodities.where((commodity) {
                                    final commodityType = commodity['commodity_type']?.toString().toLowerCase() ?? "";
                                    return commodityType == newValue?.toLowerCase();
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
                          return GestureDetector(
                            onLongPress: () {
                              setState(() {
                                isHoldMode = true; // Enter "hold mode"
                                heldCommodities.add(commodity['commodity']); // Add to held commodities
                                selectedCommodity = null; // Immediately unselect the commodity
                              });
                            },
                            onTap: () {
                              if (isHoldMode) {
                                setState(() {
                                  final commodityName = commodity['commodity'];
                                  if (heldCommodities.contains(commodityName)) {
                                    heldCommodities.remove(commodityName); // Deselect if already selected
                                    if (heldCommodities.isEmpty) {
                                      isHoldMode = false; // Exit "hold mode" if no commodities are selected
                                    }
                                  } else {
                                    heldCommodities.add(commodityName); // Select the commodity
                                  }
                                });
                              } else {
                                setState(() {
                                  if (selectedCommodity == commodity['commodity']) {
                                    selectedCommodity = null; // Unselect the commodity if it's already selected
                                  } else {
                                    selectedCommodity = commodity['commodity']; // Select the clicked commodity
                                  }
                                });
                              }
                            },
                            child: _buildCommodityItem(
                              commodity,
                              isSelected: selectedCommodity == commodity['commodity'],
                              isHeld: heldCommodities.contains(commodity['commodity']),
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
              onClose: () {
                setState(() {
                  showTutorial = false;
                });
              },
            ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(), // Use the reusable bottom navigation bar
    );
  }

  Widget _forecastButton(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: selectedForecast == text ? kPink : kDivider),
          backgroundColor: selectedForecast == text ? kPink.withOpacity(0.2) : Colors.transparent,
          minimumSize: Size(60, 28), // Adjusted size for a sleeker look
          padding: EdgeInsets.symmetric(horizontal: 8), // Reduced padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Rounded corners
          ),
        ),
        onPressed: () {
          setState(() {
            selectedForecast = text;
          });
        },
        child: Text(
          text,
          style: TextStyle(
            color: selectedForecast == text ? kPink : kBlue,
            fontSize: 12, // Smaller font size
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCommodityItem(Map<String, dynamic> commodity, {required bool isSelected, required bool isHeld, required int index}) {
    final String commodityName = commodity['commodity'] ?? "Unknown Commodity";
    final String unit = commodity['unit'] ?? ""; // e.g., "kg"
    final String commodityType = commodity['commodity_type'] ?? "Unknown Type";
    final String specification = (commodity['specification'] == null || 
                                  commodity['specification'].toString().trim().isEmpty || 
                                  commodity['specification'].toString().toLowerCase() == "none" || 
                                  commodity['specification'].toString().toLowerCase() == "nan")
        ? "-" // Replace empty, "None", or "NaN" with "-"
        : commodity['specification'].toString();

    // Alternate background color based on index
    final backgroundColor = index % 2 == 0 ? Colors.white : kAltGray;

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
        color: isSelected || isHeld ? null : backgroundColor, // Use alternating background color
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
              radius: 24, // Adjust the size of the image
              backgroundImage: AssetImage(
                'assets/commodity_images/${getCommodityImage(
                  commodityName,
                  commodityType: commodityType,
                  specification: specification,
                )}',
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
                      Text(
                        commodityName,
                        style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "($unit)", // Unit beside the name
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 12, // Smaller and less prominent
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Commodity type and specification logic
                  if (selectedFilter == null || selectedFilter == "None" || selectedFilter == "Favorites" || selectedFilter == "Filter by") ...[
                    Text(
                      "$commodityType · $specification",
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12, // Small font size
                        color: Colors.grey,
                      ),
                    ),
                  ] else ...[
                    Text(
                      specification,
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12, // Small font size
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 5),
            // Price
            Text(
              "₱${(commodity['weekly_average_price'] is double ? commodity['weekly_average_price'] : double.tryParse(commodity['weekly_average_price'].toString()) ?? 0.0).toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  List<String> getAllCommodities() {
    List<String> allCommodities = [];
    COMMODITY_TYPES.forEach((key, commodities) {
      for (String commodity in commodities) {
        if (key.toLowerCase().contains('rice')) {
          allCommodities.add('${commodity}_$key');
        } else {
          allCommodities.add(commodity);
        }
      }
    });
    return allCommodities;
  }

  // Helper to get a unique item ID (handles rice and non-rice items)
  String _getItemId(Map<String, dynamic> commodity) {
    final commodityName = commodity['commodity'].toString();
    final commodityType = commodity['commodity_type'].toString();
    return commodityType.toLowerCase().contains('rice')
        ? '${commodityName}_${commodityType}'
        : commodityName;
  }

  // Helper to apply filters
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> displayedCommodities,
      List<Map<String, dynamic>> allCommodities) {
    if (selectedFilter == null || selectedFilter == "None") {
      return List.from(displayedCommodities);
    } else if (selectedFilter == "Favorites") {
      return allCommodities.where((commodity) {
        final itemId = _getItemId(commodity);
        return favoriteCommodities.contains(itemId);
      }).toList();
    } else {
      return displayedCommodities.where((commodity) {
        final commodityType = commodity['commodity_type']?.toString().toLowerCase() ?? "";
        return commodityType == selectedFilter?.toLowerCase();
      }).toList();
    }
  }

  Widget _buildDialogContent(
      String searchText,
      List<String> selectedItems,
      void Function(String itemId, bool isChecked) onItemChanged,
      void Function(String newSearchText) onSearchChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.6,
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
                onSearchChanged(value.toLowerCase()); // Update the search text
              },
            ),
          ),
          SizedBox(height: 8),
          // Check/Uncheck All buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedItems.addAll(getAllCommodities());
                  });
                  onSearchChanged(searchText); // Refresh the filtered list
                },
                child: Text("Check All"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedItems.clear();
                  });
                  onSearchChanged(searchText); // Refresh the filtered list
                },
                child: Text("Uncheck All"),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: COMMODITY_TYPES.entries.map((entry) {
                  // Filter items based on the search text
                  final filteredItems = entry.value.where((item) {
                    final itemId = entry.key.toLowerCase().contains('rice')
                        ? '${item}_${entry.key}'
                        : item;

                    // Show items that match the search text
                    return item.toLowerCase().contains(searchText);
                  }).toList();

                  return filteredItems.isEmpty
                      ? SizedBox()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kBlue,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...filteredItems.map((item) {
                              final itemId = entry.key.toLowerCase().contains('rice')
                                  ? '${item}_${entry.key}'
                                  : item;

                              return CheckboxListTile(
                                title: Text(item),
                                dense: true,
                                value: selectedItems.contains(itemId),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedItems.add(itemId);
                                    } else {
                                      selectedItems.remove(itemId);
                                    }
                                  });
                                  onItemChanged(itemId, value ?? false);
                                },
                              );
                            }).toList(),
                            Divider(),
                          ],
                        );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}