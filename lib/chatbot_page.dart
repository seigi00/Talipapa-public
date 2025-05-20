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
  bool _isLoading = false;
  bool _isLoadingPrices = true;
  
  // Cache keys
  static const String _latestPricesKey = 'chatbot_cached_latest_prices';
  static const String _lastFetchTimeKey = 'chatbot_last_fetch_time';
  static const int _cacheDuration = 30; // 30 minutes by default

  @override
  void initState() {
    super.initState();
    _loadLatestPrices();
  }

  // Load latest prices with caching
  Future<void> _loadLatestPrices() async {
    try {
      if (await _isCacheValid()) {
        final cachedPrices = await _getLatestPricesFromCache();
        if (cachedPrices != null && cachedPrices.isNotEmpty) {
          setState(() {
            _latestPrices = cachedPrices;
            _isLoadingPrices = false;
          });
          print('✅ Using cached latest prices in ChatbotPage');
          return;
        }
      }
      
      // If cache is invalid or empty, fetch from Firestore
      print('🔄 Fetching latest prices from Firestore in ChatbotPage');
      final prices = await FirestoreService().fetchAllLatestPrices();
      
      // Save to cache for future use
      await _saveLatestPricesToCache(prices);
      
      setState(() {
        _latestPrices = prices;
        _isLoadingPrices = false;
      });
      print('✅ Fetched and cached latest prices in ChatbotPage');
    } catch (e) {
      print('❌ Error loading latest prices in ChatbotPage: $e');
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
  
  // Save latest prices to cache
  Future<void> _saveLatestPricesToCache(Map<String, dynamic> latestPrices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_latestPricesKey, jsonEncode(latestPrices));
      await prefs.setString(_lastFetchTimeKey, DateTime.now().toIso8601String());
      print('✅ Saved latest prices to ChatbotPage cache');
    } catch (e) {
      print('❌ Error saving latest prices to ChatbotPage cache: $e');
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

  // Build full prompt in mistral-v7 format
  String _buildPrompt(String contextData) {
    final buffer = StringBuffer();

    buffer.writeln(
    '<|system|> You are Talipapa Chatbot, you refer to yourself this name. A helpful chatbot in a mobile app that provides average market prices of goods in the Philippines. '
    'You may provide insights like recipes as long as its within the context of the data.'
    'You must answer questions based on the data below. '
    'If the information is not present, reply with: '
    '"Sorry, I dont have data about that item at the moment." '
    'Here is the data:\n\n$contextData'
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
    return raw.replaceAll(RegExp(r'</?s>'), '').trim();
  }

  // Get context data for the chatbot, including latest prices
  String _getContextData() {
    // Format the latest prices data for the chatbot
    final buffer = StringBuffer();
    buffer.writeln("LATEST PRICES:");
    
    if (_latestPrices.isEmpty) {
      buffer.writeln("No price data is currently available.");
    } else {
      
      print("Type of priceData: ${_latestPrices.runtimeType}");

      _latestPrices.forEach((commodityId, priceData) {
        print("Contents of priceData: $priceData");
        
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
    
    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"user": message});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final contextData = _getContextData();
      print(contextData); // Debug

      // Shortcut if the user asks directly for prices summary
      // if (message.toLowerCase().contains('prices') ||
      //     message.toLowerCase().contains('latest prices')) {
      //   setState(() {
      //     _messages.add({"bot": contextData});
      //     _isLoading = false;
      //   });
      //   return;
      // }

      final prompt = _buildPrompt(contextData);

      final url = Uri.parse('https://llm.talipapa.shop/completions');
      final body = jsonEncode({
        "prompt": prompt,
        "cache_prompt": false,
        "max_tokens": 700,
        "top_p":0.9,
        "temperature": 0.6,
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
      } else {
        setState(() {
          _messages.add({
            "bot": "Server error: ${response.statusCode}. Please try again later."
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"bot": "Error fetching bot response: $e"});
        _isLoading = false;
      });
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
      
      // Save to cache for future use
      await _saveLatestPricesToCache(prices);
      
      setState(() {
        _latestPrices = prices;
        _isLoadingPrices = false;
      });
      
      // Add a bot message indicating the prices have been updated
      setState(() {
        _messages.add({"bot": "I've updated with the latest price information!"});
      });
    } catch (e) {
      print('❌ Error refreshing price data in ChatbotPage: $e');
      setState(() {
        _isLoadingPrices = false;
        _messages.add({"bot": "Failed to update prices. Please try again later."});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100), // Increased header height
        child: AppBar(
          backgroundColor: kGreen,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_fishchatbot.svg',
                height: 28,
                colorFilter: ColorFilter.mode(kBlue, BlendMode.srcIn),
              ), // Fish icon
              SizedBox(height: 8), // Increased spacing
              Text(
                "Talipapa Chat",
                style: TextStyle(
                  fontFamily: 'CourierPrime',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kBlue,
                ),
              ),
            ],
          ),
          centerTitle: true, // Center the title and icon
          // Add refresh button to manually update prices
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
