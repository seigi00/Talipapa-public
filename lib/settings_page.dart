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
  bool isFilipino = false; // Language toggle state
  
  @override
  void initState() {
    super.initState();
    _loadLanguagePreference(); // Load language preference
  }
  
  // Load language preference
  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        isFilipino = prefs.getBool('isFilipino') ?? false;
        AppLanguage.isFilipino = isFilipino; // Update global language setting
      });
      print("✅ Loaded language preference: ${isFilipino ? 'Filipino' : 'English'}");
    } catch (e) {
      print("❌ Error loading language preference: $e");
    }
  }
  
  // Save language preference
  Future<void> _saveLanguagePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFilipino', value);
      setState(() {
        isFilipino = value;
        AppLanguage.isFilipino = value; // Update global language setting
      });
      print("✅ Saved language preference: ${value ? 'Filipino' : 'English'}");
    } catch (e) {
      print("❌ Error saving language preference: $e");
    }
  }
  Future<void> resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved data
    
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
    final backgroundColor = kGreen;
    final textColor = kBlue;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Center(
          child: Text(
            AppLanguage.get('settings'),
            style: TextStyle(color: textColor, fontFamily: 'Raleway', fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Removed the Notifications Toggle
            
            // Clear Cache Button
            ListTile(              title: Row(
                children: [
                  Text(
                    AppLanguage.get('clear_cache'),
                    style: TextStyle(fontSize: 18, color: kBlue),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.cleaning_services, color: kBlue, size: 20),
                ],
              ),
              subtitle: Text(
                AppLanguage.get('clear_cache_warning'),
                style: TextStyle(fontSize: 12, color: kBlue.withOpacity(0.7)),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                print("🧹 Cleared all cache!");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLanguage.get('cache_cleared')),
                    backgroundColor: Colors.red[700],
                  ),
                );
              },
            ),

            // Manually Fetch Data
            ListTile(
              title: Text(
                AppLanguage.get('manually_fetch'),
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              subtitle: Text(
                AppLanguage.get('fetch_description'),
                style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
              ),
              onTap: () {
                manuallyFetchData();
              },
            ),
            
            // Language Toggle
            ListTile(
              title: Text(
                AppLanguage.get('language'),
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              subtitle: Text(
                isFilipino ? AppLanguage.get('filipino') : AppLanguage.get('english'),
                style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
              ),
              trailing: Switch(
                value: isFilipino,
                activeColor: kPink,  // Changed to kPink for better visibility
                activeTrackColor: kPink.withOpacity(0.3),
                inactiveThumbColor: kBlue,
                inactiveTrackColor: kBlue.withOpacity(0.1),
                onChanged: (bool value) {
                  _saveLanguagePreference(value);
                  // Rebuild this screen only to apply language changes
                  setState(() {});
                },
              ),
            ),
            
            //Removed Reset Preferences
            ListTile(
              title: Text(
                AppLanguage.get('view_tutorial'),
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => TutorialOverlay(
                    onClose: () => Navigator.of(context).pop(),
                    showFromSettings: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(),
    );
  }
}