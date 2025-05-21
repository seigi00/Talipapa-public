import 'package:flutter/material.dart';
import 'constants.dart';

class GlobalDateDisplay extends StatelessWidget {
  final String globalPriceDate;

  const GlobalDateDisplay({super.key, required this.globalPriceDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: globalPriceDate.isEmpty
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Updating price data...",
                style: TextStyle(
                  fontSize: 12,
                  color: kBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(kBlue),
                ),
              ),
            ],
          )
        : Text(
            "As of: $globalPriceDate",
            style: TextStyle(
              color: kBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
    );
  }
}
