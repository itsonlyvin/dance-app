import 'package:Fin/features/fee/fee.dart';
import 'package:Fin/features/sections/section.dart';
import 'package:Fin/features/students/students.dart';
import 'package:Fin/features/teachers/teachers.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final darkMode = THelperFunctions.isDarkMode(context);

    return Scaffold(
      bottomNavigationBar: Obx(
        () => NavigationBar(
          height: 80,
          elevation: 0,
          backgroundColor: !darkMode
              ? const Color.fromARGB(255, 227, 222, 222)
                  .withAlpha((255 * 0.1).toInt())
              : Colors.black.withAlpha((0.1 * 255).toInt()),
          indicatorColor: darkMode
              ? Colors.white.withAlpha((255 * 0.1).toInt())
              : Colors.black.withAlpha((0.1 * 255).toInt()),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Iconsax.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.document),
              label: 'Details',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.notification),
              label: 'Notifications',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationController extends GetxController {
  final Rx<int> selectedIndex = 0.obs;
  late final List<Widget> screens;

  NavigationController({required bool admin}) {
    screens = [
      const Section(),
      const Students(),
      const Teachers(),
      const Fee(),
    ];
  }
}
