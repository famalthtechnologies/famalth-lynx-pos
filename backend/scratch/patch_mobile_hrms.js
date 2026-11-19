const fs = require('fs');
const file = 'lib/screens/mobile_billing/mobile_billing_app_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

// 1. Add import for EmployeePortalScreen
if (!txt.includes("import '../hrms/employee_portal_screen.dart';")) {
  txt = txt.replace(
    "import '../hrms/attendance_screen.dart';",
    "import '../hrms/attendance_screen.dart';\nimport '../hrms/employee_portal_screen.dart';"
  );
}

// 2. Add HRMS metrics & office state variables
if (!txt.includes('List<Map<String, dynamic>> _hrmsOffices = [];')) {
  txt = txt.replace(
`  int _hrmsStaffTotal = 0;
  int _hrmsPresentToday = 0;
  int _hrmsOnLeaveToday = 0;
  int _hrmsAbsentToday = 0;
  bool _loadingHrms = false;`,
`  int _hrmsStaffTotal = 0;
  int _hrmsPresentToday = 0;
  int _hrmsOnLeaveToday = 0;
  int _hrmsAbsentToday = 0;
  int _hrmsLateArrivalsToday = 0;
  int _hrmsEarlyDeparturesToday = 0;
  double _hrmsOvertimeHoursToday = 0.0;
  double _hrmsWorkHoursToday = 0.0;
  int _hrmsGeofenceViolationsToday = 0;
  List<Map<String, dynamic>> _hrmsOffices = [];
  String _selectedHrmsOfficeId = 'all';
  bool _loadingHrms = false;`
  );
}

// 3. Update _loadHrmsData implementation
const oldLoadHrms = `  Future<void> _loadHrmsData({bool silent = true}) async {
    if (!silent && mounted) setState(() => _loadingHrms = true);
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final empRes = await ApiClient.get(ApiEndpoints.hrmsEmployees, silent: true);
      final attRes = await ApiClient.get('\${ApiEndpoints.hrmsAttendance}?date=\$todayStr', silent: true);
      final leaveRes = await ApiClient.get(ApiEndpoints.hrmsLeaves, silent: true);

      if (mounted) {
        int total = 0;
        if (empRes != null && empRes['data'] is List) {
          total = (empRes['data'] as List).length;
        }

        int present = 0;
        if (attRes != null && attRes['data'] is List) {
          present = (attRes['data'] as List).length;
        }

        int onLeave = 0;
        if (leaveRes != null && leaveRes['data'] is List) {
          final leaves = leaveRes['data'] as List;
          onLeave = leaves.where((l) => (l['status'] ?? '').toString().toUpperCase() == 'APPROVED').length;
        }

        int absent = total > (present + onLeave) ? (total - present - onLeave) : 0;

        setState(() {
          _hrmsStaffTotal = total;
          _hrmsPresentToday = present;
          _hrmsOnLeaveToday = onLeave;
          _hrmsAbsentToday = absent;
          _loadingHrms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHrms = false);
    }
  }`;

const newLoadHrms = `  Future<void> _loadHrmsData({bool silent = true}) async {
    if (!silent && mounted) setState(() => _loadingHrms = true);
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsOffices, silent: true),
        ApiClient.get('\${ApiEndpoints.hrmsDashboardOverview}?office_id=\$_selectedHrmsOfficeId', silent: true),
      ]);
      final officesRes = results[0];
      final overviewRes = results[1];

      if (mounted) {
        if (officesRes != null && officesRes['data'] is List) {
          _hrmsOffices = List<Map<String, dynamic>>.from(officesRes['data']);
        }
        if (overviewRes != null && overviewRes['success'] == true && overviewRes['metrics'] != null) {
          final m = overviewRes['metrics'];
          setState(() {
            _hrmsStaffTotal = m['totalEmployees'] ?? 0;
            _hrmsPresentToday = m['presentToday'] ?? 0;
            _hrmsAbsentToday = m['absentToday'] ?? 0;
            _hrmsOnLeaveToday = m['onLeaveToday'] ?? 0;
            _hrmsLateArrivalsToday = m['lateArrivalsToday'] ?? 0;
            _hrmsEarlyDeparturesToday = m['earlyDeparturesToday'] ?? 0;
            _hrmsOvertimeHoursToday = (m['totalOvertimeHoursToday'] as num?)?.toDouble() ?? 0.0;
            _hrmsWorkHoursToday = (m['totalWorkHoursToday'] as num?)?.toDouble() ?? 0.0;
            _hrmsGeofenceViolationsToday = m['geofenceViolationsToday'] ?? 0;
            _loadingHrms = false;
          });
        } else {
          setState(() => _loadingHrms = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHrms = false);
    }
  }`;

if (!txt.includes('ApiEndpoints.hrmsDashboardOverview')) {
  txt = txt.replace(oldLoadHrms, newLoadHrms);
  if (!txt.includes('ApiEndpoints.hrmsDashboardOverview')) {
    txt = txt.replace(oldLoadHrms.replace(/\n/g, '\r\n'), newLoadHrms.replace(/\n/g, '\r\n'));
  }
}

// 4. In _buildHrmsDashboardView, add Office dropdown and update attendance card
const oldTopBarEnd = `                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                  tooltip: 'Refresh Workforce Attendance',
                  onPressed: () => _loadHrmsData(silent: false),
                ),
              ],
            ),
            const SizedBox(height: 14),`;

const newTopBarEnd = `                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                  tooltip: 'Refresh Workforce Attendance',
                  onPressed: () => _loadHrmsData(silent: false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Office / Branch Filter Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedHrmsOfficeId,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('🏢 All Offices & Branches'),
                          ),
                          ..._hrmsOffices.map((o) => DropdownMenuItem<String>(
                                value: o['id'].toString(),
                                child: Text('🏢 \${o['office_code']} • \${o['office_name']}'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedHrmsOfficeId = val);
                            _loadHrmsData(silent: false);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),`;

if (!txt.includes('// Office / Branch Filter Selector')) {
  txt = txt.replace(oldTopBarEnd, newTopBarEnd);
  if (!txt.includes('// Office / Branch Filter Selector')) {
    txt = txt.replace(oldTopBarEnd.replace(/\n/g, '\r\n'), newTopBarEnd.replace(/\n/g, '\r\n'));
  }
}

// 5. Add extra metrics row and Employee Portal button
const oldMetricsRow = `                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                            const SizedBox(width: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Absent', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text('$_hrmsAbsentToday Out', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),`;

const newMetricsRow = `                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                            const SizedBox(width: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Absent', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text('$_hrmsAbsentToday Out', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  // Secondary Telemetry Row: Late, Early, Overtime, Geofence
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                        child: Text('⏰ Late: \$_hrmsLateArrivalsToday', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                        child: Text('🚪 Early Out: \$_hrmsEarlyDeparturesToday', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                        child: Text('⭐ OT: \${_hrmsOvertimeHoursToday.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                        child: Text('⏱️ Work: \${_hrmsWorkHoursToday.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ),
                      if (_hrmsGeofenceViolationsToday > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(6)),
                          child: Text('📍 Out of Range: \$_hrmsGeofenceViolationsToday', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                        ),
                    ],
                  ),
                ],
              ),
            ),`;

if (!txt.includes('Secondary Telemetry Row')) {
  txt = txt.replace(oldMetricsRow, newMetricsRow);
  if (!txt.includes('Secondary Telemetry Row')) {
    txt = txt.replace(oldMetricsRow.replace(/\n/g, '\r\n'), newMetricsRow.replace(/\n/g, '\r\n'));
  }
}

// 6. Update Quick Actions to add Employee Portal Button
const oldQuickActions = `            // Quick HRMS Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 18),
                    label: const Text('Mark Staff Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
              ],
            ),`;

const newQuickActions = `            // Quick HRMS Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 18),
                    label: const Text('Attendance Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.person_pin_circle_rounded, size: 18),
                    label: const Text('Employee GPS App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmployeePortalScreen()),
                      ).then((_) => _loadHrmsData());
                    },
                  ),
                ),
              ],
            ),`;

if (!txt.includes('Employee GPS App')) {
  txt = txt.replace(oldQuickActions, newQuickActions);
  if (!txt.includes('Employee GPS App')) {
    txt = txt.replace(oldQuickActions.replace(/\n/g, '\r\n'), newQuickActions.replace(/\n/g, '\r\n'));
  }
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Successfully patched mobile_billing_app_screen.dart!');
