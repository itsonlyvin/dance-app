import 'dart:ui';
import 'package:Fin/features/course/course.dart';
import 'package:Fin/features/students/students.dart';
import 'package:Fin/features/teachers/teachers.dart';
import 'package:Fin/navigation.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreationPage extends StatefulWidget {
  const CreationPage({super.key});

  @override
  State<CreationPage> createState() => _CreationPageState();
}

class _CreationPageState extends State<CreationPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Creation"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _itemCard(
              title: "Courses",
              icon: Icons.menu_book_rounded,
              bg: TColors.primary.withOpacity(0.15),
              iconColor: TColors.primary,
              onTap: () => Get.to(() => const CoursesPage()),
            ),
            const SizedBox(height: 16),
            _itemCard(
              title: "Students",
              icon: Icons.person_rounded,
              bg: Colors.blueAccent.withOpacity(0.15),
              iconColor: Colors.blueAccent,
              onTap: () => Get.to(() => const Students()),
            ),
            const SizedBox(height: 16),
            _itemCard(
              title: "Teachers",
              icon: Icons.school_rounded,
              bg: Colors.green.withOpacity(0.15),
              iconColor: Colors.green,
              onTap: () => Get.to(() => const Teachers()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard({
    required String title,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Get.isDarkMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? Colors.grey[900]!.withOpacity(0.8)
            : Colors.white.withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[500])
          ],
        ),
      ),
    );
  }
}
