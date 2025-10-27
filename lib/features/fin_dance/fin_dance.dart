// Destination page
import 'package:flutter/material.dart';

class FinDance extends StatelessWidget {
  final String title;
  final String image;

  const FinDance({super.key, required this.title, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Image.asset(image, fit: BoxFit.cover),
      ),
    );
  }
}
