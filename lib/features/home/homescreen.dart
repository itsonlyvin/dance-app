import 'package:Fin/features/fin_dance/fin_dance.dart';
import 'package:flutter/material.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/image_strings.dart';
import 'package:Fin/utils/constants/sizes.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:carousel_slider/carousel_slider.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _currentIndex = 0; // tracks center carousel card
  double _scale = 1.0;

  final List<Map<String, String>> _products = [
    {
      'title': 'Fin Dance',
      'description': 'This is product 1',
      'image': TImages.og02,
      'image1': TImages.og01,
    },
    {
      'title': 'Product 2',
      'description': 'This is product 2',
      'image': TImages.og03,
      'image1': TImages.og04,
    },
    {
      'title': 'Product 3',
      'description': 'This is product 3',
      'image': TImages.og08,
      'image1': TImages.og09,
    },
  ];

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
              _products[_currentIndex]['image1']!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Carousel pinned to bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: screenHeight * 0.60,
              width: screenWidth,
              child: CarouselSlider(
                options: CarouselOptions(
                  height: screenHeight * 0.50,
                  aspectRatio: 16 / 9,
                  viewportFraction: 0.70,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: true,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
                items: _products.map((product) {
                  final productIndex = _products.indexOf(product);
                  final bool isCenter = productIndex == _currentIndex;

                  Widget card = AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: dark ? TColors.dark : TColors.light,
                      borderRadius: BorderRadius.circular(20),
                      border: isCenter
                          ? Border.all(color: Colors.blue.shade500, width: 1.5)
                          : null,
                      boxShadow: isCenter
                          ? [
                              const BoxShadow(
                                color: Colors.black,
                                blurRadius: 30,
                                offset: Offset(0, 10),
                              ),
                            ]
                          : [
                              const BoxShadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            height: 320,
                            clipBehavior: Clip.hardEdge,
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(TSizes.defaultSpace),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  product['image']!,
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            product['title']!,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );

                  // Wrap only center card with gesture and scale animation
                  if (isCenter) {
                    card = GestureDetector(
                      onTap: () async {
                        setState(() => _scale = 1.1); // scale up
                        await Future.delayed(
                          const Duration(milliseconds: 200),
                        );
                        setState(() => _scale = 1.0); // reset
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FinDance(
                              title: product['title']!,
                              image: product['image']!,
                            ),
                          ),
                        );
                      },
                      child: AnimatedScale(
                        scale: _scale,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: card,
                      ),
                    );
                  }

                  return card;
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
