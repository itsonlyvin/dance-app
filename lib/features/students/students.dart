import 'dart:convert';
import 'dart:ui';
import 'package:Fin/appConfig.dart';
import 'package:Fin/navigation.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> {
  late final String studentsApi;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController courseController = TextEditingController();

  List<dynamic> students = [];
  bool isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    studentsApi = "${AppConfig.baseUrl}/api/students";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      fetchStudents();
      _initialized = true;
    }
  }

  /// ✅ Safe SnackBar method
  void showSnack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });
  }

  /// 🔹 Fetch all students
  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$studentsApi/all"));
      if (response.statusCode == 200) {
        setState(() {
          students = jsonDecode(response.body);
        });
      } else {
        showSnack("Error: ${response.body}");
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Create student
  Future<void> createStudent() async {
    try {
      final response = await http.post(
        Uri.parse("$studentsApi/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "studentName": nameController.text.trim(),
          "phoneNumber": phoneController.text.trim(),
          "email": emailController.text.trim(),
          "age": int.tryParse(ageController.text.trim()) ?? 0,
          "coursesPre": courseController.text.isNotEmpty
              ? courseController.text.split(",").map((c) => c.trim()).toList()
              : [],
        }),
      );

      showSnack(response.body);
      if (response.statusCode == 201) {
        clearFields();
        fetchStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  /// 🔹 Update student
  Future<void> updateStudent(String originalName) async {
    try {
      final response = await http.put(
        Uri.parse("$studentsApi/update/$originalName"), // 👈 Path variable
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "studentName": nameController.text.trim(),
          "phoneNumber": phoneController.text.trim(),
          "email": emailController.text.trim(),
          "age": int.tryParse(ageController.text.trim()) ?? 0,
          "coursesPre": courseController.text.isNotEmpty
              ? courseController.text.split(",").map((c) => c.trim()).toList()
              : [],
        }),
      );

      showSnack(response.body);
      if (response.statusCode == 200) {
        clearFields();
        fetchStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  /// 🔹 Delete student
  Future<void> deleteStudent(String studentName) async {
    try {
      final response = await http.delete(
        Uri.parse("$studentsApi/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"studentName": studentName}),
      );

      showSnack(response.body);
      if (response.statusCode == 200) fetchStudents();
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  void clearFields() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    ageController.clear();
    courseController.clear();
  }

  /// 🔹 Show dialog (Add / Edit)
  void showStudentDialog({Map<String, dynamic>? student}) {
    final bool isEdit = student != null;

    if (isEdit) {
      nameController.text = student["studentName"] ?? "";
      phoneController.text = student["phoneNumber"] ?? "";
      emailController.text = student["email"] ?? "";
      ageController.text = "${student["age"] ?? ""}";
      courseController.text =
          (student["coursesPre"] as List?)?.join(", ") ?? "";
    } else {
      clearFields();
    }

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(isEdit ? "Edit Student" : "Add Student"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(nameController, "Name"),
                _buildTextField(phoneController, "Phone"),
                _buildTextField(emailController, "Email"),
                _buildTextField(ageController, "Age"),
                _buildTextField(courseController, "Courses (comma separated)"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(TColors.info),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (isEdit) {
                  updateStudent(student["studentName"]);
                } else {
                  createStudent();
                }
              },
              child: Text(isEdit ? "Update" : "Save"),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Reusable text field
  Widget _buildTextField(TextEditingController controller, String label) {
    final darkMode = THelperFunctions.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkMode = THelperFunctions.isDarkMode(context);
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Students"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: fetchStudents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      /// Raised FloatingActionButton

      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: Obx(
        () {
          final controller = Get.find<NavigationController>();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastEaseInToSlowEaseOut,
            padding: EdgeInsets.only(
              bottom: controller.isNavVisible.value
                  ? 95.0
                  : 17.0, // moves when nav hides
              right: controller.isNavVisible.value ? 15 : 0,
            ),
            child: FloatingActionButton(
              onPressed: () => showStudentDialog(),
              backgroundColor: TColors.primary,
              elevation: 6,
              child: const Icon(Icons.add, size: 28),
            ),
          );
        },
      ),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchStudents, // 🔹 Pull-to-refresh
                color: Theme.of(context).colorScheme.primary,
                child: students.isEmpty
                    ? const Center(child: Text("No students found"))
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isDark
                                  ? Colors.grey[900]?.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.85),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              title: Text(
                                student["studentName"] ?? "Unknown",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Courses: ${(student["coursesPre"] as List?)?.join(', ') ?? 'N/A'}",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: TColors.info),
                                    onPressed: () =>
                                        showStudentDialog(student: student),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: TColors.error),
                                    onPressed: () =>
                                        deleteStudent(student["studentName"]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
