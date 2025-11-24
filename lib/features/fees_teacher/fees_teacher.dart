import 'dart:convert';
import 'package:Fin/utils/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Fin/utils/http/appconfig.dart';

class TeacherFeePage extends StatefulWidget {
  const TeacherFeePage({super.key});

  @override
  State<TeacherFeePage> createState() => _TeacherFeePageState();
}

class _TeacherFeePageState extends State<TeacherFeePage> {
  late final String teachersApi;
  late final String detailsApi;
  late final String adjustApi;

  List<Map<String, dynamic>> teachers = [];
  Map<String, dynamic>? selectedTeacher;
  Map<String, dynamic>? report;

  int? year;
  int? month;
  bool loading = false;

  final years = List.generate(6, (i) => 2023 + i);
  final months = List.generate(12, (i) => i + 1);

  @override
  void initState() {
    super.initState();

    teachersApi = "${AppConfig.baseUrl}/api/teacher/all";
    detailsApi = "${AppConfig.baseUrl}/teacher-fees/details";
    adjustApi = "${AppConfig.baseUrl}/teacher-fees/adjust";

    final now = DateTime.now();
    year = now.year;
    month = now.month;

    loadTeachers();
  }

  void toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // =================================================================
  // 1️⃣ LOAD TEACHERS
  // =================================================================
  Future<void> loadTeachers() async {
    try {
      setState(() => loading = true);
      final res = await http.get(Uri.parse(teachersApi));
      final body = jsonDecode(res.body);

      if (body["data"] is List) {
        teachers = List<Map<String, dynamic>>.from(body["data"]);
      }
    } catch (e) {
      toast("Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // =================================================================
  // 2️⃣ FETCH TEACHER MONTHLY FEE DETAILS
  // =================================================================
  Future<void> loadReport() async {
    if (selectedTeacher == null) {
      toast("Please select teacher");
      return;
    }

    try {
      setState(() => loading = true);

      final id = selectedTeacher!["id"];
      final res = await http.get(
        Uri.parse("$detailsApi?teacherId=$id&year=$year&month=$month"),
      );

      final json = jsonDecode(res.body);

      if (json["data"] != null) {
        report = Map<String, dynamic>.from(json["data"]);
      } else {
        report = null;
      }

      toast(json["message"] ?? "");
    } catch (e) {
      toast("Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // =================================================================
  // 3️⃣ ADJUST SALARY DIALOG
  // =================================================================
  Future<void> adjustDialog() async {
    if (report == null) return;

    final bonusCtrl = TextEditingController();
    final penaltyCtrl = TextEditingController();
    final payModeCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    bool paid = report?["feeRecord"]?["paid"] ?? false;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Adjust Salary — ${report!['teacherName']}"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              numberField(bonusCtrl, "Bonus ₹"),
              numberField(penaltyCtrl, "Penalty ₹"),
              textField(payModeCtrl, "Payment Mode (Cash/UPI/Bank)"),
              textField(remarksCtrl, "Remarks"),
              StatefulBuilder(
                builder: (ctx, setSB) => CheckboxListTile(
                  title: const Text("Mark Paid"),
                  value: paid,
                  onChanged: (v) => setSB(() => paid = v ?? false),
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await submitAdjustment(
                bonus: bonusCtrl.text,
                penalty: penaltyCtrl.text,
                payMode: payModeCtrl.text,
                remarks: remarksCtrl.text,
                paid: paid,
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // 4️⃣ SEND PUT JSON PAYLOAD
  // =================================================================
  Future<void> submitAdjustment({
    required String bonus,
    required String penalty,
    required String payMode,
    required String remarks,
    required bool paid,
  }) async {
    try {
      setState(() => loading = true);

      // Basic payload
      final body = {
        "teacherId": selectedTeacher!["id"],
        "year": year,
        "month": month,
        "paid": paid
      };

      // If fee record exists
      if (report?["feeRecord"]?["id"] != null) {
        body["teacherFeeId"] = report!["feeRecord"]["id"];
      }

      if (bonus.isNotEmpty && double.tryParse(bonus) != null) {
        body["bonus"] = double.parse(bonus);
      }
      if (penalty.isNotEmpty && double.tryParse(penalty) != null) {
        body["penalty"] = double.parse(penalty);
      }
      if (payMode.isNotEmpty) {
        body["paymentMode"] = payMode;
      }
      if (remarks.isNotEmpty) {
        body["remarks"] = remarks;
      }

      final res = await http.put(
        Uri.parse(adjustApi),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final json = jsonDecode(res.body);
      toast(json["message"] ?? "Updated");
      await loadReport();
    } catch (e) {
      toast("Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // =================================================================
  // UI HELPERS
  // =================================================================
  Widget numberField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: label,
        ),
      ),
    );
  }

  Widget textField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelText: label,
        ),
      ),
    );
  }

  Widget dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChange,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelText: label,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
            .toList(),
        onChanged: onChange,
      ),
    );
  }

  // =================================================================
  // PAID STATUS UI
  // =================================================================
  Widget feeStatusChip(bool paid) {
    return Chip(
      label: Text(
        paid ? "PAID" : "UNPAID",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: paid ? TColors.success : TColors.error,
        ),
      ),
      backgroundColor: paid
          ? TColors.success.withOpacity(.15)
          : TColors.error.withOpacity(.15),
    );
  }

  // =================================================================
  // SALARY CARD
  // =================================================================
  Widget salaryCard(Map<String, dynamic> r) {
    final paid = r["feeRecord"]?["paid"] == true;
    final payMode = r["feeRecord"]?["paymentMode"] ?? "-";
    final remarks = r["feeRecord"]?["remarks"] ?? null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            r["teacherName"],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          feeStatusChip(paid),
          const Divider(height: 20),
          Text("Hourly Rate: ₹${r['salaryPerHour']}"),
          Text("Base Salary: ₹${r['calculatedTotal']}"),
          Text("Bonus: ₹${r['bonus']}"),
          Text("Penalty: ₹${r['penalty']}"),
          const SizedBox(height: 10),
          Text(
            "Final Salary: ₹${r['finalSalary']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text("Payment Mode: $payMode"),
          if (remarks != null && remarks.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text("Remarks: $remarks"),
            ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: adjustDialog,
            icon: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.edit),
            ),
            label: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Adjust Salary"),
            ),
          ),
        ]),
      ),
    );
  }

  Widget sectionCard(Map<String, dynamic> s) {
    return Card(
      child: ListTile(
        title: Text(s["courseName"]),
        subtitle: Text("${s['date']} — Students: ${s['registeredStudents']}"),
        trailing: Text(
          "₹${s['sectionSalary']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // =================================================================
  // UI
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Monthly Salary Report")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: dropdown(
                        label: "Year",
                        value: year,
                        items: years,
                        onChange: (v) => setState(() => year = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: dropdown(
                        label: "Month",
                        value: month,
                        items: months,
                        onChange: (v) => setState(() => month = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: InputDecoration(
                    labelText: "Select Teacher",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  value: selectedTeacher,
                  items: teachers
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t["teacherName"]),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedTeacher = v;
                      report = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: loadReport,
                  icon: const Icon(Icons.search),
                  label: const Text("Load Report"),
                ),
                const SizedBox(height: 20),
                if (report == null)
                  const Center(child: Text("No report loaded"))
                else ...[
                  salaryCard(report!),
                  const SizedBox(height: 12),
                  const Text(
                    "Sections Breakdown",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(
                    (report!["sections"] as List).length,
                    (i) => sectionCard(
                      Map<String, dynamic>.from(report!["sections"][i]),
                    ),
                  )
                ]
              ],
            ),
          ),
          if (loading) const Center(child: CircularProgressIndicator())
        ],
      ),
    );
  }
}
