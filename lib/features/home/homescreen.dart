import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/image_strings.dart';
import 'package:Fin/utils/constants/sizes.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

class Homescreen extends StatelessWidget {
  const Homescreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool dark = THelperFunctions.isDarkMode(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              TImages.og01,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            right: screenWidth * 0.15,
            bottom: 0,
            child: Container(
              width: screenWidth * 0.70,
              height: screenHeight * 0.60,
              decoration: BoxDecoration(
                color: dark ? TColors.dark : TColors.light,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 10, // how soft the shadow is
                    spreadRadius: 2, // how wide the shadow spreads
                    offset: Offset(0, 5), // position: (x, y)
                  ),
                ],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),

              // Inside Container
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(TSizes.defaultSpace),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(25),
                      ),
                      child: Image.asset(
                        width: double.infinity,
                        height: 250,
                        TImages.og02,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
