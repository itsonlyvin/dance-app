import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Fin/utils/constants/colors.dart';
import 'package:Fin/utils/constants/sizes.dart';
import 'package:Fin/utils/http/appconfig.dart';

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

  int? selectedStudentId;
  String? selectedStudentName;

  List<dynamic> students = [];
  List<dynamic> monthlyFees = [];
  Map<String, dynamic>? summary;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;

    feeApi = "${AppConfig.baseUrl}/fees";
    studentsApi = "${AppConfig.baseUrl}/api/students/all";

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

  Map<String, dynamic> unwrap(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    try {
      final decoded = jsonDecode(res.body);
      final message = (decoded is Map && decoded.containsKey('message'))
          ? decoded['message']?.toString() ?? ''
          : (ok ? 'Success' : res.body);
      final data = (decoded is Map && decoded.containsKey('data'))
          ? decoded['data']
          : (decoded is List ? decoded : null);
      return {"ok": ok, "message": message, "data": data};
    } catch (e) {
      return {"ok": ok, "message": res.body, "data": null};
    }
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(studentsApi));
      final json = unwrap(res);
      if (json["ok"]) {
        setState(() => students = (json["data"] ?? []) as List<dynamic>);
      } else {
        showSnack(json["message"] ?? "Failed to load students");
      }
    } catch (e) {
      showSnack("Error loading students: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> generateFees() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select year & month");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.post(Uri.parse(
          "$feeApi/generate?year=$selectedYear&month=$selectedMonth"));
      final json = unwrap(res);
      showSnack(json["message"] ?? "");
      if (json["ok"]) await fetchMonthlyStatus();
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchMonthlyStatus() async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select year & month");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(
          Uri.parse("$feeApi/status?year=$selectedYear&month=$selectedMonth"));
      final json = unwrap(res);
      if (json["ok"]) {
        setState(() {
          final raw = json["data"] as dynamic;
          if (raw is List) {
            monthlyFees = raw
                .map<Map<String, dynamic>>((e) => _normalizeFeeEntry(e))
                .toList();
          } else if (raw is Map) {
            monthlyFees = [_normalizeFeeEntry(raw)];
          } else {
            monthlyFees = [];
          }
        });
      } else {
        setState(() => monthlyFees = []);
      }
      showSnack(json["message"] ?? "");
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // OPTION 2 BACKEND STRUCTURE NORMALIZATION
  Map<String, dynamic> _normalizeFeeEntry(dynamic e) {
    try {
      if (e == null || e is! Map) return {};

      int? sid;
      String? sname;

      // flat structure: studentId, studentName
      if (e.containsKey('studentId')) {
        sid = _toInt(e['studentId']);
      } else if (e.containsKey('student') &&
          e['student'] is Map &&
          e['student'].containsKey('id')) {
        sid = _toInt(e['student']['id']);
      }

      if (e.containsKey('studentName')) {
        sname = e['studentName']?.toString();
      } else if (e.containsKey('student') &&
          e['student'] is Map &&
          e['student'].containsKey('studentName')) {
        sname = e['student']['studentName']?.toString();
      }

      return {
        'studentId': sid,
        'studentName': sname ?? (sid != null ? 'Student $sid' : 'Unknown'),
        'year': e['year'],
        'month': e['month'],
        'finalAmount': e['finalAmount'] ?? e['totalFee'] ?? 0,
        'paid': e['paid'] == true,

        // new backend fields – optional but used if present
        'totalScheduledSections': e['totalScheduledSections'] ?? 0,
        'totalScheduledHours':
            (e['totalScheduledHours'] ?? '').toString(), // string or double
        'totalAttendedSections': e['totalAttendedSections'] ?? 0,
        'totalAttendedHours':
            (e['totalAttendedHours'] ?? '').toString(), // string or double

        '__raw': e,
      };
    } catch (ex) {
      return {};
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  Future<void> fetchSummary() async {
    if (selectedStudentId == null ||
        selectedYear == null ||
        selectedMonth == null) {
      showSnack("Select student, year, month");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          "$feeApi/student/summary?studentId=$selectedStudentId&year=$selectedYear&month=$selectedMonth"));
      final json = unwrap(res);
      if (json["ok"]) {
        setState(() {
          final d = json["data"];
          if (d is Map)
            summary = Map<String, dynamic>.from(d);
          else
            summary = null;
        });
      } else {
        setState(() => summary = null);
      }
      showSnack(json["message"] ?? "");
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStudentDetailsDialog(int studentId) async {
    if (selectedYear == null || selectedMonth == null) {
      showSnack("Select year & month first");
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(
          "$feeApi/student/details?studentId=$studentId&year=$selectedYear&month=$selectedMonth"));
      final json = unwrap(res);
      if (json["ok"] && json["data"] != null) {
        final data = Map<String, dynamic>.from(json["data"]);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
                "${data['studentName'] ?? 'Student'} — ${data['month'] ?? selectedMonth}/${data['year'] ?? selectedYear}"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.list_alt, "Scheduled Sections",
                      "${data['totalScheduledSections'] ?? 0}"),
                  _infoRow(Icons.schedule, "Scheduled Hours",
                      "${data['totalScheduledHours'] ?? '0.00'} hrs"),
                  _infoRow(Icons.check_circle, "Attended Sections",
                      "${data['totalAttendedSections'] ?? 0}"),
                  _infoRow(Icons.access_time, "Attended Hours",
                      "${data['totalAttendedHours'] ?? '0.00'} hrs"),
                  const Divider(),
                  _infoRow(Icons.currency_rupee, "Total Fee",
                      "₹${data['totalFee'] ?? 0}"),
                  _infoRow(
                      Icons.discount, "Discount", "₹${data['discount'] ?? 0}"),
                  _infoRow(
                      Icons.money_off, "Penalty", "₹${data['penalty'] ?? 0}"),
                  _infoRow(Icons.check_circle, "Final Amount",
                      "₹${data['finalAmount'] ?? 0}"),
                  const Divider(),
                  _infoRow(Icons.payment, "Paid",
                      (data['paid'] == true) ? "Yes" : "No"),
                  if (data['paymentDate'] != null)
                    _infoRow(Icons.calendar_today, "Payment Date",
                        data['paymentDate'].toString()),
                  if (data['remarks'] != null &&
                      data['remarks'].toString().isNotEmpty)
                    _infoRow(Icons.note, "Remarks", data['remarks'].toString()),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"))
            ],
          ),
        );
      } else {
        showSnack(json["message"] ?? "No details");
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> selectStudentBottomSheet() async {
    String search = "";
    final searchCtrl = TextEditingController();

    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateSB) {
          final filtered = students.where((s) {
            final name = (s['studentName'] ?? '').toString().toLowerCase();
            return name.contains(search.toLowerCase());
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(
                      child: Center(
                          child: Text("Select Student",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)))),
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setStateSB(() {}))
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                      hintText: "Search student by name",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onChanged: (v) => setStateSB(() => search = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: filtered.isEmpty
                      ? const Center(child: Text("No students found"))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = filtered[i] as Map;
                            final name =
                                s['studentName']?.toString() ?? 'Unnamed';
                            final sid = _toInt(s['id']) ?? 0;
                            final initial =
                                name.isNotEmpty ? name[0].toUpperCase() : '?';
                            return ListTile(
                              leading: CircleAvatar(child: Text(initial)),
                              title: Text(name),
                              subtitle: Text("ID: $sid"),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 6),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text("Cancel"))),
              ],
            ),
          );
        });
      },
    );

    if (selected != null && selected is Map) {
      setState(() {
        selectedStudentId = _toInt(selected['id']);
        selectedStudentName = selected['studentName']?.toString();
      });
    }
  }

  Future<void> adjustFeeDialog(Map<String, dynamic> fee) async {
    final discountCtrl = TextEditingController();
    final penaltyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    bool paid = fee['paid'] == true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text("Adjust Fee — ${fee['studentName'] ?? 'Student'}"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _numField(discountCtrl, "Discount (₹)"),
              _numField(penaltyCtrl, "Penalty (₹)"),
              TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: "Remarks")),
              StatefulBuilder(builder: (context, setStateSB) {
                return CheckboxListTile(
                  value: paid,
                  title: const Text("Mark Paid"),
                  onChanged: (v) => setStateSB(() => paid = v ?? false),
                );
              }),
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
              final sid = fee['studentId'] ?? selectedStudentId;
              if (sid == null) {
                showSnack("No student id available");
                return;
              }

              final params = <String>[
                "studentId=$sid",
                "year=${fee['year'] ?? selectedYear}",
                "month=${fee['month'] ?? selectedMonth}",
                "paid=$paid"
              ];

              if (discountCtrl.text.trim().isNotEmpty) {
                final d = discountCtrl.text.trim();
                if (double.tryParse(d) != null) params.add("discount=$d");
              }
              if (penaltyCtrl.text.trim().isNotEmpty) {
                final p = penaltyCtrl.text.trim();
                if (double.tryParse(p) != null) params.add("penalty=$p");
              }
              if (remarksCtrl.text.trim().isNotEmpty) {
                params.add(
                    "remarks=${Uri.encodeComponent(remarksCtrl.text.trim())}");
              }

              final url = "$feeApi/adjust?${params.join('&')}";

              setState(() => isLoading = true);
              try {
                final res = await http.put(Uri.parse(url));
                final json = unwrap(res);
                showSnack(json["message"] ?? "");
                if (json["ok"]) await fetchMonthlyStatus();
              } catch (e) {
                showSnack("Error: $e");
              } finally {
                setState(() => isLoading = false);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    );
  }

  Widget _dropdown<T>(
      {required String label,
      required T? value,
      required List<T> items,
      required void Function(T?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _feeCard(Map<String, dynamic> f, bool darkMode) {
    final studentName = f['studentName']?.toString() ?? 'Unnamed';
    final paid = f['paid'] == true;
    final amt = f['finalAmount'] ?? 0;
    final scheduledHours = f['totalScheduledHours']?.toString() ?? '';
    final attendedHours = f['totalAttendedHours']?.toString() ?? '';
    final year = f['year'] ?? selectedYear;
    final month = f['month'] ?? selectedMonth;
    final studentId = f['studentId'] ?? selectedStudentId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: darkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(studentName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: paid
                      ? TColors.success.withOpacity(0.14)
                      : TColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(paid ? Icons.check_circle : Icons.error_outline,
                    size: 14, color: paid ? TColors.success : TColors.error),
                const SizedBox(width: 6),
                Text(paid ? "PAID" : "UNPAID",
                    style: TextStyle(
                        color: paid ? TColors.success : TColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
            )
          ]),
          // const SizedBox(height: 6),
          // Row(children: [
          //   Icon(Icons.schedule, size: 14, color: TColors.darkGrey),
          //   const SizedBox(width: 6),
          //   Text(
          //       scheduledHours.isNotEmpty
          //           ? "Scheduled: $scheduledHours hrs"
          //           : "Scheduled: -",
          //       style: const TextStyle(fontSize: 13)),
          // ]),
          // const SizedBox(height: 2),
          // Row(children: [
          //   Icon(Icons.check_circle, size: 14, color: TColors.darkGrey),
          //   const SizedBox(width: 6),
          //   Text(
          //       attendedHours.isNotEmpty
          //           ? "Attended: $attendedHours hrs"
          //           : "Attended: -",
          //       style: const TextStyle(fontSize: 13)),
          // ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_month, size: 14, color: TColors.darkGrey),
            const SizedBox(width: 6),
            Text("${month ?? '-'} / ${year ?? '-'}",
                style: const TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.currency_rupee, size: 16, color: TColors.darkGrey),
            const SizedBox(width: 6),
            Text("₹$amt",
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                  onPressed: studentId != null
                      ? () => fetchStudentDetailsDialog(studentId)
                      : null,
                  icon: const Icon(Icons.info_outline),
                  label: const Text("Details")),
              const SizedBox(width: 8),
              TextButton.icon(
                  onPressed: () => adjustFeeDialog({
                        'studentId': studentId,
                        'studentName': studentName,
                        'year': year,
                        'month': month,
                        'paid': paid
                      }),
                  icon: const Icon(Icons.settings),
                  label: const Text("Adjust")),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: TColors.darkGrey),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]));
  }

  Widget _summaryCard(Map<String, dynamic> s, bool darkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: darkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s["studentName"] ?? "-",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _infoRow(Icons.class_, "Scheduled Sections",
            "${s['totalScheduledSections'] ?? 0}"),
        _infoRow(Icons.schedule, "Scheduled Hours",
            "${s['scheduledHours'] ?? '0.00'} hrs"),
        _infoRow(Icons.check_circle, "Attended Sections",
            "${s['attendedSections'] ?? 0}"),
        _infoRow(Icons.access_time_filled, "Attended Hours",
            "${s['attendedHours'] ?? '0.00'} hrs"),
        _infoRow(Icons.close, "Absent Sections", "${s['absentSections'] ?? 0}"),
        const Divider(),
        _infoRow(Icons.currency_rupee, "Total Fee", "₹${s['totalFee'] ?? 0}"),
        _infoRow(Icons.discount, "Discount", "₹${s['discount'] ?? 0}"),
        _infoRow(Icons.money_off, "Penalty", "₹${s['penalty'] ?? 0}"),
        _infoRow(
            Icons.check_circle, "Final Amount", "₹${s['finalAmount'] ?? 0}"),
        const Divider(),
        Row(children: [
          const Text("Status: ", style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Chip(
              backgroundColor: (s['paid'] == true)
                  ? TColors.success.withOpacity(0.14)
                  : TColors.error.withOpacity(0.12),
              label: Text(s['paid'] == true ? "PAID" : "UNPAID",
                  style: TextStyle(
                      color:
                          s['paid'] == true ? TColors.success : TColors.error,
                      fontWeight: FontWeight.bold)))
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Scaffold(
        appBar: AppBar(title: const Text("Fees"), centerTitle: true),
        // floatingActionButton: FloatingActionButton.extended(
        //     onPressed: generateFees,
        //     label: const Text("Generate Fees"),
        //     icon: const Icon(Icons.auto_awesome),
        //     backgroundColor: TColors.primary),
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: RefreshIndicator(
              onRefresh: () async {
                await fetchStudents();
                await fetchMonthlyStatus();
              },
              child: ListView(children: [
                Row(children: [
                  Expanded(
                      child: _dropdown(
                          label: "Year",
                          value: selectedYear,
                          items: years,
                          onChanged: (v) => setState(() => selectedYear = v))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _dropdown(
                          label: "Month",
                          value: selectedMonth,
                          items: months,
                          onChanged: (v) => setState(() => selectedMonth = v))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: fetchMonthlyStatus,
                          icon: const Icon(Icons.visibility),
                          label: const Text("Monthly Status"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.info))),
                  const SizedBox(width: TSizes.spaceBtwInputFields),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: selectStudentBottomSheet,
                          icon: const Icon(Icons.person_search),
                          label: Text(selectedStudentName ?? "Select Student"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.secondary))),
                ]),
                const SizedBox(height: TSizes.spaceBtwItems),
                const SizedBox(height: 8),
                Text("Monthly Report",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (monthlyFees.isEmpty)
                  Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: darkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                          child:
                              Text("No fee records found for selected month")))
                else
                  ...monthlyFees.map(
                      (f) => _feeCard(f as Map<String, dynamic>, darkMode)),
                const SizedBox(height: 12),
                Text("Student Monthly Summary",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: fetchSummary,
                          icon: const Icon(Icons.bar_chart),
                          label: const Text("View Summary"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.success))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () => selectedStudentId != null
                              ? fetchStudentDetailsDialog(selectedStudentId!)
                              : showSnack("Select a student first"),
                          icon: const Icon(Icons.info),
                          label: const Text("Details"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: TColors.info))),
                ]),
                const SizedBox(height: 8),
                if (summary != null) _summaryCard(summary!, darkMode),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ),
      ),
      if (isLoading)
        Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator())),
    ]);
  }
}
