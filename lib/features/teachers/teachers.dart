import 'dart:convert';
import 'dart:ui';
import 'package:Fin/utils/http/appconfig.dart';

import 'package:Fin/utils/constants/colors.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

class Teachers extends StatefulWidget {
  const Teachers({super.key});

  @override
  State<Teachers> createState() => _TeachersState();
}

class _TeachersState extends State<Teachers> {
  late final String teacherApi;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController courseController = TextEditingController();

  List<dynamic> teachers = [];
  List<dynamic> inactiveTeachers = [];

  bool isLoading = false;
  bool _initialized = false;
  bool showInactive = false;

  @override
  void initState() {
    super.initState();
    teacherApi = "${AppConfig.baseUrl}/api/teacher";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      fetchTeachers();
      _initialized = true;
    }
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ================= FETCH ACTIVE =================
  Future<void> fetchTeachers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("$teacherApi/all"));
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => teachers = json["data"] ?? []);
      } else {
        showSnack(json["message"]);
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    }
    setState(() => isLoading = false);
  }

  // ================= FETCH INACTIVE =================
  Future<void> fetchInactiveTeachers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("$teacherApi/inactive"));
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => inactiveTeachers = json["data"] ?? []);
      } else {
        showSnack(json["message"]);
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    }
    setState(() => isLoading = false);
  }

  // ================= CREATE =================
  Future<void> createTeacher() async {
    try {
      final res = await http.post(
        Uri.parse("$teacherApi/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "teacherName": nameController.text.trim(),
          "phoneNumber": phoneController.text.trim(),
          "email": emailController.text.trim(),
          "age": int.tryParse(ageController.text.trim()) ?? 0,
          "coursesTea": courseController.text.isNotEmpty
              ? courseController.text.split(",").map((c) => c.trim()).toList()
              : [],
        }),
      );

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 201) {
        clearFields();
        fetchTeachers();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ================= UPDATE =================
  Future<void> updateTeacher(String originalName) async {
    try {
      final res = await http.put(
        Uri.parse("$teacherApi/update/$originalName"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "teacherName": nameController.text.trim(),
          "phoneNumber": phoneController.text.trim(),
          "email": emailController.text.trim(),
          "age": int.tryParse(ageController.text.trim()) ?? 0,
          "coursesTea": courseController.text.isNotEmpty
              ? courseController.text.split(",").map((c) => c.trim()).toList()
              : [],
        }),
      );

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 200) {
        clearFields();
        fetchTeachers();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ================= DELETE =================
  Future<void> deleteTeacher(String name) async {
    try {
      final res = await http.delete(
        Uri.parse("$teacherApi/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"teacherName": name}),
      );

      final json = jsonDecode(res.body);
      showSnack(json["message"]);

      if (res.statusCode == 200) {
        fetchTeachers();
        fetchInactiveTeachers();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // CONFIRM DELETE
  Future<void> confirmDeleteTeacher(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete \"$name\"?"),
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

    if (confirm == true) deleteTeacher(name);
  }

  // ================= REACTIVATE =================
  Future<void> reactivateTeacher(String name) async {
    try {
      final res = await http.put(Uri.parse("$teacherApi/reactivate/$name"));
      final json = jsonDecode(res.body);

      showSnack(json["message"]);

      if (res.statusCode == 200) {
        fetchTeachers();
        fetchInactiveTeachers();
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  Future<void> confirmReactivateTeacher(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reactivate Teacher"),
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

    if (confirm == true) reactivateTeacher(name);
  }

  // CLEAR FIELDS
  void clearFields() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    ageController.clear();
    courseController.clear();
  }

  // FORM POPUP
  void showTeacherDialog({Map<String, dynamic>? teacher}) {
    final editing = teacher != null;

    if (editing) {
      nameController.text = teacher["teacherName"];
      phoneController.text = teacher["phoneNumber"];
      emailController.text = teacher["email"];
      ageController.text = teacher["age"].toString();
      courseController.text =
          (teacher["coursesTea"] as List?)?.join(", ") ?? "";
    } else {
      clearFields();
    }

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          title: Text(editing ? "Edit Teacher" : "Add Teacher"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _field(nameController, "Name"),
                _field(phoneController, "Phone"),
                _field(emailController, "Email"),
                _field(ageController, "Age"),
                _field(courseController, "Courses (comma separated)"),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(TColors.info)),
              onPressed: () {
                Navigator.pop(context);
                editing
                    ? updateTeacher(teacher!["teacherName"])
                    : createTeacher();
              },
              child: Text(editing ? "Update" : "Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final list = showInactive ? inactiveTeachers : teachers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Teachers"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => showInactive = !showInactive);
              showInactive ? fetchInactiveTeachers() : fetchTeachers();
            },
          ),
          IconButton(
            onPressed: fetchTeachers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTeacherDialog(),
        backgroundColor: TColors.primary,
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: showInactive ? fetchInactiveTeachers : fetchTeachers,
                child: list.isEmpty
                    ? const Center(child: Text("No teachers found"))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final t = list[i];

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
                                    t["teacherName"],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
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
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Courses: ${(t["coursesTea"] as List?)?.join(', ') ?? 'N/A'}",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              trailing: showInactive
                                  ? IconButton(
                                      icon: const Icon(Icons.refresh,
                                          color: Colors.green),
                                      onPressed: () => confirmReactivateTeacher(
                                          t["teacherName"]),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: TColors.info),
                                          onPressed: () =>
                                              showTeacherDialog(teacher: t),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: TColors.error),
                                          onPressed: () => confirmDeleteTeacher(
                                              t["teacherName"]),
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
