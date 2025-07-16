import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final bool showFromSettings;

  const TutorialOverlay({
    super.key, 
    required this.onClose, 
    this.showFromSettings = false,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  bool dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    if (!widget.showFromSettings) {
      _loadPreference();
    }
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final skipTutorial = prefs.getBool('skipLaunchTutorial') ?? false;

    if (!skipTutorial || widget.showFromSettings) {
      setState(() {
        dontShowAgain = skipTutorial; // Reflect the preference in the checkbox
      });
    } else {
      widget.onClose(); // Automatically close if the preference is set
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.black.withOpacity(0.7),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLanguage.get('welcome'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kBlue,
                      ),
                    ),
                    SizedBox(height: 24),
                    ListTile(
                      leading: Icon(Icons.star, color: kPink),
                      title: Text(AppLanguage.get('favorite_commodities'), 
                        style: TextStyle(color: kBlue)),
                      subtitle: Text(AppLanguage.get('tap_star'),
                        style: TextStyle(color: kBlue)),
                    ),
                    ListTile(
                      leading: Icon(Icons.touch_app, color: kBlue),
                      title: Text(AppLanguage.get('select_items'), 
                        style: TextStyle(color: kBlue)),
                      subtitle: Text(AppLanguage.get('tap_select'),
                        style: TextStyle(color: kBlue)),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: dontShowAgain,
                              onChanged: (bool? value) async {
                                setState(() {
                                  dontShowAgain = value ?? false;
                                });
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('skipLaunchTutorial', dontShowAgain);
                              },
                              activeColor: kPink,
                            ),
                            Text(
                              AppLanguage.get('dont_show'),
                              style: TextStyle(color: kBlue, fontSize: 12),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: widget.onClose,
                          child: Text(AppLanguage.get('close'), style: TextStyle(color: kPink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}