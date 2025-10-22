import 'package:Fin/features/home/homescreen.dart';
import 'package:Fin/utils/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This is the main entry point of the application.
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: TAppTheme.lightTheme,
      darkTheme: TAppTheme.darkTheme,
      title: 'Fin',
      // The home widget is the main screen of the application.
      home: const Homescreen(),
    );
  }
}
