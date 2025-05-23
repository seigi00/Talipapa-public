import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG support
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'custom_bottom_navbar.dart';
import 'services/firestore_service.dart';
import 'package:http/http.dart' as http;

class ChatbotPage extends StatefulWidget {
  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  
  // Store the latest prices in state
  Map<String, dynamic> _latestPrices = {};
  Map<String, dynamic> _forecastedPrices = {};
  bool _isLoading = false;
  bool _isLoadingPrices = true;
  
  // Cached context data
  String _cachedContextData = "";
  
  // Cache keys
  static const String _latestPricesKey = 'chatbot_cached_latest_prices';
  static const String _forecastedPricesKey = 'chatbot_cached_forecasted_prices';
  static const String _contextDataKey = 'chatbot_cached_context_data';
  static const String _lastFetchTimeKey = 'chatbot_last_fetch_time';
  static const String _messagesHistoryKey = 'chatbot_messages_history';
  static const int _cacheDuration = 15; // 30 minutes by default

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMessageHistory();
  }

  // Load message history from SharedPreferences
  Future<void> _loadMessageHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString(_messagesHistoryKey);
      
      if (messagesJson != null && messagesJson.isNotEmpty) {
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        setState(() {
          _messages.clear();
          _messages.addAll(
            messagesList.map((message) => Map<String, String>.from(message)).toList()
          );
        });
        print('✅ Loaded ${_messages.length} messages from history');
      }
    } catch (e) {
      print('❌ Error loading message history: $e');
    }
  }

  // Save message history to SharedPreferences
  Future<void> _saveMessageHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = jsonEncode(_messages);
      await prefs.setString(_messagesHistoryKey, messagesJson);
      print('✅ Saved ${_messages.length} messages to history');
    } catch (e) {
      print('❌ Error saving message history: $e');
    }
  }

  // Clear message history (optional method for future use)
  Future<void> _clearMessageHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_messagesHistoryKey);
      setState(() {
        _messages.clear();
      });
      print('✅ Cleared message history');
    } catch (e) {
      print('❌ Error clearing message history: $e');
    }
  }

  // Load all data needed for the chatbot
  Future<void> _loadData() async {
    await _loadLatestPrices();
    _generateAndCacheContextData();
  }

  // Generate and cache the context data
  void _generateAndCacheContextData() {
    final contextData = _getContextData();
    _cachedContextData = contextData;
    _saveContextDataToCache(contextData);
    print('✅ Generated and cached context data in ChatbotPage');
  }
  
  // Load latest prices with caching
  Future<void> _loadLatestPrices() async {
    try {
      if (await _isCacheValid()) {
        final cachedPrices = await _getLatestPricesFromCache();
        final cachedForecastPrices = await _getForecastedPricesFromCache();
        final cachedContextData = await _getContextDataFromCache();
        
        if (cachedPrices != null && cachedPrices.isNotEmpty && 
            cachedForecastPrices != null && 
            cachedContextData != null && cachedContextData.isNotEmpty) {
          setState(() {
            _latestPrices = cachedPrices;
            _forecastedPrices = cachedForecastPrices;
            _cachedContextData = cachedContextData;
            _isLoadingPrices = false;
          });
          print('✅ Using cached data in ChatbotPage');
          return;
        }
      }
      
      // If cache is invalid or empty, fetch from Firestore
      print('🔄 Fetching latest prices from Firestore in ChatbotPage');
      final prices = await FirestoreService().fetchAllLatestPrices();
      final forecastPrices = await FirestoreService().fetchAllForecastedPricesForChatbot();
      
      // Extract and store the data we need for context generation
      final extractedPrices = _extractPriceData(prices);
      final extractedForecastPrices = _extractForecastData(forecastPrices);
      
      // Save to cache for future use
      await _saveLatestPricesToCache(extractedPrices);
      await _saveForecastedPricesToCache(extractedForecastPrices);
      
      setState(() {
        _latestPrices = prices;
        _forecastedPrices = forecastPrices;
        _isLoadingPrices = false;
      });
      
      // Generate and cache context data after loading prices
      _generateAndCacheContextData();
      
      print('✅ Fetched and cached data in ChatbotPage');
    } catch (e) {
      print('❌ Error loading data in ChatbotPage: $e');
      setState(() {
        _isLoadingPrices = false;
      });
    }
  }
  
  // Check if cache is valid (not expired)
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchTimeStr = prefs.getString(_lastFetchTimeKey);
      
      if (lastFetchTimeStr == null) {
        return false; // No cache exists yet
      }
      
      final lastFetchTime = DateTime.parse(lastFetchTimeStr);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastFetchTime).inMinutes;
      
      return difference < _cacheDuration;
    } catch (e) {
      print('❌ Error checking cache validity in ChatbotPage: $e');
      return false;
    }
  }
  
  // Convert Timestamp objects to strings for JSON serialization
  dynamic _convertForSerialization(dynamic value) {
    if (value is Map) {
      return Map.fromEntries(
        value.entries.map(
          (entry) => MapEntry(entry.key, _convertForSerialization(entry.value)),
        ),
      );
    } else if (value is List) {
      return value.map(_convertForSerialization).toList();
    } else if (value.toString().contains('Timestamp')) {
      // Handle Firebase Timestamp by converting to ISO string
      try {
        // Extract the seconds and nanoseconds if possible
        // This is a simple string manipulation approach since we can't directly access Timestamp methods
        return DateTime.now().toIso8601String(); // Fallback if extraction fails
      } catch (e) {
        return null;
      }
    }
    return value;
  }

  // Save latest prices to cache
  Future<void> _saveLatestPricesToCache(Map<String, dynamic> latestPrices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Timestamp objects before serializing
      final serializablePrices = _convertForSerialization(latestPrices);
      await prefs.setString(_latestPricesKey, jsonEncode(serializablePrices));
      await prefs.setString(_lastFetchTimeKey, DateTime.now().toIso8601String());
      print('✅ Saved latest prices to ChatbotPage cache');
    } catch (e) {
      print('❌ Error saving latest prices to ChatbotPage cache: $e');
    }
  }
  
  // Save forecasted prices to cache
  Future<void> _saveForecastedPricesToCache(Map<String, dynamic> forecastedPrices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Timestamp objects before serializing
      final serializablePrices = _convertForSerialization(forecastedPrices);
      await prefs.setString(_forecastedPricesKey, jsonEncode(serializablePrices));
      print('✅ Saved forecasted prices to ChatbotPage cache');
    } catch (e) {
      print('❌ Error saving forecasted prices to ChatbotPage cache: $e');
    }
  }
  
  // Save context data to cache
  Future<void> _saveContextDataToCache(String contextData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_contextDataKey, contextData);
      print('✅ Saved context data to ChatbotPage cache');
    } catch (e) {
      print('❌ Error saving context data to ChatbotPage cache: $e');
    }
  }
  
  // Get latest prices from cache
  Future<Map<String, dynamic>?> _getLatestPricesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_latestPricesKey);
      
      if (jsonData == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(jsonData));
    } catch (e) {
      print('❌ Error getting latest prices from ChatbotPage cache: $e');
      return null;
    }
  }
  
  // Get forecasted prices from cache
  Future<Map<String, dynamic>?> _getForecastedPricesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_forecastedPricesKey);
      
      if (jsonData == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(jsonData));
    } catch (e) {
      print('❌ Error getting forecasted prices from ChatbotPage cache: $e');
      return null;
    }
  }
  
  // Get context data from cache
  Future<String?> _getContextDataFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_contextDataKey);
    } catch (e) {
      print('❌ Error getting context data from ChatbotPage cache: $e');
      return null;
    }
  }

  // Build full prompt in mistral-v7 format
  String _buildPrompt() {
    final buffer = StringBuffer();

    buffer.writeln(
      '<|system|>\n'
      'You are Talipapa Chatbot, a helpful assistant in a mobile app that provides average market prices and forecasted prices of goods in the Philippines.\n\n'
      'Rules:\n'
      '- Always refer to yourself as "Talipapa Chatbot".\n'
      '- Only answer questions if you can find relevant **official** or **forecasted** price data in the context below.\n'
      '- Do not guess or make up answers. Only use the data provided.\n'
      '- If you are asked for forecasted prices without a specific commodity. You must not answer.\n'
      '- If there is no relevant data for a commodity, reply exactly with:\n'
      '  "Sorry, I don\'t have data about that item at the moment."\n'
      '- You may provide related insights such as recipes or suggestions *only if clearly related to the provided data*.\n\n'
      'Here is the data:\n'
      '$_cachedContextData\n'
    );



    for (var message in _messages) {
      if (message.containsKey('user')) {
        buffer.writeln('<|user|> ${message['user']}');
      } else if (message.containsKey('bot')) {
        buffer.writeln('<|assistant|> ${message['bot']}');
      }
    }

    buffer.write('<|assistant|>');
    return buffer.toString();
  }

  // Clean the assistant's raw response by removing </s> and similar tags
  String _cleanResponse(String raw) {
    return raw
    .replaceAll(RegExp(r'`'), '')
    .replaceAll(RegExp(r'</?s>'), '').trim();
  }

  // Get context data for the chatbot, including latest prices
  String _getContextData() {
    // Format the latest prices data for the chatbot
    final buffer = StringBuffer();
    buffer.writeln("LAST WEEK ACTUAL PRICES:");
    
    if (_latestPrices.isEmpty) {
      buffer.writeln("No price data is currently available.");
    } else {
      _latestPrices.forEach((commodityId, priceData) {
        
        // Get the commodity ID from the original data
        final id = priceData['original_data']['commodity_id'] ?? '';
        
        // Look up the display name from the constants
        String displayName = 'Unknown';
        String unit = 'kg'; // Default unit
        
        if (COMMODITY_ID_TO_DISPLAY.containsKey(id)) {
          // Get the display name from the mapping
          displayName = COMMODITY_ID_TO_DISPLAY[id]?['display_name'] ?? 'Unknown';
          
          // Get the unit if available
          unit = COMMODITY_ID_TO_DISPLAY[id]?['unit'] ?? 'kg';
        }
        
        final price = priceData['price'] ?? 0.0;
        final date = priceData['formatted_end_date'] ?? '';
        // Use the display name instead of the ID
        buffer.writeln("$displayName: ₱$price per $unit as of $date");
      });
    }
    
    //Add Forecasted Prices 
    buffer.writeln("FORECASTED PRICES:");
    
    if (_forecastedPrices.isEmpty) {
      buffer.writeln("No forecast price data is currently available.");
    } else {
      if (_forecastedPrices['success'] == true) {
        final Map<String, List<dynamic>> forecastedPrices =
            Map<String, List<dynamic>>.from(_forecastedPrices['forecast_data']);

        buffer.writeln("✅ Successfully organized forecast data for ${forecastedPrices.length} commodities");

        forecastedPrices.forEach((commodityId, forecasts) {
          final name = COMMODITY_ID_TO_DISPLAY[commodityId]?['display_name'] ?? 'Unknown';
          final specification = COMMODITY_ID_TO_DISPLAY[commodityId]?['specification'] ?? 'Unknown';
          final unit = COMMODITY_ID_TO_DISPLAY[commodityId]?['unit'] ?? 'Unknown';
          buffer.writeln("\nCommodity: $name");
          buffer.writeln("Specification: $specification");
          for (int i = 0; i < forecasts.length; i++) {
            final forecast = forecasts[i];
            final label = forecast['forecast_period'] ?? '';
            final date = forecast['formatted_end_date'] ?? '';
            final price = forecast['price'] ?? 0.0;

            buffer.writeln("🔸 $label: $date - ₱$price per $unit");
          }
        });
      } else {
        buffer.writeln("No forecast price data is currently available.");
      }
    }

    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"user": message});
      _isLoading = true;
    });

    // Save message history after adding user message
    await _saveMessageHistory();

    _messageController.clear();

    try {
      // Use the cached context data instead of generating it every time
      final prompt = _buildPrompt();

      final url = Uri.parse('https://llm.talipapa.shop/completions');
      final body = jsonEncode({
        "prompt": prompt,
        "cache_prompt": true,
        "max_tokens": 500,
        "top_p":0.9,
        "temperature": 0.9,
        // "repeat_penalty": 1.1,
        // "frequency_penalty": 0.2,
        // "presence_penalty": 0.3,
        "stop": ["<|user|>", "<|assistant|>"],
        "model": "capybarahermes-2.5-mistral-7b.Q4_K_M.gguf"
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['content'] as String?;

        if (rawText == null || rawText.isEmpty) {
          throw Exception('Empty response from server');
        }

        final botReply = _cleanResponse(rawText);
        setState(() {
          _messages.add({"bot": botReply});
          _isLoading = false;
        });

        // Save message history after adding bot response
        await _saveMessageHistory();
      } else {
        setState(() {
          _messages.add({
            "bot": "Server error: ${response.statusCode}. Please try again later."
          });
          _isLoading = false;
        });

        // Save message history after adding error message
        await _saveMessageHistory();
      }
    } catch (e) {
      setState(() {
        _messages.add({"bot": "Error fetching bot response: $e"});
        _isLoading = false;
      });

      // Save message history after adding error message
      await _saveMessageHistory();
    }
  }

  // Force refresh price data (useful for a refresh button)
  Future<void> _refreshPriceData() async {
    setState(() {
      _isLoadingPrices = true;
    });
    
    try {
      // Fetch fresh data from Firestore
      final prices = await FirestoreService().fetchAllLatestPrices();
      final forecastedprices = await FirestoreService().fetchAllForecastedPricesForChatbot();
      
      // Extract and store the data we need for context generation
      final extractedPrices = _extractPriceData(prices);
      final extractedForecastPrices = _extractForecastData(forecastedprices);
      
      // Save to cache for future use
      await _saveLatestPricesToCache(extractedPrices);
      await _saveForecastedPricesToCache(extractedForecastPrices);
      
      setState(() {
        _latestPrices = prices;
        _forecastedPrices = forecastedprices;
        _isLoadingPrices = false;
      });
      
      // Generate and cache new context data
      _generateAndCacheContextData();
      
      // Add a bot message indicating the prices have been updated
      setState(() {
        _messages.add({"bot": "I've updated with the latest price information!"});
      });

      // Save message history after adding refresh message
      await _saveMessageHistory();
    } catch (e) {
      print('❌ Error refreshing price data in ChatbotPage: $e');
      setState(() {
        _isLoadingPrices = false;
        _messages.add({"bot": "Failed to update prices. Please try again later."});
      });

      // Save message history after adding error message
      await _saveMessageHistory();
    }
  }
  
  // Extract only the data we need from the price objects to avoid Timestamp issues
  Map<String, dynamic> _extractPriceData(Map<String, dynamic> prices) {
    final result = <String, dynamic>{};
    
    prices.forEach((key, value) {
      if (value is Map) {
        final extractedItem = <String, dynamic>{};
        // Extract only the fields we need for the context
        if (value.containsKey('price')) extractedItem['price'] = value['price'];
        if (value.containsKey('formatted_end_date')) extractedItem['formatted_end_date'] = value['formatted_end_date'];
        
        // Handle the original_data field
        if (value.containsKey('original_data') && value['original_data'] is Map) {
          final originalDataExtract = <String, dynamic>{};
          final originalData = value['original_data'];
          if (originalData.containsKey('commodity_id')) originalDataExtract['commodity_id'] = originalData['commodity_id'];
          extractedItem['original_data'] = originalDataExtract;
        }
        
        result[key] = extractedItem;
      }
    });
    
    return result;
  }
  
  // Extract only the data we need from the forecast objects to avoid Timestamp issues
  Map<String, dynamic> _extractForecastData(Map<String, dynamic> forecasts) {
    final result = <String, dynamic>{};
    
    // Copy success flag
    if (forecasts.containsKey('success')) result['success'] = forecasts['success'];
    
    // Extract commodity names
    if (forecasts.containsKey('commodity_names')) {
      result['commodity_names'] = Map<String, String>.from(forecasts['commodity_names']);
    }
    
    // Extract forecast data without Timestamp objects
    if (forecasts.containsKey('forecast_data') && forecasts['forecast_data'] is Map) {
      final extractedForecasts = <String, List<Map<String, dynamic>>>{};
      
      forecasts['forecast_data'].forEach((commodityId, forecasts) {
        if (forecasts is List) {
          final forecastList = <Map<String, dynamic>>[];
          
          for (final forecast in forecasts) {
            if (forecast is Map) {
              final extractedForecast = <String, dynamic>{};
              
              // Extract only the fields we need
              if (forecast.containsKey('forecast_period')) extractedForecast['forecast_period'] = forecast['forecast_period'];
              if (forecast.containsKey('formatted_end_date')) extractedForecast['formatted_end_date'] = forecast['formatted_end_date'];
              if (forecast.containsKey('price')) extractedForecast['price'] = forecast['price'];
              
              forecastList.add(extractedForecast);
            }
          }
          
          extractedForecasts[commodityId] = forecastList;
        }
      });
      
      result['forecast_data'] = extractedForecasts;
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100), // Keep the existing header height
        child: AppBar(
          backgroundColor: kGreen,
          flexibleSpace: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // Align content to bottom
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_fishchatbot.svg',
                  height: 28,
                  colorFilter: ColorFilter.mode(kBlue, BlendMode.srcIn),
                ),
                SizedBox(height: 8),
                Text(
                  "Talipapa Chat",
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kBlue,
                  ),
                ),
                SizedBox(height: 12), // Add bottom padding
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: kBlue),
              onPressed: _isLoadingPrices ? null : _refreshPriceData,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Add a loading indicator for prices
          if (_isLoadingPrices)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: LinearProgressIndicator(backgroundColor: kGreen.withOpacity(0.3), valueColor: AlwaysStoppedAnimation<Color>(kGreen)),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + 1, // Add 1 for static welcome
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Static welcome message
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: CustomPaint(
                      painter: ChatBubblePainter(color: kBlue, isUser: false),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Welcome to Talipapa Chat! How can I assist you today?",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Adjust for index offset
                final message = _messages[index - 1];
                final isUser = message.containsKey("user");

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: CustomPaint(
                    painter: ChatBubblePainter(
                      color: isUser ? kGreen : kBlue,
                      isUser: isUser,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? kGreen : kBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUser ? message["user"]! : message["bot"]!,
                          style: TextStyle(
                            color: isUser ? kBlue : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: "Type your message...",
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isLoading ? kGreen.withOpacity(0.5) : kGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(),
    );
  }
}

class ChatBubblePainter extends CustomPainter {
  final Color color;
  final bool isUser;

  ChatBubblePainter({required this.color, required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    if (isUser) {
      // Tail on the right for user messages
      path.moveTo(size.width, size.height - 10);
      path.lineTo(size.width - 10, size.height - 20);
      path.lineTo(size.width - 10, size.height);
    } else {
      // Tail on the left for bot messages
      path.moveTo(0, size.height - 10);
      path.lineTo(10, size.height - 20);
      path.lineTo(10, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
