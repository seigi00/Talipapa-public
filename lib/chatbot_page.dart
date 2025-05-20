import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG support
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'custom_bottom_navbar.dart';
import 'utils/forecast_cache_manager.dart';

class ChatbotPage extends StatefulWidget {
  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;

  // Build full prompt in mistral-v7 format
String _buildPrompt() {
  final buffer = StringBuffer();

  // Inject context as system instruction
  buffer.writeln('<|system|> You are Talipapa, a helpful chatbot in a mobile app that forecasts average market prices of goods in the Philippines. Provide friendly and accurate responses.');

  for (var message in _messages) {
    if (message.containsKey('user')) {
      buffer.writeln('<|user|> ${message['user']}');
    } else if (message.containsKey('bot')) {
      buffer.writeln('<|assistant|> ${message['bot']}');
    }
  }

  // Final assistant cue with no newline
  buffer.write('<|assistant|>');

  return buffer.toString();
}

  // Clean the assistant's raw response by removing </s> and similar tags
  String _cleanResponse(String raw) {
    return raw.replaceAll(RegExp(r'</?s>'), '').trim();
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
      final prompt = _buildPrompt();

      // TODO: Change to your llama server URL & port
      final url = Uri.parse('https://llm.talipapa.shop/completions');

      final body = jsonEncode({
        "prompt": prompt,
        // "n_keep": 0,
        "cache_prompt": false,
        "max_tokens": 100,
        "temperature": 0.7,
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
        print("Raw response: ${response.body}");
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
        ),
      ),
      body: Column(
        children: [
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
