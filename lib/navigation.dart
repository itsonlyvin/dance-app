import 'dart:ui';
import 'package:Fin/features/fee/fee.dart';
import 'package:Fin/features/sections/section.dart';
import 'package:Fin/features/students/students.dart';
import 'package:Fin/features/teachers/teachers.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class NavigationMenu extends StatelessWidget {
  final int initialIndex;
  const NavigationMenu({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController(admin: true));
    controller.selectedIndex.value = initialIndex;
    final darkMode = THelperFunctions.isDarkMode(context);

    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            controller.hideNavBar();
          } else if (notification.direction == ScrollDirection.forward) {
            controller.showNavBar();
          }
          return false;
        },
        child: Obx(() => controller.screens[controller.selectedIndex.value]),
      ),

      /// Animated Bottom Navigation Bar
      bottomNavigationBar: Obx(
        () => AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: controller.isNavVisible.value
              ? const Offset(0, 0)
              : const Offset(0, 1.5),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: controller.isNavVisible.value ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: NavigationBar(
                    height: 70,
                    elevation: 0,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    selectedIndex: controller.selectedIndex.value,
                    backgroundColor: darkMode
                        ? Colors.black.withOpacity(0.1)
                        : Colors.white.withOpacity(0.1),
                    indicatorColor: Colors.transparent,
                    onDestinationSelected: (index) =>
                        controller.selectedIndex.value = index,
                    destinations: [
                      _buildNavItem(
                        icon: Iconsax.document,
                        label: "Section",
                        selected: controller.selectedIndex.value == 0,
                        context: context,
                      ),
                      _buildNavItem(
                        icon: Iconsax.personalcard,
                        label: "Students",
                        selected: controller.selectedIndex.value == 1,
                        context: context,
                      ),
                      _buildNavItem(
                        icon: Iconsax.teacher,
                        label: "Teachers",
                        selected: controller.selectedIndex.value == 2,
                        context: context,
                      ),
                      _buildNavItem(
                        icon: Iconsax.money,
                        label: "Fee",
                        selected: controller.selectedIndex.value == 3,
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds each navigation icon with smooth glow animation
  NavigationDestination _buildNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required BuildContext context,
  }) {
    const Color activeColor = TColors.primary;
    final Color inactiveColor =
        THelperFunctions.isDarkMode(context) ? TColors.light : TColors.dark;

    return NavigationDestination(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: selected ? activeColor : inactiveColor,
          size: selected ? 26 : 24,
        ),
      ),
      label: label,
    );
  }
}

class NavigationController extends GetxController {
  final Rx<int> selectedIndex = 0.obs;
  final RxBool isNavVisible = true.obs;
  late final List<Widget> screens;

  NavigationController({required bool admin}) {
    screens = const [
      Section(),
      Students(),
      Teachers(),
      Fee(),
    ];
  }

  void hideNavBar() => isNavVisible.value = false;
  void showNavBar() => isNavVisible.value = true;
}
