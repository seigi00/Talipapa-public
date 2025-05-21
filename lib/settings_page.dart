import 'package:Talipapa/tutorial_overlay.dart';
import 'package:Talipapa/utils/data_cache.dart';
import 'package:Talipapa/utils/forecast_cache_manager.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'custom_bottom_navbar.dart'; // Import the custom bottom navigation bar
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Import HomePage to access fetchCommodities

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true; // Default value for notifications

  @override
  void initState() {
    super.initState();
    loadSettings(); // Load saved settings
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
  }

  Future<void> resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved data
    setState(() {
      notificationsEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("All data has been reset.")),
    );
  }

  void showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Reset"),
          content: Text("Are you sure you want to reset all data? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                resetData(); // Perform reset
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Reset"),
            ),
          ],
        );
      },
    );  }

  // Method to manually refresh data from Firestore  // Method to manually refresh data from Firestore
  Future<void> manuallyFetchData() async {
    print("🔄 Manual refresh requested from Settings");
    
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
      
      // Force clear all forecast caches
      await ForecastCacheManager.invalidateAllForecasts();
      
      // Clear dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Navigate to the HomePage with a reset flag
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomePage(forceRefresh: true),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = kGreen; // Static background color
    final textColor = kBlue; // Static text color

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,        title: Center( // Center the "Settings" header horizontally
          child: Text(
            "Settings",
            style: TextStyle(color: textColor, fontFamily: 'Raleway', fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [            // Notifications Toggle
            ListTile(
              title: Text(
                "Notifications",
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              trailing: Switch(
                value: notificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                  saveSettings(); // Save the updated setting
                },
              ),
            ),
            
            // Manually Fetch Data
            ListTile(
              title: Text(
                "Manually Fetch Data",
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              subtitle: Text(
                "If the list or graph is not loading properly, manually fetch data to reset cache",
                style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
              ),
              onTap: () {
                manuallyFetchData(); // Fetch fresh data
              },
            ),
            
            // Reset Data
            ListTile(
              title: Text(
                "Reset Preferences",
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              onTap: () {
                showResetConfirmationDialog(); // Show confirmation dialog
              },
            ),
            ListTile(
              title: Text(
                "View Tutorial",
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => TutorialOverlay(
                    onClose: () => Navigator.of(context).pop(),
                    showFromSettings: true, // Add this parameter to TutorialOverlay
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(), // Re-added the bottom navigation bar
    );
  }
}