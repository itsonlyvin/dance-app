import 'dart:convert';
import 'package:Fin/appConfig.dart';
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

  List<dynamic> sections = [];
  List<dynamic> allStudents = [];
  List<String> selectedStudents = [];
  bool isLoading = false;

  DateTime focusedDay = DateTime.now();
  DateTime selectedDate = DateTime.now();

  final TextEditingController teacherController = TextEditingController();
  final TextEditingController courseController = TextEditingController();
  final TextEditingController timeFromController = TextEditingController();
  final TextEditingController timeToController = TextEditingController();

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

  Future<void> fetchStudents() async {
    try {
      final response = await http.get(Uri.parse(studentsApi));
      if (response.statusCode == 200) {
        setState(() => allStudents = jsonDecode(response.body));
      } else {
        showSnack("Failed to load students");
      }
    } catch (e) {
      showSnack("Error fetching students: $e");
    }
  }

  Future<void> fetchSections() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$sectionApi/all"));
      if (response.statusCode == 200) {
        setState(() => sections = jsonDecode(response.body));
      } else {
        showSnack("Error loading sections");
      }
    } catch (e) {
      showSnack("Connection error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get sectionsForSelectedDate {
    final dateString = selectedDate.toIso8601String().split('T')[0];
    return sections.where((s) => s['date']?.toString() == dateString).toList();
  }

  Set<DateTime> get sectionDates {
    return sections
        .map((s) => DateTime.parse(s['date']))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
  }

  Future<void> createOrUpdateSection({Map<String, dynamic>? section}) async {
    final isEdit = section != null;

    final payload = isEdit
        ? {
            "oldTeacherName": section["teacherName"],
            "oldCourseName": section["courseName"],
            "oldDate": section["date"],
            "oldTimeFrom": section["timeFrom"],
            "oldTimeTo": section["timeTo"],
            "newTeacherName": teacherController.text.trim(),
            "newCourseName": courseController.text.trim(),
            "newDate": selectedDate.toIso8601String().split('T')[0],
            "newTimeFrom": timeFromController.text.trim(),
            "newTimeTo": timeToController.text.trim(),
            "students": selectedStudents,
          }
        : {
            "teacherName": teacherController.text.trim(),
            "courseName": courseController.text.trim(),
            "date": selectedDate.toIso8601String().split('T')[0],
            "timeFrom": timeFromController.text.trim(),
            "timeTo": timeToController.text.trim(),
            "students": selectedStudents,
          };

    final uri = isEdit ? "$sectionApi/update" : "$sectionApi/create";
    final method = isEdit ? http.put : http.post;

    try {
      final response = await method(
        Uri.parse(uri),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      showSnack(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchSections();
        Navigator.pop(context);
      }
    } catch (e) {
      showSnack("Error saving section: $e");
    }
  }

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

      showSnack(response.body);
      if (response.statusCode == 200) fetchSections();
    } catch (e) {
      showSnack("Error deleting section: $e");
    }
  }

  void openSectionDialog({Map<String, dynamic>? section}) {
    final isEdit = section != null;

    if (isEdit) {
      teacherController.text = section!["teacherName"];
      courseController.text = section["courseName"];
      selectedDate = DateTime.parse(section["date"]);
      timeFromController.text = section["timeFrom"];
      timeToController.text = section["timeTo"];
      selectedStudents = List<String>.from(section["students"] ?? []);
    } else {
      teacherController.clear();
      courseController.clear();
      timeFromController.clear();
      timeToController.clear();
      selectedStudents.clear();
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            padding: const EdgeInsets.all(TSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: TSizes.defaultSpace),
                Center(
                  child: Text(
                    isEdit ? "Edit Section" : "Add Section",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: TSizes.defaultSpace),
                _textField(teacherController, "Teacher Name"),
                _textField(courseController, "Course Name"),
                // Time Pickers
                const SizedBox(height: TSizes.spaceBtwItems),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          // 🕓 Try to read the current time from the controller
                          TimeOfDay initialTime = TimeOfDay.now();

                          if (timeFromController.text.isNotEmpty) {
                            try {
                              // Parse the text like "2:30 PM" → TimeOfDay
                              final format = TimeOfDayFormat
                                  .h_colon_mm_space_a; // Default 12-hr
                              final localizations =
                                  MaterialLocalizations.of(context);
                              initialTime =
                                  localizations.timeOfDayFormat == format
                                      ? localizations.timeOfDayFormat
                                          as TimeOfDay // not correct
                                      : TimeOfDay.now();

                              // Easier way: parse manually
                              final parsed = TimeOfDayExtension.tryParse(
                                  timeFromController.text);
                              if (parsed != null) initialTime = parsed;
                            } catch (_) {}
                          }

                          final picked = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );

                          if (picked != null) {
                            timeFromController.text = picked.format(context);
                          }
                        },
                        child: AbsorbPointer(
                          child: _textField(
                            timeFromController,
                            "From",
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TSizes.spaceBtwItems),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          // 🕓 Try to read the current time from the controller
                          TimeOfDay initialTime = TimeOfDay.now();

                          if (timeToController.text.isNotEmpty) {
                            try {
                              // Parse the text like "2:30 PM" → TimeOfDay
                              final format = TimeOfDayFormat
                                  .h_colon_mm_space_a; // Default 12-hr
                              final localizations =
                                  MaterialLocalizations.of(context);
                              initialTime =
                                  localizations.timeOfDayFormat == format
                                      ? localizations.timeOfDayFormat
                                          as TimeOfDay // not correct
                                      : TimeOfDay.now();

                              // Easier way: parse manually
                              final parsed = TimeOfDayExtension.tryParse(
                                  timeToController.text);
                              if (parsed != null) initialTime = parsed;
                            } catch (_) {}
                          }

                          final picked = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );

                          if (picked != null) {
                            timeToController.text = picked.format(context);
                          }
                        },
                        child: AbsorbPointer(
                          child: _textField(
                            timeToController,
                            "To",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TSizes.spaceBtwItems),
                OutlinedButton.icon(
                  onPressed: () => _selectStudents(setState),
                  icon: const Icon(Icons.group_add, color: TColors.secondary),
                  label: const Text("Select Students"),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: TColors.secondary),
                    foregroundColor: TColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: selectedStudents
                      .map((s) => Chip(
                            label: Text(s),
                            backgroundColor: TColors.secondary.withOpacity(0.1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: TSizes.spaceBtwItems),
                ElevatedButton(
                  onPressed: () => createOrUpdateSection(section: section),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: TColors.primary,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text(isEdit ? "Update Section" : "Save Section"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectStudents(StateSetter parentSetState) async {
    final List<String> tempSelected = List.from(selectedStudents);

    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor:
            THelperFunctions.isDarkMode(context) ? TColors.dark : Colors.white,
        title: const Text(
          "Select Students",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height:
              MediaQuery.of(context).size.height * 0.5, // limit dialog height
          child: Scrollbar(
            thumbVisibility: true,
            radius: const Radius.circular(8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allStudents.length,
              itemBuilder: (context, index) {
                final s = allStudents[index];
                final name = s["studentName"] ?? "Unnamed";
                final selected = tempSelected.contains(name);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? TColors.secondary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CheckboxListTile(
                    title: Text(name),
                    value: selected,
                    activeColor: TColors.secondary,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged: (checked) {
                      (context as Element)
                          .markNeedsBuild(); // refresh state safely
                      if (checked == true) {
                        tempSelected.add(name);
                      } else {
                        tempSelected.remove(name);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, tempSelected),
            child: const Text("Done"),
          ),
        ],
      ),
    );

    // Update parent state if user pressed "Done"
    if (result != null) {
      parentSetState(() {
        selectedStudents = result;
      });
    }
  }

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

      /// Raised FloatingActionButton
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,

      floatingActionButton: Obx(
        () {
          final controller = Get.find<NavigationController>();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
            padding: EdgeInsets.only(
              bottom: controller.isNavVisible.value
                  ? 95.0
                  : 12.0, // moves when nav hides
              right: controller.isNavVisible.value ? 15 : 1,
            ),
            child: FloatingActionButton(
              onPressed: () => openSectionDialog(),
              backgroundColor: TColors.primary,
              elevation: 6,
              child: const Icon(Icons.add, size: 28),
            ),
          );
        },
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar Card
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
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: darkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
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
                                    "${s['teacherName']} - ${s['courseName']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                  subtitle: Text(
                                    "${s['timeFrom']} - ${s['timeTo']}\nStudents: ${(s['students'] as List?)?.join(', ') ?? 'None'}",
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        openSectionDialog(section: s);
                                      } else if (value == 'delete') {
                                        deleteSection(s);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete')),
                                    ],
                                  ),
                                ),
                              );
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
