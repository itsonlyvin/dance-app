import 'dart:convert';
import 'package:Fin/utils/http/appconfig.dart';
import 'package:Fin/navigation.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/sizes.dart';
import 'package:Fin/utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

class Section extends StatefulWidget {
  const Section({super.key});

  @override
  State<Section> createState() => _SectionState();
}

class _SectionState extends State<Section> {
  late final String sectionApi;
  late final String studentsApi;

  List<Map<String, dynamic>> sections = [];
  List<dynamic> allStudents = [];
  List<String> selectedStudents = [];
  bool isLoading = false;

  DateTime focusedDay = DateTime.now();
  DateTime selectedDate = DateTime.now();

  final TextEditingController teacherController = TextEditingController();
  final TextEditingController courseController = TextEditingController();
  final TextEditingController timeFromController = TextEditingController();
  final TextEditingController timeToController = TextEditingController();
  final TextEditingController adminRemarkController = TextEditingController();
  final TextEditingController repeatCountController = TextEditingController();

  bool repeatWeekly = false;
  int repeatCount = 0;

  @override
  void initState() {
    super.initState();
    sectionApi = "${AppConfig.baseUrl}/section";
    studentsApi = "${AppConfig.baseUrl}/api/students/all";
    fetchSections();
    fetchStudents();
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ---------- Helper: unwrap unified response ----------
  /// Returns a Map with keys:
  /// {
  ///   "ok": bool, // http success
  ///   "message": String,
  ///   "data": dynamic
  /// }
  Map<String, dynamic> _unwrapResponse(http.Response resp) {
    final statusOk = resp.statusCode >= 200 && resp.statusCode < 300;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        // If server follows { message, data }
        if (decoded.containsKey('data') || decoded.containsKey('message')) {
          return {
            "ok": statusOk,
            "message": decoded['message']?.toString() ??
                (statusOk ? "Success" : "Error"),
            "data": decoded.containsKey('data')
                ? decoded['data']
                : (decoded['data'] ?? decoded),
          };
        } else {
          // Map without keys: treat whole map as data
          return {
            "ok": statusOk,
            "message": statusOk ? "Success" : "Error",
            "data": decoded,
          };
        }
      } else {
        // decoded is not a map (e.g., list)
        return {
          "ok": statusOk,
          "message": statusOk ? "Success" : "Error",
          "data": decoded,
        };
      }
    } catch (e) {
      // body is not json or decode failed -> fallback
      final body = resp.body.trim();
      return {
        "ok": statusOk,
        "message": body.isNotEmpty ? body : (statusOk ? "Success" : "Error"),
        "data": statusOk ? List<dynamic>.empty() : null,
      };
    }
  }

  // ----------------------------- FETCH STUDENTS -----------------------------
  Future<void> fetchStudents() async {
    try {
      final response = await http.get(Uri.parse(studentsApi));
      final wrapped = _unwrapResponse(response);

      if (wrapped["ok"] == true) {
        final rawData = wrapped["data"];

        // backend might return { data: [...] } OR array directly OR { students: [...] }
        List<dynamic> studentsList = [];
        if (rawData is List) {
          studentsList = rawData;
        } else if (rawData is Map && rawData.containsKey('data')) {
          studentsList = rawData['data'] as List<dynamic>;
        } else if (rawData is Map && rawData.containsKey('students')) {
          studentsList = rawData['students'] as List<dynamic>;
        } else if (rawData == null) {
          studentsList = [];
        } else {
          // single object or map - try to coerce
          studentsList = [rawData];
        }

        setState(() => allStudents = studentsList);
      } else {
        showSnack(wrapped["message"] ?? "Failed to load students");
      }
    } catch (e) {
      showSnack("Error fetching students: $e");
    }
  }

  // ----------------------------- FETCH SECTIONS -----------------------------
  Future<void> fetchSections() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$sectionApi/all"));
      final wrapped = _unwrapResponse(response);

      if (wrapped["ok"] == true) {
        final rawData = wrapped["data"];

        List<dynamic> rawList = [];
        if (rawData is List) {
          rawList = rawData;
        } else if (rawData is Map && rawData.containsKey('data')) {
          rawList = rawData['data'] as List<dynamic>;
        } else if (rawData == null) {
          rawList = [];
        } else {
          // If backend returned a single object, put it into a list
          rawList = [rawData];
        }

        setState(() {
          sections = rawList.map((raw) {
            final s = Map<String, dynamic>.from(raw as Map);

            final attendanceList = ((s["attendance"] ?? []) as List)
                .map((a) => Map<String, dynamic>.from(a as Map))
                .toList();

            final presentCount =
                attendanceList.where((a) => a["present"] == true).length;
            final absentCount =
                attendanceList.where((a) => a["present"] == false).length;

            return {
              ...s,
              "attendance": attendanceList,
              "students": List<String>.from(s["students"] ?? []),
              "presentCount": presentCount,
              "absentCount": absentCount,
            };
          }).toList();
        });
      } else {
        showSnack(wrapped["message"] ?? "Error loading sections");
      }
    } catch (e) {
      showSnack("Connection error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get sectionsForSelectedDate {
    final dateString = selectedDate.toIso8601String().split('T')[0];
    return sections.where((s) => s['date']?.toString() == dateString).toList();
  }

  Set<DateTime> get sectionDates {
    return sections
        .map((s) => DateTime.parse(s['date']))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
  }

  String _ensureSeconds(String hhmmOrHhmmss) {
    if (hhmmOrHhmmss.isEmpty) return hhmmOrHhmmss;
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(hhmmOrHhmmss))
      return hhmmOrHhmmss;
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(hhmmOrHhmmss))
      return "$hhmmOrHhmmss:00";
    final t = TimeOfDayExtension.tryParse(hhmmOrHhmmss);
    if (t != null) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return "$h:$m:00";
    }
    return hhmmOrHhmmss;
  }

  String _formatForBackend(String timeText) {
    if (timeText.isEmpty) return "";
    try {
      final t = TimeOfDayExtension.tryParse(timeText);
      if (t == null) return timeText;
      final hours = t.hour.toString().padLeft(2, '0');
      final minutes = t.minute.toString().padLeft(2, '0');
      return "$hours:$minutes";
    } catch (_) {
      return timeText;
    }
  }

  // ---------------- CREATE SECTION ----------------
  Future<void> createOrUpdateSection({Map<String, dynamic>? section}) async {
    final teacherName = teacherController.text.trim();
    final courseName = courseController.text.trim();
    final date = selectedDate.toIso8601String().split('T')[0];
    final timeFrom = _formatForBackend(timeFromController.text.trim());
    final timeTo = _formatForBackend(timeToController.text.trim());
    final adminRemark = adminRemarkController.text.trim();
    final students = selectedStudents;

    if (teacherName.isEmpty ||
        courseName.isEmpty ||
        timeFrom.isEmpty ||
        timeTo.isEmpty ||
        students.isEmpty) {
      showSnack("Please fill all required fields & select students.");
      return;
    }

    final payload = {
      "teacherName": teacherName,
      "courseName": courseName,
      "date": date,
      "timeFrom": timeFrom,
      "timeTo": timeTo,
      "students": students,
      "repeatWeekly": repeatWeekly,
      "repeatCount": repeatCount,
      "adminRemark": adminRemark,
    };

    try {
      final response = await http.post(
        Uri.parse("$sectionApi/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final wrapped = _unwrapResponse(response);
      if (wrapped["ok"] == true) {
        Navigator.pop(context);
        await fetchSections();
        showSnack(wrapped["message"] ?? "Section created successfully");
      } else {
        showSnack(wrapped["message"] ?? "Failed to create section");
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ---------------- DELETE SECTION ----------------
  Future<void> deleteSection(Map<String, dynamic> s) async {
    try {
      final response = await http.delete(
        Uri.parse("$sectionApi/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "teacherName": s["teacherName"],
          "courseName": s["courseName"],
          "date": s["date"],
          "timeFrom": s["timeFrom"],
          "timeTo": s["timeTo"],
        }),
      );

      final wrapped = _unwrapResponse(response);
      showSnack(wrapped["message"] ?? "Deleted");
      if (wrapped["ok"] == true) fetchSections();
    } catch (e) {
      showSnack("Error deleting section: $e");
    }
  }

  // ---------------- MARK ATTENDANCE ----------------
  Future<void> markAttendance(
    String teacherName,
    String courseName,
    String date,
    String timeFrom,
    String timeTo,
    String studentName,
    bool present,
  ) async {
    final dateOnly = date.split('T').first;
    final fromWithSec = _ensureSeconds(timeFrom);
    final toWithSec = _ensureSeconds(timeTo);

    final uri = Uri.parse("$sectionApi/mark-attendance").replace(
      queryParameters: {
        "teacherName": teacherName,
        "courseName": courseName,
        "date": dateOnly,
        "timeFrom": fromWithSec,
        "timeTo": toWithSec,
        "studentName": studentName,
        "present": present.toString(),
      },
    );

    try {
      final response = await http.post(uri);
      final wrapped = _unwrapResponse(response);

      if (wrapped["ok"] == true) {
        showSnack(wrapped["message"] ?? "Attendance saved");
      } else {
        showSnack(wrapped["message"] ?? "Failed to save attendance");
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ---------------- MARK ALL PRESENT ----------------
  Future<void> markAllPresent(
    String teacherName,
    String courseName,
    String date,
    String timeFrom,
    String timeTo,
  ) async {
    final dateOnly = date.split('T').first;
    final fromWithSec = _ensureSeconds(timeFrom);
    final toWithSec = _ensureSeconds(timeTo);

    final uri = Uri.parse("$sectionApi/markAllPresent");

    final body = jsonEncode({
      "teacherName": teacherName,
      "courseName": courseName,
      "date": dateOnly,
      "timeFrom": fromWithSec,
      "timeTo": toWithSec,
    });

    try {
      final response = await http.post(uri,
          headers: {"Content-Type": "application/json"}, body: body);
      final wrapped = _unwrapResponse(response);

      if (wrapped["ok"] == true) {
        showSnack(wrapped["message"] ?? "All students marked present");
        fetchSections();
      } else {
        showSnack(wrapped["message"] ?? "Failed to mark all present");
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ---------------- UPDATE SECTION ----------------
  Future<void> updateSectionOnly(Map<String, dynamic> section) async {
    final payload = {
      "teacherName": section["teacherName"],
      "courseName": section["courseName"],
      "date": section["date"],
      "timeFrom": section["timeFrom"],
      "timeTo": section["timeTo"],
      "repeatWeekly": repeatWeekly,
      "repeatCount": repeatCount,
      "adminRemark": adminRemarkController.text.trim(),
      "oldStudents": List<String>.from(section["students"] ?? []),
      "newStudents": selectedStudents.isNotEmpty
          ? selectedStudents
          : List<String>.from(section["students"] ?? []),
    };

    try {
      final res = await http.put(
        Uri.parse("$sectionApi/update"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final wrapped = _unwrapResponse(res);
      if (wrapped["ok"] == true) {
        Navigator.pop(context);
        await fetchSections();
        showSnack(wrapped["message"] ?? "Section updated");
      } else {
        showSnack(wrapped["message"] ?? "Update failed");
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ---------------- CHANGE SECTION KEY ----------------
  Future<void> changeSectionKeyFlutter(Map<String, dynamic> section) async {
    final payload = {
      "oldKey": {
        "teacherName": section["teacherName"],
        "courseName": section["courseName"],
        "date": section["date"],
        "timeFrom": section["timeFrom"],
        "timeTo": section["timeTo"],
      },
      "newKey": {
        "teacherName": teacherController.text.trim(),
        "courseName": courseController.text.trim(),
        "date": selectedDate.toIso8601String().split('T')[0],
        "timeFrom": _formatForBackend(timeFromController.text.trim()),
        "timeTo": _formatForBackend(timeToController.text.trim()),
      }
    };

    try {
      final res = await http.put(
        Uri.parse("$sectionApi/changeKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final wrapped = _unwrapResponse(res);
      if (wrapped["ok"] == true) {
        Navigator.pop(context);
        await fetchSections();
        showSnack(wrapped["message"] ?? "Section key changed");
      } else {
        showSnack(wrapped["message"] ?? "Change key failed");
      }
    } catch (e) {
      showSnack("Error: $e");
    }
  }

  // ---------------- ATTENDANCE DIALOG ----------------
  void openAttendanceDialog(Map<String, dynamic> section) {
    final attendanceList = ((section["attendance"] ?? []) as List)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();

    final Map<String, bool> attendanceMap = {
      for (var a in attendanceList) a["studentName"]: a["present"] ?? false,
    };

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📝 Mark Attendance",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${section["teacherName"]} • ${section["courseName"]}",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.55,
                child: Column(
                  children: [
                    // --- Top Buttons Row ---
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              //  icon: const Icon(Icons.done_all, size: 18),
                              label: const Text("All Present"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                              ),
                              onPressed: () async {
                                setState(() {
                                  attendanceMap.updateAll((_, __) => true);
                                });
                                await markAllPresent(
                                  section["teacherName"],
                                  section["courseName"],
                                  section["date"],
                                  section["timeFrom"],
                                  section["timeTo"],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              // icon: const Icon(Icons.close, size: 18),
                              label: const Text("Select None"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TColors.error,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                              ),
                              onPressed: () {
                                setState(() {
                                  attendanceMap.updateAll((_, __) => false);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1.2),

                    // --- Student List ---
                    Expanded(
                      child: attendanceMap.isEmpty
                          ? const Center(
                              child:
                                  Text("No students found for this section."),
                            )
                          : ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, thickness: 0.3),
                              itemCount: attendanceMap.length,
                              itemBuilder: (context, index) {
                                final name =
                                    attendanceMap.keys.elementAt(index);
                                return CheckboxListTile(
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  value: attendanceMap[name],
                                  activeColor: TColors.secondary,
                                  checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  onChanged: (value) {
                                    setState(() =>
                                        attendanceMap[name] = value ?? false);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text("Save Attendance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.secondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    setState(() => isSaving = true);
                    for (var entry in attendanceMap.entries) {
                      await markAttendance(
                        section["teacherName"],
                        section["courseName"],
                        section["date"],
                        section["timeFrom"],
                        section["timeTo"],
                        entry.key,
                        entry.value,
                      );
                    }
                    setState(() => isSaving = false);
                    Navigator.pop(context);
                    fetchSections();
                  },
                ),
              ],
            ),

            // --- Overlay while saving ---
            if (isSaving)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        "Saving attendance...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // STUDENT SELECT DIALOG
  Future<void> _selectStudents(
      void Function(void Function()) parentSetState) async {
    final tempSelected = List<String>.from(selectedStudents);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Students"),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: ListView.builder(
            itemCount: allStudents.length,
            itemBuilder: (context, index) {
              final student = allStudents[index];
              final name = student["studentName"] ?? "Unnamed";
              final selected = tempSelected.contains(name);
              return CheckboxListTile(
                title: Text(name),
                value: selected,
                activeColor: TColors.secondary,
                onChanged: (checked) {
                  (context as Element).markNeedsBuild();
                  if (checked == true) {
                    tempSelected.add(name);
                  } else {
                    tempSelected.remove(name);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TColors.secondary),
            onPressed: () => Navigator.pop(context, tempSelected),
            child: const Text("Done"),
          ),
        ],
      ),
    );

    if (result != null) {
      parentSetState(() {
        selectedStudents = result;
      });
    }
  }

  // TEXTFIELD WIDGET
  Widget _textField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: THelperFunctions.isDarkMode(context)
                ? TColors.dark
                : TColors.light,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  // SECTION FORM (ADD/EDIT)
  void openSectionDialog({Map<String, dynamic>? section}) {
    final isEdit = section != null;

    if (isEdit) {
      teacherController.text = section!["teacherName"];
      courseController.text = section["courseName"];
      selectedDate = DateTime.parse(section["date"]);
      timeFromController.text = section["timeFrom"];
      timeToController.text = section["timeTo"];
      adminRemarkController.text = section["adminRemark"] ?? '';
      selectedStudents = List<String>.from(section["students"] ?? []);
      repeatWeekly = section["repeatWeekly"] ?? false;
      repeatCount = section["repeatCount"] ?? 0;
    } else {
      teacherController.clear();
      courseController.clear();
      timeFromController.clear();
      timeToController.clear();
      adminRemarkController.clear();
      selectedStudents.clear();
      repeatWeekly = false;
      repeatCount = 0;
    }

    // Sync repeatCount with controller before showing
    repeatCountController.text = repeatCount == 0 ? "" : repeatCount.toString();

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              // Keep controller updated whenever repeatCount changes
              repeatCountController.text =
                  repeatCount == 0 ? "" : repeatCount.toString();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(TSizes.defaultSpace),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        isEdit ? "Edit Section" : "Add Section",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: TSizes.defaultSpace),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: teacherController,
                        decoration: InputDecoration(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("Teacher Name"),
                              SizedBox(width: 6),
                              Icon(Icons.key, size: 18),
                            ],
                          ),
                          filled: true,
                          fillColor: THelperFunctions.isDarkMode(context)
                              ? TColors.dark
                              : TColors.light,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: courseController,
                        decoration: InputDecoration(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("Course Name"),
                              SizedBox(width: 6),
                              Icon(Icons.key, size: 18),
                            ],
                          ),
                          filled: true,
                          fillColor: THelperFunctions.isDarkMode(context)
                              ? TColors.dark
                              : TColors.light,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: TSizes.spaceBtwItems),

                    // Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  timeFromController.text =
                                      picked.format(context);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: TextField(
                                  controller: timeFromController,
                                  decoration: InputDecoration(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text("From"),
                                        SizedBox(width: 6),
                                        Icon(Icons.key, size: 18),
                                      ],
                                    ),
                                    filled: true,
                                    fillColor:
                                        THelperFunctions.isDarkMode(context)
                                            ? TColors.dark
                                            : TColors.light,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: TSizes.spaceBtwItems),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  timeToController.text =
                                      picked.format(context);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: TextField(
                                  controller: timeToController,
                                  decoration: InputDecoration(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text("To"),
                                        SizedBox(width: 6),
                                        Icon(Icons.key, size: 18),
                                      ],
                                    ),
                                    filled: true,
                                    fillColor:
                                        THelperFunctions.isDarkMode(context)
                                            ? TColors.dark
                                            : TColors.light,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: TSizes.spaceBtwItems),

// ADMIN REMARK WITH ICON
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: adminRemarkController,
                        decoration: InputDecoration(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("Admin Remark"),
                              SizedBox(width: 6),
                              Icon(Icons.update, size: 18),
                            ],
                          ),
                          filled: true,
                          fillColor: THelperFunctions.isDarkMode(context)
                              ? TColors.dark
                              : TColors.light,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

// SELECT STUDENTS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.group_add),
                          label: const Text("Select Students"),
                          onPressed: () => _selectStudents(setState),
                        ),
                        Text("${selectedStudents.length} selected",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),

                    Wrap(
                      spacing: 6,
                      children: selectedStudents
                          .map((s) => Chip(
                                label: Text(s),
                                backgroundColor:
                                    TColors.secondary.withOpacity(0.2),
                              ))
                          .toList(),
                    ),

                    const Divider(height: 30),

// REPEAT SECTION
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: repeatWeekly,
                              activeColor: TColors.primary,
                              onChanged: (value) {
                                setState(() {
                                  repeatWeekly = value;
                                  if (!value) {
                                    repeatCount = 0;
                                    repeatCountController.clear();
                                  }
                                });
                              },
                            ),

                            // LABEL WITH UPDATE ICON
                            Row(
                              children: const [
                                Text(
                                  " Repeat Monthly",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.update, size: 18),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // REPEAT COUNT WITH ICON
                        TextField(
                          controller: repeatCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text("Repeat Count (weeks)"),
                                SizedBox(width: 6),
                                Icon(Icons.update, size: 18),
                              ],
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {
                              repeatCount = int.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Buttons: Create OR (Update + Change Key)
                    Center(
                      child: isEdit
                          ? Row(
                              children: [
                                // CHANGE KEY BUTTON (FIRST)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.key),
                                    label: const Text("Change Key"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: TColors.secondary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    onPressed: () =>
                                        changeSectionKeyFlutter(section!),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // UPDATE BUTTON (SECOND)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.update),
                                    label: const Text("Update"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: TColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    onPressed: () =>
                                        updateSectionOnly(section!),
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text("Create"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 14),
                              ),
                              onPressed: () => createOrUpdateSection(),
                            ),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // SECTION CARD
  Widget _buildSectionCard(Map<String, dynamic> s, bool darkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: darkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          "${s['teacherName'].toString().toUpperCase()} - ${s['courseName'].toString().toUpperCase()}",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time with color
              Text(
                "${s['timeFrom']} - ${s['timeTo']}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),

              // Admin Remark
              Text(
                "Admin Remark: ${s['adminRemark']?.isNotEmpty == true ? s['adminRemark'] : '-'}",
                style: TextStyle(
                  color: TColors.darkGrey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),

              // Present / Absent Counts
              Row(
                children: [
                  // Present
                  RichText(
                    text: TextSpan(
                      text: "Present: ",
                      style: const TextStyle(
                        color: TColors.darkGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      children: [
                        TextSpan(
                          text: "${s['presentCount']}",
                          style: const TextStyle(
                            color: TColors.third,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Absent
                  RichText(
                    text: TextSpan(
                      text: "Absent: ",
                      style: const TextStyle(
                        color: TColors.darkGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      children: [
                        TextSpan(
                          text: "${s['absentCount']}",
                          style: const TextStyle(
                            color: TColors.third,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              openSectionDialog(section: s);
            } else if (value == 'delete') {
              confirmDeleteSection(s);
            } else if (value == 'attendance') {
              openAttendanceDialog(s);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
            PopupMenuItem(value: 'attendance', child: Text('Mark Attendance')),
          ],
        ),
      ),
    );
  }

  Future<void> confirmDeleteSection(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text(
            "Are you sure you want to delete this section? This action cannot be undone."),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TColors.error),
            child: const Text("Delete"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      deleteSection(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = THelperFunctions.isDarkMode(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Section Schedule"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: fetchSections, icon: const Icon(Icons.refresh))
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: Obx(() {
        final controller = Get.find<NavigationController>();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
          padding: EdgeInsets.only(
            bottom: controller.isNavVisible.value ? 95.0 : 12.0,
            right: controller.isNavVisible.value ? 15 : 1,
          ),
          child: FloatingActionButton(
            onPressed: () => openSectionDialog(),
            backgroundColor: TColors.primary,
            elevation: 6,
            child: const Icon(Icons.add, size: 28),
          ),
        );
      }),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar(
                      focusedDay: focusedDay,
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      selectedDayPredicate: (day) =>
                          isSameDay(selectedDate, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          selectedDate = selectedDay;
                          this.focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                            color: TColors.primary.withOpacity(0.8),
                            shape: BoxShape.circle),
                        selectedDecoration: const BoxDecoration(
                            color: TColors.secondary, shape: BoxShape.circle),
                        markerDecoration: const BoxDecoration(
                            color: TColors.third, shape: BoxShape.circle),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (sectionDates.contains(
                              DateTime(date.year, date.month, date.day))) {
                            return Positioned(
                              bottom: 4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: TColors.third,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchSections,
                    child: sectionsForSelectedDate.isEmpty
                        ? const Center(
                            heightFactor: 8.0,
                            child: Text(
                              "No sections for this day",
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: sectionsForSelectedDate.length,
                            itemBuilder: (context, index) {
                              final s = sectionsForSelectedDate[index];
                              return _buildSectionCard(s, darkMode);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  static TimeOfDay? tryParse(String input) {
    try {
      final parts = input.split(RegExp('[: ]'));
      if (parts.length < 3) return null;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      String period = parts[2].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
