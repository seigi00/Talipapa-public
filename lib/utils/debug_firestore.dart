import 'package:cloud_firestore/cloud_firestore.dart';

// A utility class to help debug Firestore connection and permission issues
class FirestoreDebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test read access to the commodities collection
  static Future<Map<String, dynamic>> testCommoditiesAccess() async {
    try {
      print("🔍 Testing read access to 'commodities' collection...");
      final snapshot = await _firestore.collection('commodities').limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        print("✅ Access granted to 'commodities' collection, but no documents found");
        return {
          'success': true,
          'message': 'Access granted to commodities collection, but no documents found',
          'empty': true
        };
      } else {
        print("✅ Successfully read from 'commodities' collection");
        return {
          'success': true,
          'message': 'Successfully read from commodities collection',
          'empty': false
        };
      }
    } catch (e) {
      print("❌ Error accessing 'commodities' collection: $e");
      final isPermissionDenied = e.toString().contains("permission-denied");
      
      if (isPermissionDenied) {
        print("⚠️ PERMISSION DENIED when accessing commodities collection");
        print("⚠️ Check your Firestore security rules to ensure they allow read access");
      }
      
      return {
        'success': false,
        'message': 'Error accessing commodities collection: $e',
        'isPermissionDenied': isPermissionDenied
      };
    }
  }

  // Test read access to the price_entries collection
  static Future<Map<String, dynamic>> testPriceEntriesAccess() async {
    try {
      print("🔍 Testing read access to 'price_entries' collection...");
      final snapshot = await _firestore.collection('price_entries').limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        print("✅ Access granted to 'price_entries' collection, but no documents found");
        return {
          'success': true,
          'message': 'Access granted to price_entries collection, but no documents found',
          'empty': true
        };
      } else {
        print("✅ Successfully read from 'price_entries' collection");
        return {
          'success': true,
          'message': 'Successfully read from price_entries collection',
          'empty': false
        };
      }
    } catch (e) {
      print("❌ Error accessing 'price_entries' collection: $e");
      final isPermissionDenied = e.toString().contains("permission-denied");
      
      if (isPermissionDenied) {
        print("⚠️ PERMISSION DENIED when accessing price_entries collection");
        print("⚠️ Check your Firestore security rules to ensure they allow read access");
      }
      
      return {
        'success': false,
        'message': 'Error accessing price_entries collection: $e',
        'isPermissionDenied': isPermissionDenied
      };
    }
  }

  // Run both access tests
  static Future<Map<String, dynamic>> testAllAccess() async {
    final commoditiesResult = await testCommoditiesAccess();
    final priceEntriesResult = await testPriceEntriesAccess();
    
    final allSuccess = commoditiesResult['success'] && priceEntriesResult['success'];
    
    if (allSuccess) {
      print("✅ All collections can be accessed successfully");
    } else {
      print("❌ Some collections have access issues:");
      if (!commoditiesResult['success']) {
        print("  - Commodities: ${commoditiesResult['message']}");
      }
      if (!priceEntriesResult['success']) {
        print("  - Price Entries: ${priceEntriesResult['message']}");
      }
    }
    
    return {
      'success': allSuccess,
      'commodities': commoditiesResult,
      'price_entries': priceEntriesResult
    };
  }
  
  // Display suggested Firestore rules for this app
  static void printSuggestedRules() {
    print("""
✨ Suggested Firestore Rules for Talipapa App ✨

service cloud.firestore {
  match /databases/{database}/documents {
    // Allow anyone to read commodities collection
    match /commodities/{document=**} {
      allow read: if true;  // Public read access
      allow write: if false; // No public write access
    }
    
    // Allow anyone to read price_entries collection
    match /price_entries/{document=**} {
      allow read: if true;  // Public read access
      allow write: if false; // No public write access
    }
    
    // Default rule - deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
    """);
  }
}
