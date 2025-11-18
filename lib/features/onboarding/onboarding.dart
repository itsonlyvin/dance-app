import 'dart:ui';
import 'package:Fin/navigation.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/image_strings.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;
  double _scale = 1.0;

  final List<Map<String, String>> _products = [
    {'title': 'Section', 'image': TImages.logodark, 'image1': TImages.og01},
    {'title': 'Create', 'image': TImages.og03, 'image1': TImages.og04},
    {'title': 'Attendance', 'image': TImages.og09, 'image1': TImages.og08},
    {'title': 'Fees', 'image': TImages.og05, 'image1': TImages.og06},
  ];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // 💡 MATCHING HEIGHT FOR CAROUSEL, CARD & IMAGE
    final double cardHeight = screenHeight * 0.40;

    const gradientColors = [
      Color.fromRGBO(0, 0, 0, 1),
      Color.fromRGBO(0, 0, 0, 0.85),
      Color.fromRGBO(0, 0, 0, 0.5),
      Colors.transparent,
    ];

    return Scaffold(
      body: Stack(
        children: [
          // ---------------------- PARALLAX BACKGROUND ----------------------
          Positioned.fill(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 600),
              scale: 1.02,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _products[_currentIndex]['image1']!,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Cinematic gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: gradientColors,
                          stops: [0.0, 0.25, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Vignette
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------------- CAROUSEL ----------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: screenHeight * 0.60,
              width: screenWidth,
              child: CarouselSlider(
                options: CarouselOptions(
                  height: cardHeight, // 👈 MATCH HEIGHT
                  viewportFraction: 0.70,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: true,
                  onPageChanged: (index, _) {
                    setState(() => _currentIndex = index);
                  },
                ),
                items: _products.map((product) {
                  final productIndex = _products.indexOf(product);
                  final bool isCenter = productIndex == _currentIndex;
                  final double lift = isCenter ? -12 : 0;

                  // ---------------------- CARD ----------------------
                  Widget card = Transform.translate(
                    offset: Offset(0, lift),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: cardHeight, // 👈 MATCH HEIGHT
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: isCenter
                            ? Border.all(color: TColors.primary, width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Image inside card
                            Image.asset(
                              product['image']!,
                              width: double.infinity,
                              height: cardHeight, // 👈 MATCH HEIGHT
                              fit: BoxFit.cover,
                            ),

                            // Cinematic gradient
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: gradientColors,
                                  stops: [0.0, 0.25, 0.55, 1.0],
                                ),
                              ),
                            ),

                            // Title on image
                            // Title on image (BOTTOM CENTER)
                            Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Text(
                                        product['title']!,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );

                  // Tap animation
                  if (isCenter) {
                    card = GestureDetector(
                      onTap: () async {
                        setState(() => _scale = 0.9);
                        await Future.delayed(const Duration(milliseconds: 150));
                        setState(() => _scale = 1.0);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NavigationMenu(initialIndex: productIndex),
                          ),
                        );
                      },
                      child: AnimatedScale(
                        scale: _scale,
                        duration: const Duration(milliseconds: 200),
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
