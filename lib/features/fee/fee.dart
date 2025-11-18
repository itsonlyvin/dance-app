import 'dart:convert';
import 'dart:ui';
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/sizes.dart';
import 'package:Fin/utils/http/appconfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Fee extends StatefulWidget {
  const Fee({super.key});

  @override
  State<Fee> createState() => _FeeState();
}

class _FeeState extends State<Fee> {
  late final String feeApi;
  late final String studentsApi;

  List<int> years = List.generate(6, (i) => 2023 + i);
  List<int> months = List.generate(12, (i) => i + 1);

  int? selectedYear;
  int? selectedMonth;
  String? selectedStudent;

  List<dynamic> students = [];
  List<dynamic> monthlyFees = [];
  Map<String, dynamic>? summary;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    DateTime now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;

    feeApi = "${AppConfig.baseUrl}/fees";
    studentsApi = "${AppConfig.baseUrl}/api/students/all";
    fetchStudents();
  }

  // ************** SNACKBAR (same as Students page) **************
  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ************** UNWRAP RESPONSE **************
  Map<String, dynamic> unwrap(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;

    try {
      final decoded = jsonDecode(res.body);

      return {
        "ok": ok,
        "message": decoded["message"]?.toString() ?? "",
        "data": decoded["data"],
      };
    } catch (e) {
      return {
        "ok": ok,
        "message": res.body,
        "data": null,
      };
    }
  }

  // ************** FETCH STUDENTS **************
  Future<void> fetchStudents() async {
    try {
      final res = await http.get(Uri.parse(studentsApi));
      final json = unwrap(res);

      if (json["ok"]) {
        setState(() => students = json["data"] ?? []);
      } else {
        showSnack(json["message"]);
      }
    } catch (e) {
      showSnack("Error loading students: $e");
    }
  }

  // ************** GENERATE FEES **************
  Future<void> generateFees() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select Year & Month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("$feeApi/generate?year=$selectedYear&month=$selectedMonth"),
      );

      final json = unwrap(res);
      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ************** FETCH MONTHLY STATUS **************
  Future<void> fetchMonthlyStatus() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select Year & Month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.get(
        Uri.parse("$feeApi/status?year=$selectedYear&month=$selectedMonth"),
      );

      final json = unwrap(res);
      if (json["ok"]) {
        setState(() => monthlyFees = json["data"] ?? []);
      }

      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ************** FETCH SUMMARY REPORT **************
  Future<void> fetchSummary() async {
    if (selectedStudent == null ||
        selectedYear == null ||
        selectedMonth == null) {
      showSnack("Select student year month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse(
          "$feeApi/student/$selectedStudent/$selectedYear/$selectedMonth"));

      final json = unwrap(res);

      if (json["ok"]) {
        setState(() => summary = json["data"]);
      } else {
        setState(() => summary = null);
      }

      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ************** UI HELPER WIDGETS **************
  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ************** PAGE UI **************
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Fees"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: fetchStudents,
              ),
            ],
          ),
          body: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _dropdown(
                            label: "Year",
                            value: selectedYear,
                            items: years,
                            onChanged: (v) => setState(() => selectedYear = v)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdown(
                            label: "Month",
                            value: selectedMonth,
                            items: months,
                            onChanged: (v) =>
                                setState(() => selectedMonth = v)),
                      ),
                    ],
                  ),

                  ElevatedButton(
                      onPressed: generateFees,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.primary),
                      child: const Text("Generate Monthly Fees")),
                  const SizedBox(height: TSizes.spaceBtwItems),

                  ElevatedButton(
                      onPressed: fetchMonthlyStatus,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: TColors.info),
                      child: const Text("View Monthly Status")),
                  const SizedBox(height: TSizes.spaceBtwItems),

                  // ************** MONTHLY FEES LIST **************
                  ExpansionTile(
                    title: const Text(
                      "Monthly Fees",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      if (monthlyFees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No fee records found"),
                        )
                      else
                        ...monthlyFees.map((f) => _feeCard(f, isDark)),
                    ],
                  ),

                  const SizedBox(height: TSizes.spaceBtwItems),

                  // ************** SUMMARY REPORT **************
                  ExpansionTile(
                    title: const Text("Student Monthly Summary",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    children: [
                      _dropdown(
                        label: "Select Student",
                        value: selectedStudent,
                        items: students
                            .map<String>((s) => s["studentName"])
                            .toList(),
                        onChanged: (v) => setState(() => selectedStudent = v),
                      ),
                      ElevatedButton(
                          onPressed: fetchSummary,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.success),
                          child: const Text("View Summary")),
                      if (summary != null) _summaryCard(summary!, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ************** MONTHLY FEE CARD (same UI style as Students page) **************
  Widget _feeCard(dynamic f, bool isDark) {
    bool paid = f["paid"] ?? false;

    String hours = "";
    if (f["totalHours"] != null) hours = "${f["totalHours"]} hrs";
    if (f["totalHoursStudied"] != null) hours = "${f["totalHoursStudied"]} hrs";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? Colors.grey[900]!.withOpacity(0.8) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        title: Text("${f["studentName"]} • $hours",
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("Amount: ₹${f["finalAmount"]}"),
        trailing: Chip(
          label: Text(
            paid ? "PAID" : "UNPAID",
            style: TextStyle(
                color: paid ? Colors.green[900] : Colors.red[900],
                fontWeight: FontWeight.bold),
          ),
          backgroundColor: paid
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
        ),
      ),
    );
  }

  // ************** SUMMARY CARD **************
  Widget _summaryCard(Map<String, dynamic> s, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.grey[900]!.withOpacity(0.8) : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s["studentName"],
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _row("Total Sections", s["totalSectionsAvailable"].toString()),
          _row("Present", s["sectionsPresent"].toString()),
          _row("Absent", s["sectionsAbsent"].toString()),
          _row("Hours Studied", s["totalHoursStudied"].toString()),
          const Divider(),
          _row("Total Fee", "₹${s["totalFee"]}"),
          _row("Discount", "₹${s["discount"]}"),
          _row("Penalty", "₹${s["penalty"]}"),
          _row("Final Amount", "₹${s["finalAmount"]}"),
          const Divider(),
          Row(
            children: [
              const Text("Status: ", style: TextStyle(fontSize: 16)),
              Chip(
                backgroundColor: s["paid"]
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                label: Text(
                  s["paid"] ? "PAID" : "UNPAID",
                  style: TextStyle(
                    color: s["paid"] ? Colors.green[900] : Colors.red[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
