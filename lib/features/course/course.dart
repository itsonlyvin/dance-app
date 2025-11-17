import 'dart:convert';
import 'dart:ui';
import 'package:Fin/appConfig.dart';
import 'package:Fin/navigation.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  late final String coursesApi;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController rateController = TextEditingController();

  List<dynamic> courses = [];
  bool isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    coursesApi = "${AppConfig.baseUrl}/api/courses";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      fetchCourses();
      _initialized = true;
    }
  }

  void showSnack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  Future<void> fetchCourses() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("$coursesApi/all"));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // backend might return List<Courses> or a wrapper {message,data}
        if (body is Map && body.containsKey("data")) {
          setState(() => courses = body["data"] ?? []);
        } else if (body is List) {
          setState(() => courses = body);
        } else {
          // unexpected but try to handle gracefully
          setState(() => courses = []);
          showSnack("Unexpected response from server");
        }
      } else {
        // try to read message if wrapper
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message")) {
            showSnack(body["message"]);
          } else {
            showSnack("Error: ${res.body}");
          }
        } catch (_) {
          showSnack("Error: ${res.body}");
        }
      }
    } catch (e) {
      showSnack("Failed to connect: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createCourse() async {
    try {
      final payload = {
        "courseName": nameController.text.trim(),
        "ratePerHour": double.tryParse(rateController.text.trim()) ?? 0.0,
      };

      final res = await http.post(
        Uri.parse("$coursesApi/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        // try to parse message
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack(res.body);
        } catch (_) {
          showSnack(res.body);
        }

        clearFields();
        fetchCourses();
      } else {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack("Error: ${res.body}");
        } catch (_) {
          showSnack("Error: ${res.body}");
        }
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  Future<void> updateCourse(String originalName) async {
    try {
      final payload = {
        "courseName": nameController.text.trim(),
        "ratePerHour": double.tryParse(rateController.text.trim()) ?? 0.0,
      };

      final res = await http.put(
        Uri.parse("$coursesApi/update/$originalName"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack(res.body);
        } catch (_) {
          showSnack(res.body);
        }

        clearFields();
        fetchCourses();
      } else {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack("Error: ${res.body}");
        } catch (_) {
          showSnack("Error: ${res.body}");
        }
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  Future<void> deleteCourse(String courseName) async {
    try {
      // controller expects path variable: DELETE /delete/{courseName}
      final res =
          await http.delete(Uri.parse("$coursesApi/delete/$courseName"));

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack(res.body);
        } catch (_) {
          showSnack(res.body);
        }

        fetchCourses();
      } else {
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey("message"))
            showSnack(body["message"]);
          else
            showSnack("Error: ${res.body}");
        } catch (_) {
          showSnack("Error: ${res.body}");
        }
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  void clearFields() {
    nameController.clear();
    rateController.clear();
  }

  void showCourseDialog({Map<String, dynamic>? course}) {
    final bool isEdit = course != null;

    if (isEdit) {
      nameController.text = course["courseName"] ?? "";
      // rate might be double or int
      rateController.text = (course["ratePerHour"]?.toString() ?? "");
    } else {
      clearFields();
    }

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? "Edit Course" : "Add Course"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(nameController, "Course Name"),
                _buildTextField(rateController, "Rate per hour"),
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
                if (isEdit) {
                  updateCourse(course!["courseName"]);
                } else {
                  createCourse();
                }
              },
              child: Text(isEdit ? "Update" : "Save"),
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
        keyboardType: label == "Rate per hour"
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
    );
  }

  Future<void> confirmDeleteCourse(String name) async {
    final c = await showDialog<bool>(
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

    if (c == true) deleteCourse(name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text("Courses"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: fetchCourses, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCourseDialog(),
        backgroundColor: TColors.primary,
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchCourses,
                color: Theme.of(context).colorScheme.primary,
                child: courses.isEmpty
                    ? const Center(child: Text("No courses found"))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          final course = courses[index];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
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
                                    offset: const Offset(0, 3))
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              title: Text(
                                course["courseName"] ?? "Unknown",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Rate / hour: ${(course["ratePerHour"] != null) ? course["ratePerHour"].toString() : 'N/A'}",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54),
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: TColors.info),
                                      onPressed: () =>
                                          showCourseDialog(course: course)),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: TColors.error),
                                      onPressed: () => confirmDeleteCourse(
                                          course["courseName"])),
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
