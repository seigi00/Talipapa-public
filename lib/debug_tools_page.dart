import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';
import 'utils/commodity_debug_tool.dart';
import 'custom_bottom_navbar.dart';

class DebugToolsPage extends StatefulWidget {
  @override
  _DebugToolsPageState createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _unknownCommodities = [];
  String _debugMessage = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kGreen,
        title: Text(
          "Debug Tools",
          style: TextStyle(color: kBlue, fontFamily: 'Raleway', fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug Actions Section
                  Text(
                    "Commodity Debugging",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Find Unknown Commodities Button
                  ElevatedButton.icon(
                    icon: Icon(Icons.search, color: Colors.white),
                    label: Text(
                      "Find Unknown Commodities",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPink,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _findUnknownCommodities,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Identifies commodities missing from the COMMODITY_ID_TO_DISPLAY map",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Missing Entry Button
                  ElevatedButton.icon(
                    icon: Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      "Check for Missing Entry 5973eecf-ee85-4d1b-9d2d-a15f918bae0f",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _checkMissingEntry,
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Results section
                  if (_debugMessage.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kLightGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBlue.withOpacity(0.2)),
                      ),
                      child: Text(
                        _debugMessage,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Results List
                  if (_unknownCommodities.isNotEmpty) ...[
                    Text(
                      "Unknown Commodities (${_unknownCommodities.length}):",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _unknownCommodities.length,
                        itemBuilder: (context, index) {
                          final commodity = _unknownCommodities[index];
                          final id = commodity['id'];
                          final data = commodity['data'] as Map<String, dynamic>;
                          final name = data['name'] ?? 'No name available';
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                id,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                "Name: $name\nData: ${data.toString()}",
                                style: TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: CustomBottomNavBar(),
    );
  }

  // Debug method to find unknown commodities
  Future<void> _findUnknownCommodities() async {
    setState(() {
      _isLoading = true;
      _debugMessage = "Searching for unknown commodities...";
      _unknownCommodities = [];
    });
    
    try {
      final unknownCommodities = await CommodityDebugTool.findUnknownCommodities();
      
      setState(() {
        _unknownCommodities = unknownCommodities;
        _isLoading = false;
        
        if (unknownCommodities.isEmpty) {
          _debugMessage = "✅ No unknown commodities found in the database.";
        } else {
          _debugMessage = "⚠️ Found ${unknownCommodities.length} unknown commodities in the database.";
        }
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugMessage = "❌ Error finding unknown commodities: $e";
      });
      print("❌ Error finding unknown commodities: $e");
    }
  }

  // Check if the specific entry exists now
  Future<void> _checkMissingEntry() async {
    final String targetId = "5973eecf-ee85-4d1b-9d2d-a15f918bae0f";
    
    setState(() {
      _isLoading = true;
      _debugMessage = "Checking for commodity ID: $targetId";
    });
    
    try {
      // Check if entry exists in COMMODITY_ID_TO_DISPLAY
      final bool existsInMap = COMMODITY_ID_TO_DISPLAY.containsKey(targetId);
      
      // Check if exists in Firestore
      bool existsInFirestore = false;
      final doc = await FirebaseFirestore.instance.collection('commodities').doc(targetId).get();
      existsInFirestore = doc.exists;
      
      setState(() {
        _isLoading = false;
        if (existsInMap) {
          _debugMessage = "✅ Commodity $targetId exists in COMMODITY_ID_TO_DISPLAY map.\n"
                         "Display name: ${COMMODITY_ID_TO_DISPLAY[targetId]?['display_name']}\n"
                         "Category: ${COMMODITY_ID_TO_DISPLAY[targetId]?['category']}\n"
                         "Specification: ${COMMODITY_ID_TO_DISPLAY[targetId]?['specification']}\n"
                         "Unit: ${COMMODITY_ID_TO_DISPLAY[targetId]?['unit']}\n\n"
                         "Exists in Firestore: ${existsInFirestore ? 'Yes' : 'No'}";
        } else {
          _debugMessage = "❌ Commodity $targetId DOES NOT exist in COMMODITY_ID_TO_DISPLAY map.\n"
                         "Exists in Firestore: ${existsInFirestore ? 'Yes' : 'No'}";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugMessage = "❌ Error checking commodity entry: $e";
      });
      print("❌ Error checking commodity entry: $e");
    }
  }
}
