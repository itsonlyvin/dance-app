import 'dart:convert';
import 'package:Fin/utils/http/appconfig.dart';
import 'package:Fin/utils/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FeesMarking extends StatefulWidget {
  const FeesMarking({super.key});

  @override
  State<FeesMarking> createState() => _FeesMarkingState();
}

class _FeesMarkingState extends State<FeesMarking> {
  late final String feeApi;
  late final String studentsApi;

  List<int> years = List.generate(6, (i) => 2023 + i);
  List<int> months = List.generate(12, (i) => i + 1);

  int? selectedYear;
  int? selectedMonth;

  String? selectedStudent;
  List<dynamic> students = [];

  final TextEditingController discountController = TextEditingController();
  final TextEditingController penaltyController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  bool paid = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    feeApi = "${AppConfig.baseUrl}/fees/adjust";
    studentsApi = "${AppConfig.baseUrl}/api/students/all";
    fetchStudents();
  }

  // ---------------- Snackbar ----------------
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ---------------- Unified Backend Decoder ----------------
  Map<String, dynamic> unwrap(http.Response res) {
    final success = res.statusCode >= 200 && res.statusCode < 300;

    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map && decoded.containsKey("message")) {
        return {
          "ok": success,
          "message": decoded["message"]?.toString(),
          "data": decoded["data"]
        };
      }

      if (decoded is List) {
        return {
          "ok": success,
          "message": success ? "Success" : "Error",
          "data": decoded
        };
      }

      return {"ok": success, "message": res.body, "data": null};
    } catch (_) {
      return {"ok": success, "message": res.body, "data": null};
    }
  }

  // ---------------- Load Students ----------------
  Future<void> fetchStudents() async {
    try {
      final res = await http.get(Uri.parse(studentsApi));
      final json = unwrap(res);

      if (json["ok"] == true && json["data"] is List) {
        setState(() => students = json["data"]);
      } else {
        showSnack(json["message"] ?? "Failed to load students");
      }
    } catch (e) {
      showSnack("Failed to load students: $e");
    }
  }

  // ---------------- Adjust Fee ----------------
  Future<void> adjustFee() async {
    if (selectedStudent == null ||
        selectedMonth == null ||
        selectedYear == null) {
      showSnack("Select student, year & month");
      return;
    }

    setState(() => isLoading = true);

    final url =
        "$feeApi?studentName=$selectedStudent&year=$selectedYear&month=$selectedMonth"
        "&discount=${discountController.text}"
        "&penalty=${penaltyController.text}"
        "&paid=$paid"
        "&remarks=${remarksController.text}";

    try {
      final res = await http.put(Uri.parse(url));
      final json = unwrap(res);

      showSnack(json["message"] ?? "Updated");
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ---------------- Dropdown Widget ----------------
  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ---------------- Input Field ----------------
  Widget _input(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: (label.contains("Penalty") || label.contains("Discount"))
            ? TextInputType.number
            : TextInputType.text,
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mark / Adjust Fee"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ------------ Student Dropdown ------------
            _dropdown<String>(
              label: "Select Student",
              value: selectedStudent,
              items: students.map<String>((s) => s["studentName"]).toList(),
              onChanged: (v) => setState(() => selectedStudent = v),
            ),

            // ------------ Year/Month Row ------------
            Row(
              children: [
                Expanded(
                  child: _dropdown<int>(
                    label: "Year",
                    value: selectedYear,
                    items: years,
                    onChanged: (v) => setState(() => selectedYear = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown<int>(
                    label: "Month",
                    value: selectedMonth,
                    items: months,
                    onChanged: (v) => setState(() => selectedMonth = v),
                  ),
                ),
              ],
            ),

            // ------------ Fields ------------
            _input(discountController, "Discount"),
            _input(penaltyController, "Penalty"),
            _input(remarksController, "Remarks"),

            CheckboxListTile(
              value: paid,
              onChanged: (v) => setState(() => paid = v!),
              title: const Text("Mark as Paid"),
            ),

            const SizedBox(height: 16),

            // ------------ Submit Button ------------
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading ? null : adjustFee,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Adjustment",
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
