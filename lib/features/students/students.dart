import 'dart:convert';
import 'dart:ui';
import 'package:Fin/utils/http/appconfig.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:flutter/material.dart';
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
  List<dynamic> inactiveStudents = [];

  bool isLoading = false;
  bool _initialized = false;
  bool showInactive = false;

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

  // SNACKBAR
  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // FETCH ACTIVE STUDENTS
  Future<void> fetchStudents() async {
    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse("$studentsApi/all"));
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => students = json["data"] ?? []);
      } else {
        showSnack(json["message"] ?? "Error");
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    }

    setState(() => isLoading = false);
  }

  // FETCH INACTIVE STUDENTS
  Future<void> fetchInactiveStudents() async {
    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse("$studentsApi/inactive"));
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => inactiveStudents = json["data"] ?? []);
      } else {
        showSnack(json["message"] ?? "Error");
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    }

    setState(() => isLoading = false);
  }

  // CREATE STUDENT
  Future<void> createStudent() async {
    try {
      final res = await http.post(
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

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 201) {
        clearFields();
        fetchStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // UPDATE STUDENT (BY ID)
  Future<void> updateStudentById(int id) async {
    try {
      final res = await http.put(
        Uri.parse("$studentsApi/update/$id"),
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

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 200) {
        clearFields();
        fetchStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // DELETE STUDENT (BY ID)
  Future<void> deleteStudentById(int id) async {
    try {
      final res = await http.delete(
        Uri.parse("$studentsApi/delete/$id"),
      );

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 200) {
        fetchStudents();
        fetchInactiveStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // CONFIRM DELETE
  Future<void> confirmDeleteStudent(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete \"$name\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) deleteStudentById(id);
  }

  // REACTIVATE STUDENT (BY ID)
  Future<void> reactivateStudentById(int id) async {
    try {
      final res = await http.put(
        Uri.parse("$studentsApi/reactivate/$id"),
      );

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 200) {
        fetchInactiveStudents();
        fetchStudents();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  Future<void> confirmReactivateStudent(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reactivate Student"),
        content: Text("Reactivate \"$name\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Reactivate")),
        ],
      ),
    );

    if (confirm == true) reactivateStudentById(id);
  }

  // CLEAR FIELDS
  void clearFields() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    ageController.clear();
    courseController.clear();
  }

  // ADD / EDIT POPUP
  void showStudentDialog({Map<String, dynamic>? student}) {
    final editing = student != null;

    if (editing) {
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(editing ? "Edit Student" : "Add Student"),
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
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                editing ? updateStudentById(student!["id"]) : createStudent();
              },
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(TColors.info)),
              child: Text(editing ? "Update" : "Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final listToShow = showInactive ? inactiveStudents : students;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Students"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => showInactive = !showInactive);
              showInactive ? fetchInactiveStudents() : fetchStudents();
            },
          ),
          IconButton(
            onPressed: fetchStudents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showStudentDialog(),
        backgroundColor: TColors.primary,
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: showInactive ? fetchInactiveStudents : fetchStudents,
                color: Theme.of(context).colorScheme.primary,
                child: listToShow.isEmpty
                    ? const Center(child: Text("No students found"))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: listToShow.length,
                        itemBuilder: (context, index) {
                          final s = listToShow[index];

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isDark
                                  ? Colors.grey[900]!.withOpacity(0.8)
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
                              title: Row(
                                children: [
                                  Text(
                                    s["studentName"] ?? "Unknown",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: showInactive
                                          ? TColors.error.withOpacity(0.15)
                                          : TColors.success.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      showInactive ? "Inactive" : "Active",
                                      style: TextStyle(
                                        color: showInactive
                                            ? TColors.error
                                            : TColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Courses: ${(s["coursesPre"] as List?)?.join(', ') ?? 'N/A'}",
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
                                  if (!showInactive) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: TColors.info),
                                      onPressed: () =>
                                          showStudentDialog(student: s),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: TColors.error),
                                      onPressed: () => confirmDeleteStudent(
                                          s["id"], s["studentName"]),
                                    ),
                                  ] else ...[
                                    IconButton(
                                      icon: const Icon(Icons.refresh,
                                          color: Colors.green),
                                      onPressed: () => confirmReactivateStudent(
                                          s["id"], s["studentName"]),
                                    ),
                                  ],
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
