import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import for SVG support
import 'constants.dart';
import 'custom_bottom_navbar.dart';

class ChatbotPage extends StatefulWidget {
  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"bot": "Welcome to Talipapa Chat! How can I assist you today?"} // Initial chatbot message
  ]; // List to store messages

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      setState(() {
        _messages.add({"user": message}); // Add user message
        _messages.add({"bot": _getBotResponse(message)}); // Add bot response
      });
      _messageController.clear(); // Clear the input field
    }
  }

  String _getBotResponse(String userMessage) {
    // Basic bot response logic
    if (userMessage.toLowerCase().contains("hello")) {
      return "Hi there! How can I assist you today?";
    } else if (userMessage.toLowerCase().contains("price")) {
      return "You can check the latest prices in the app.";
    } else {
      return "I'm sorry, I didn't understand that. Can you rephrase?";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(120), // Adjusted height to match or slightly exceed main.dart
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
              SizedBox(height: 12), // Increased spacing to prevent overlap
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.containsKey("user");
                final isFirstBotMessage = index == 0 && message.containsKey("bot");

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: CustomPaint(
                    painter: ChatBubblePainter(
                      color: isFirstBotMessage ? kBlue : (isUser ? kGreen : kPink),
                      isUser: isUser,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7, // Limit bubble width to 70% of screen width
                      ),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFirstBotMessage ? kBlue : (isUser ? kGreen : kPink),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUser ? message["user"]! : message["bot"]!,
                          style: TextStyle(
                            color: isFirstBotMessage ? Colors.white : (isUser ? kBlue : Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Add spacing above the navbar
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30), // Rounded input bar
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
                            decoration: InputDecoration(
                              hintText: "Type your message...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
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
                                color: kGreen, // Green background for the send icon
                                shape: BoxShape.circle, // Circular send icon
                              ),
                              child: Icon(
                                Icons.arrow_upward, // Thin upward arrow
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}