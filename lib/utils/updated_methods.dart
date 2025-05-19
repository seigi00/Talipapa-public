// This file contains updated methods for the commodities app

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

// Updated _forecastButton method that refreshes all commodity prices when clicked
Widget buildForecastButton(
  BuildContext context,
  String text, {
  required double height,
  required String selectedForecast,
  required Function(String) onForecastChanged,
  required Function(Map<String, dynamic>) onPricesUpdated,
  required firestoreService,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(minWidth: 100, maxWidth: 130),
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
          // Update the selected forecast period
          onForecastChanged(text);
          
          // Update all commodity prices based on the selected forecast period
          try {
            // Fetch the latest prices with the selected forecast period
            final Map<String, dynamic> latestPricesData = await firestoreService.fetchAllLatestPrices(
              forecastPeriod: text
            );
            
            // Pass the price data to the parent widget to update the UI
            onPricesUpdated(latestPricesData);
            
            print("✅ Updated prices with forecast period: $text");
          } catch (e) {
            print("❌ Error updating prices with forecast: $e");
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
            ),
          ),
        ),
      ),
    ),
  );
}

// Build the global date display widget with dynamic date
Widget buildGlobalDateDisplay(String globalPriceDate) {
  return Container(
    width: double.infinity,
    color: Colors.white,
    padding: EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      "As of: ${globalPriceDate.isNotEmpty ? globalPriceDate : 'Latest Available Data'}",
      style: TextStyle(
        color: kBlue,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// Helper method to check if a commodity date is different from global date
bool isOlderDate(String commodityDate, String globalDate) {
  if (commodityDate.isEmpty || 
      commodityDate == "No data" || 
      commodityDate == globalDate) {
    return false;
  }
  return true;
}