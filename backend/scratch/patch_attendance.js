const fs = require('fs');
const file = 'lib/screens/hrms/attendance_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

// 1. Add _offices and _selectedOffice
if (!txt.includes('List<Map<String, dynamic>> _offices = [];')) {
  txt = txt.replace(
`  List<Map<String, dynamic>> _leaveTypesList = [];`,
`  List<Map<String, dynamic>> _leaveTypesList = [];
  List<Map<String, dynamic>> _offices = [];
  String _selectedOffice = 'All';`
  );
}

// 2. Load ApiEndpoints.hrmsOffices in _loadData
if (!txt.includes('ApiClient.get(ApiEndpoints.hrmsOffices)')) {
  txt = txt.replace(
`        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
      ]);
      setState(() {`,
`        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsOffices),
      ]);
      setState(() {`
  );

  txt = txt.replace(
`        _leaveTypesList    = List<Map<String, dynamic>>.from(results[6]['data'] ?? []);
      });`,
`        _leaveTypesList    = List<Map<String, dynamic>>.from(results[6]['data'] ?? []);
        _offices           = List<Map<String, dynamic>>.from(results[7]['data'] ?? []);
      });`
  );
}

// 3. Update filteredPunches to support office filter
if (!txt.includes('if (_selectedOffice != \'All\')')) {
  txt = txt.replace(
`    final filteredPunches = (_selectedEmployee == 'All'
        ? _attendancePunches
        : _attendancePunches.where((p) => p['employee_id'].toString() == _selectedEmployee).toList())
      ..sort((a, b) {
        final da = a['punch_date']?.toString() ?? '';
        final db = b['punch_date']?.toString() ?? '';
        return da.compareTo(db);
      });`,
`    final filteredPunches = _attendancePunches.where((p) {
      if (_selectedEmployee != 'All' && p['employee_id'].toString() != _selectedEmployee) {
        return false;
      }
      if (_selectedOffice != 'All') {
        final emp = _employeesList.firstWhere(
          (e) => e['id'].toString() == p['employee_id'].toString(),
          orElse: () => {},
        );
        final offId = p['office_id']?.toString() ?? emp['office_id']?.toString();
        if (offId != _selectedOffice) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = a['punch_date']?.toString() ?? '';
        final db = b['punch_date']?.toString() ?? '';
        return db.compareTo(da);
      });`
  );
}

// 4. Update dropdown filter in _buildAttendanceLogTab
const oldFilter = `        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployee,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: 'All', child: Text('All Employees')),
                      ..._employeesList.map((e) => DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text('\${e['full_name']} (\${e['employee_code']})'),
                          )),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedEmployee = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildMonthPicker(),
            ],
          ),
        ),`;

const newFilter = `        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOffice,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: 'All', child: Text('🏢 All Offices')),
                      ..._offices.map((o) => DropdownMenuItem<String>(
                            value: o['id'].toString(),
                            child: Text('\${o['office_code']} • \${o['office_name']}'),
                          )),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedOffice = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployee,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: 'All', child: Text('👤 All Employees')),
                      ..._employeesList.map((e) => DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text('\${e['full_name']} (\${e['employee_code']})'),
                          )),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedEmployee = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildMonthPicker(),
            ],
          ),
        ),`;

if (!txt.includes('🏢 All Offices')) {
  txt = txt.replace(oldFilter, newFilter);
  if (!txt.includes('🏢 All Offices')) {
    txt = txt.replace(oldFilter.replace(/\n/g, '\r\n'), newFilter.replace(/\n/g, '\r\n'));
  }
}

// 5. Add DataTable columns: Office, In Dist, Out Dist, Geofence
const oldCols = `                              columns: const [
                                DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('In Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Out Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Req. Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Work Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Overtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Less Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ],`;

const newCols = `                              columns: const [
                                DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Office', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('In Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('In Dist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Out Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Out Dist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Geofence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Work Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Overtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ],`;

if (!txt.includes("DataColumn(label: Text('In Dist'")) {
  txt = txt.replace(oldCols, newCols);
  if (!txt.includes("DataColumn(label: Text('In Dist'")) {
    txt = txt.replace(oldCols.replace(/\n/g, '\r\n'), newCols.replace(/\n/g, '\r\n'));
  }
}

// 6. In DataRow, add the cells and tap inspection
const oldRow = `                                  onSelectChanged: (selected) {
                                    if (selected == true) {
                                      _showPunchDialog(empId, dateStr, punch);
                                    }
                                  },
                                  cells: [
                                    DataCell(Text(punch['punch_date']?.toString() ?? '')),
                                    DataCell(Text(empName)),
                                    DataCell(_buildStatusChip(punch['status']?.toString() ?? 'Present')),
                                    DataCell(Text(punch['punch_in'] != null ? _fmtTimeOnly(punch['punch_in']) : '—')),
                                    DataCell(Text(punch['punch_out'] != null ? _fmtTimeOnly(punch['punch_out']) : '—')),`;

const newRow = `                                  onSelectChanged: (selected) {
                                    if (selected == true) {
                                      _showGeotagInspectionDialog(punch);
                                    }
                                  },
                                  cells: [
                                    DataCell(Text(punch['punch_date']?.toString() ?? '')),
                                    DataCell(Text(empName)),
                                    DataCell(Builder(builder: (ctx) {
                                      final emp = _employeesList.firstWhere((e) => e['id'].toString() == empId.toString(), orElse: () => {});
                                      final offName = punch['office']?['office_name'] ?? emp['office_name'] ?? 'HO';
                                      return Text(offName.toString(), style: const TextStyle(fontSize: 11));
                                    })),
                                    DataCell(_buildStatusChip(punch['status']?.toString() ?? 'Present')),
                                    DataCell(Text(punch['punch_in'] != null ? _fmtTimeOnly(punch['punch_in']) : '—')),
                                    DataCell(Builder(builder: (ctx) {
                                      final d = punch['checkin_distance_meters'] ?? punch['distance_meters'];
                                      if (d == null) return const Text('—', style: TextStyle(color: Colors.grey));
                                      final dist = double.tryParse(d.toString()) ?? 0.0;
                                      return Text('\${dist.toStringAsFixed(0)}m', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: dist <= 100 ? const Color(0xFF15803D) : const Color(0xFFDC2626)));
                                    })),
                                    DataCell(Text(punch['punch_out'] != null ? _fmtTimeOnly(punch['punch_out']) : '—')),
                                    DataCell(Builder(builder: (ctx) {
                                      final d = punch['checkout_distance_meters'];
                                      if (d == null) return const Text('—', style: TextStyle(color: Colors.grey));
                                      final dist = double.tryParse(d.toString()) ?? 0.0;
                                      return Text('\${dist.toStringAsFixed(0)}m', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: dist <= 100 ? const Color(0xFF15803D) : const Color(0xFFDC2626)));
                                    })),
                                    DataCell(Builder(builder: (ctx) {
                                      final isComp = punch['is_geofence_compliant'] != false;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isComp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isComp ? 'Within Zone' : 'Out of Range',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isComp ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                                        ),
                                      );
                                    })),`;

if (!txt.includes('_showGeotagInspectionDialog(punch)')) {
  txt = txt.replace(oldRow, newRow);
  if (!txt.includes('_showGeotagInspectionDialog(punch)')) {
    txt = txt.replace(oldRow.replace(/\n/g, '\r\n'), newRow.replace(/\n/g, '\r\n'));
  }
}

// Replace Source DataCell at end of row with Action icon
const oldSource = `                                    DataCell(Builder(builder: (context) {
                                      return Text(punch['source']?.toString() ?? 'SYSTEM');
                                    })),`;

const newSource = `                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.location_searching_rounded, size: 18, color: Color(0xFF2563EB)),
                                        tooltip: 'Inspect Geotag & Distance',
                                        onPressed: () => _showGeotagInspectionDialog(punch),
                                      ),
                                    ),`;

if (!txt.includes('Inspect Geotag & Distance')) {
  txt = txt.replace(oldSource, newSource);
  if (!txt.includes('Inspect Geotag & Distance')) {
    txt = txt.replace(oldSource.replace(/\n/g, '\r\n'), newSource.replace(/\n/g, '\r\n'));
  }
}

// 7. Append _showGeotagInspectionDialog and _buildInspectionCard methods
const dialogMethods = `
  void _showGeotagInspectionDialog(Map<String, dynamic> punch) {
    final empId = punch['employee_id'];
    final empName = _lookupEmployeeName(empId);
    final emp = _employeesList.firstWhere(
      (e) => e['id'].toString() == empId.toString(),
      orElse: () => {},
    );
    final office = punch['office'] ?? emp['office'] ?? {};
    final officeName = office['office_name'] ?? emp['office_name'] ?? 'Head Office';
    final officeLat = office['latitude']?.toString() ?? '30.316495';
    final officeLng = office['longitude']?.toString() ?? '78.032192';
    final geofenceRadius = office['geofence_radius_meters']?.toString() ?? '100';

    final inLat = punch['checkin_latitude']?.toString() ?? punch['latitude']?.toString() ?? '—';
    final inLng = punch['checkin_longitude']?.toString() ?? punch['longitude']?.toString() ?? '—';
    final inDist = punch['checkin_distance_meters'] != null
        ? '\${double.tryParse(punch['checkin_distance_meters'].toString())?.toStringAsFixed(1)}m'
        : (punch['distance_meters'] != null ? '\${double.tryParse(punch['distance_meters'].toString())?.toStringAsFixed(1)}m' : '—');

    final outLat = punch['checkout_latitude']?.toString() ?? '—';
    final outLng = punch['checkout_longitude']?.toString() ?? '—';
    final outDist = punch['checkout_distance_meters'] != null
        ? '\${double.tryParse(punch['checkout_distance_meters'].toString())?.toStringAsFixed(1)}m'
        : '—';

    final isCompliant = punch['is_geofence_compliant'] != false;
    final inTime = punch['punch_in'] != null ? _fmtTimeOnly(punch['punch_in']) : '—';
    final outTime = punch['punch_out'] != null ? _fmtTimeOnly(punch['punch_out']) : '—';
    final lateMins = punch['late_minutes'] ?? punch['late_arrival_mins'] ?? 0;
    final earlyMins = punch['early_departure_mins'] ?? 0;
    final otHours = punch['overtime_hours'] ?? '0.00';
    final hoursWorked = punch['hours_worked'] ?? '0.00';
    final dateStr = punch['punch_date']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompliant ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompliant ? Icons.location_on_rounded : Icons.location_off_rounded,
                color: isCompliant ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Geotag Attendance Inspector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('\$empName • \$dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompliant ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCompliant ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompliant ? Icons.check_circle_rounded : Icons.warning_rounded,
                        color: isCompliant ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCompliant
                              ? 'Geofence Compliant: Punch marked within allowed \${geofenceRadius}m office radius.'
                              : 'Geofence Warning: Marked outside designated \${geofenceRadius}m office boundary!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCompliant ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assigned Office / Branch:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('🏢 \$officeName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Base Coordinates: \$officeLat, \$officeLng (Geofence: \${geofenceRadius}m)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _buildInspectionCard(
                  title: 'Punch In (Check-In Geotag)',
                  time: inTime,
                  distance: inDist,
                  lat: inLat,
                  lng: inLng,
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                  extraMetric: lateMins > 0 ? '⚠️ Late Arrival: \$lateMins mins' : '✅ Arrived on time',
                  extraColor: lateMins > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),

                _buildInspectionCard(
                  title: 'Punch Out (Check-Out Geotag)',
                  time: outTime,
                  distance: outDist,
                  lat: outLat,
                  lng: outLng,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFFAF5FF),
                  extraMetric: earlyMins > 0 ? '⚠️ Early Departure: \$earlyMins mins' : (double.tryParse(otHours.toString()) ?? 0) > 0 ? '⭐ Overtime: \$otHours hrs' : 'Standard Shift Completed',
                  extraColor: earlyMins > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Hours Worked: \$hoursWorked hrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Status: \${punch['status'] ?? "Present"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488))),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard({
    required String title,
    required String time,
    required String distance,
    required String lat,
    required String lng,
    required Color color,
    required Color bgColor,
    required String extraMetric,
    required Color extraColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              Text('Time: \$time', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF4B5563)),
              const SizedBox(width: 4),
              const Text('Distance from Office: ', style: TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
              Text(distance, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.explore_outlined, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text('GPS Coordinates: \$lat, \$lng', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: extraColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(extraMetric, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: extraColor)),
          ),
        ],
      ),
    );
  }
`;

if (!txt.includes('void _showGeotagInspectionDialog')) {
  // Insert before the last closing brace of _AttendanceScreenState
  const lastBrace = txt.lastIndexOf('}');
  txt = txt.substring(0, lastBrace) + dialogMethods + '\n}\n';
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Successfully patched attendance_screen.dart!');
