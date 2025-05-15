import 'package:Talipapa/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'custom_bottom_navbar.dart'; // Import the custom bottom navigation bar
import 'package:shared_preferences/shared_preferences.dart';

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
    );
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
        centerTitle: true,
        title: Center( // Center the "Settings" header horizontally
          child: Text(
            "Settings",
            style: TextStyle(color: textColor, fontFamily: 'CourierPrime', fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Toggle
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

            // Reset Data
            ListTile(
              title: Text(
                "Reset Data",
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