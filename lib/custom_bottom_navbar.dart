import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main.dart'; // Import HomePage
import 'chatbot_page.dart'; // Import FishPage
import 'settings_page.dart'; // Import SettingsPage
import 'constants.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60, // Set your desired total height here (default is ~80)
      child: BottomAppBar(
        padding: EdgeInsets.zero, // Remove default padding
        height: 56, // Set the same height here
        color: kGreen,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNavIcon(
              context, 
              'assets/icons/ic_home.svg', 
              () => _navigateTo(context, HomePage()),
              20, // Reduced icon size
            ),
            _buildNavIcon(
              context, 
              'assets/icons/ic_fishchatbot.svg', 
              () => _navigateTo(context, ChatbotPage()),
              20, // Reduced icon size
            ),
            _buildNavIcon(
              context, 
              'assets/icons/ic_profile.svg', 
              () => _navigateTo(context, SettingsPage()),
              20, // Reduced icon size
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavIcon(BuildContext context, String iconPath, VoidCallback onPressed, double size) {
    return IconButton(
      icon: SvgPicture.asset(
        iconPath,
        height: size, // Use smaller size here
        width: size, // Maintain aspect ratio
        colorFilter: ColorFilter.mode(kBlue, BlendMode.srcIn),
      ),
      padding: EdgeInsets.all(8), // Reduce padding around icons
      constraints: BoxConstraints(), // Remove default constraints
      onPressed: onPressed,
    );
  }
  
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}