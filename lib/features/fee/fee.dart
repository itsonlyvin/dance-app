import 'dart:convert';
import 'package:Fin/utils/http/appconfig.dart';
import 'package:Fin/utils/constants/colors.dart';
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
  Map<String, dynamic>? studentFee;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    /// PRE-SELECT CURRENT MONTH & YEAR
    DateTime now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;

    feeApi = "${AppConfig.baseUrl}/fees";
    studentsApi = "${AppConfig.baseUrl}/api/students/all";
    fetchStudents();
  }

  // -------- SNACK --------
  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------- UNIFIED BACKEND RESPONSE PARSER --------
  Map<String, dynamic> unwrap(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;

    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map) {
        return {
          "ok": ok,
          "message":
              decoded["message"]?.toString() ?? (ok ? "Success" : "Error"),
          "data": decoded["data"]
        };
      }

      if (decoded is List) {
        return {"ok": ok, "message": ok ? "Success" : "Error", "data": decoded};
      }

      return {"ok": ok, "message": res.body, "data": null};
    } catch (_) {
      return {"ok": ok, "message": res.body, "data": null};
    }
  }

  // -------- FETCH STUDENTS --------
  Future<void> fetchStudents() async {
    try {
      final res = await http.get(Uri.parse(studentsApi));
      final json = unwrap(res);

      if (json["ok"] == true) {
        final raw = json["data"];
        setState(() => students = raw is List ? raw : []);
      } else {
        showSnack(json["message"]);
      }
    } catch (e) {
      showSnack("Error loading students: $e");
    }
  }

  // -------- GENERATE FEES --------
  Future<void> generateFees() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select Year & Month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = "$feeApi/generate?year=$selectedYear&month=$selectedMonth";
      final res = await http.post(Uri.parse(url));

      final json = unwrap(res);
      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // -------- MONTHLY STATUS --------
  Future<void> fetchMonthlyStatus() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select Year & Month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = "$feeApi/status?year=$selectedYear&month=$selectedMonth";
      final res = await http.get(Uri.parse(url));

      final json = unwrap(res);

      if (json["ok"] == true) {
        final raw = json["data"];
        setState(() => monthlyFees = raw is List ? raw : []);
      }

      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // -------- INDIVIDUAL STUDENT FEE --------
  Future<void> fetchStudentFee() async {
    if (selectedStudent == null ||
        selectedYear == null ||
        selectedMonth == null) {
      showSnack("Select Student, Year & Month");
      return;
    }

    setState(() => isLoading = true);

    try {
      final url =
          "$feeApi/student?name=$selectedStudent&year=$selectedYear&month=$selectedMonth";

      final res = await http.get(Uri.parse(url));
      final json = unwrap(res);

      setState(() => studentFee = json["ok"] ? json["data"] : null);

      showSnack(json["message"]);
    } catch (e) {
      showSnack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  // -------- ADJUST FEE --------
  Future<void> adjustFee(Map<String, dynamic> fee) async {
    final TextEditingController discount = TextEditingController();
    final TextEditingController penalty = TextEditingController();
    final TextEditingController remarks = TextEditingController();
    bool paid = fee["paid"] ?? false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Adjust Fee (${fee["studentName"]})"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField(discount, "Discount"),
              _numberField(penalty, "Penalty"),
              TextField(
                controller: remarks,
                decoration: const InputDecoration(labelText: "Remarks"),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setStateSB) => CheckboxListTile(
                  value: paid,
                  title: const Text("Mark as Paid"),
                  onChanged: (v) => setStateSB(() => paid = v!),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(context);

              try {
                final url =
                    "$feeApi/adjust?studentName=${fee["studentName"]}&year=${fee["year"]}&month=${fee["month"]}"
                    "&discount=${discount.text}&penalty=${penalty.text}&paid=$paid&remarks=${remarks.text}";

                final res = await http.put(Uri.parse(url));
                final json = unwrap(res);

                showSnack(json["message"]);
                fetchMonthlyStatus();
              } catch (e) {
                showSnack("Error: $e");
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // -------- UI HELPERS --------
  Widget _numberField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: Theme.of(context).colorScheme.surfaceVariant,
        iconEnabledColor: Theme.of(context).colorScheme.onSurface,
        style: Theme.of(context).textTheme.bodyMedium,
        underline: const SizedBox(),
        hint: Text(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ---------------- PAGE UI ---------------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Fees"),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dropdown<int>(
                        label: "Select Year",
                        value: selectedYear,
                        items: years,
                        onChanged: (v) => setState(() => selectedYear = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdown<int>(
                        label: "Select Month",
                        value: selectedMonth,
                        items: months,
                        onChanged: (v) => setState(() => selectedMonth = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: generateFees,
                  label: const Text("Generate Monthly Fees"),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.list_alt),
                  onPressed: fetchMonthlyStatus,
                  label: const Text("View Monthly Status"),
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  title: const Text(
                    "Monthly Fees",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    if (monthlyFees.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("No monthly fee records found."),
                      )
                    else
                      ...monthlyFees.map((f) => _feeCard(f)).toList(),
                  ],
                ),
                const Divider(height: 40, thickness: 1),
                ExpansionTile(
                  title: const Text(
                    "Student Fee Details",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    _dropdown<String>(
                      label: "Select Student",
                      value: selectedStudent,
                      items: students
                          .map<String>((s) => s["studentName"])
                          .toList(),
                      onChanged: (v) => setState(() => selectedStudent = v),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: fetchStudentFee,
                      child: const Text("View Student Fee Details"),
                    ),
                    if (studentFee != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _feeCard(studentFee!, showAdjust: false),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isLoading)
          Container(
            color: Colors.black38,
            child: const Center(child: CircularProgressIndicator()),
          )
      ],
    );
  }

  // -------- Fee Card --------
  Widget _feeCard(dynamic f, {bool showAdjust = true}) {
    bool paid = f["paid"] ?? false;

    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: paid ? Colors.green : Colors.red,
          child: Icon(
            paid ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          "${f["studentName"]} • ${f["totalHours"]} hrs",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          "Final Amount: ₹${f["finalAmount"]}",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: showAdjust
            ? IconButton(
                icon: const Icon(Icons.settings),
                color: Theme.of(context).iconTheme.color,
                onPressed: () => adjustFee(f),
              )
            : null,
      ),
    );
  }
}
