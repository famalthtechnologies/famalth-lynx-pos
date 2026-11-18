import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import 'attendance_screen.dart';
import 'employee_screen.dart';
import 'hrms_masters_screen.dart';
import 'payroll_screen.dart';

class HrmsDashboardScreen extends StatefulWidget {
  const HrmsDashboardScreen({super.key});

  @override
  State<HrmsDashboardScreen> createState() => _HrmsDashboardScreenState();
}

class _HrmsDashboardScreenState extends State<HrmsDashboardScreen> {
  bool _isLoading = true;
  String _selectedOfficeId = 'all';
  List<Map<String, dynamic>> _offices = [];

  // Metrics
  int _totalEmployees = 0;
  int _presentToday = 0;
  int _absentToday = 0;
  int _onLeaveToday = 0;
  int _lateArrivalsToday = 0;
  int _earlyDeparturesToday = 0;
  double _totalOvertimeHours = 0.0;
  double _totalWorkHours = 0.0;
  int _geofenceViolationsToday = 0;

  // Feeds
  List<Map<String, dynamic>> _todayPunches = [];
  List<Map<String, dynamic>> _pendingLeaves = [];

  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color borderSubtle = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String _formatPunchTime(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty) return '—';
    try {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateFormat('hh:mm a').format(dt.toLocal());
      }
    } catch (_) {}
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final period = h >= 12 ? 'PM' : 'AM';
        final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
      }
    }
    return s;
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsOffices, silent: true),
        ApiClient.get('${ApiEndpoints.hrmsDashboardOverview}?office_id=$_selectedOfficeId', silent: true),
        ApiClient.get(ApiEndpoints.hrmsLeaves, silent: true),
        ApiClient.get('${ApiEndpoints.hrmsAttendance}?punch_date=$todayStr', silent: true),
        ApiClient.get(ApiEndpoints.hrmsEmployees, silent: true),
      ]);

      final officesRes = results[0];
      final overviewRes = results[1];
      final leavesRes = results[2];
      final attRes = results[3];
      final empRes = results[4];

      if (mounted) {
        if (officesRes != null && officesRes['data'] is List) {
          _offices = List<Map<String, dynamic>>.from(officesRes['data']);
        }

        if (overviewRes != null && overviewRes['success'] == true && overviewRes['metrics'] != null) {
          final m = overviewRes['metrics'];
          _totalEmployees = m['totalEmployees'] ?? m['total_employees'] ?? 0;
          _presentToday = m['presentToday'] ?? m['present_today'] ?? 0;
          _absentToday = m['absentToday'] ?? m['absent_today'] ?? 0;
          _onLeaveToday = m['onLeaveToday'] ?? m['on_leave_today'] ?? 0;
          _lateArrivalsToday = m['lateArrivalsToday'] ?? m['late_arrivals'] ?? 0;
          _earlyDeparturesToday = m['earlyDeparturesToday'] ?? m['early_departures'] ?? 0;
          _totalOvertimeHours = ((m['totalOvertimeHoursToday'] ?? m['overtime_hours']) as num?)?.toDouble() ?? 0.0;
          _totalWorkHours = ((m['totalWorkHoursToday'] ?? m['total_hours_worked']) as num?)?.toDouble() ?? 0.0;
          _geofenceViolationsToday = m['geofenceViolationsToday'] ?? m['geofence_violations'] ?? 0;
        }

        if (empRes != null && empRes['data'] is List) {
          final allEmps = List<Map<String, dynamic>>.from(empRes['data']);
          final filtered = _selectedOfficeId == 'all'
              ? allEmps
              : allEmps.where((e) => e['office_id']?.toString() == _selectedOfficeId).toList();
          if (_totalEmployees == 0 && filtered.isNotEmpty) {
            _totalEmployees = filtered.length;
            _absentToday = (_totalEmployees - _presentToday - _onLeaveToday).clamp(0, 99999);
          }
        }

        if (leavesRes != null && leavesRes['data'] is List) {
          final allLeaves = List<Map<String, dynamic>>.from(leavesRes['data']);
          _pendingLeaves = allLeaves.where((l) => (l['status'] ?? '').toString().toUpperCase() == 'PENDING').toList();
        }

        if (overviewRes != null && overviewRes['recent_punches'] is List && (overviewRes['recent_punches'] as List).isNotEmpty) {
          _todayPunches = List<Map<String, dynamic>>.from(overviewRes['recent_punches']);
        } else if (attRes != null && attRes['data'] is List) {
          _todayPunches = List<Map<String, dynamic>>.from(attRes['data']);
        }

        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
    final double attendanceRate = _totalEmployees > 0 ? (_presentToday / _totalEmployees) * 100 : 0.0;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_rounded, color: accentIndigo, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HRMS & Workforce Dashboard',
                  style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  todayFormatted,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: primaryNavy),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryNavy),
            tooltip: 'Refresh Dashboard',
            onPressed: _loadDashboardData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentIndigo))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Office / Branch Selector & Quick Header
                    _buildOfficeFilterBar(attendanceRate),
                    const SizedBox(height: 20),

                    // 2. High-Impact KPI Grid (8 Cards)
                    _buildKpiGrid(),
                    const SizedBox(height: 20),

                    // 3. Quick Action Hub Bar
                    _buildActionHubBar(),
                    const SizedBox(height: 24),

                    // 4. Two-Column Live Panels (Today's Punches & Pending Leave Requests)
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildTodayPunchesCard()),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: _buildPendingLeavesCard()),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildTodayPunchesCard(),
                              const SizedBox(height: 20),
                              _buildPendingLeavesCard(),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // -------------------------------------------------------------
  // Office Filter & Header Bar
  // -------------------------------------------------------------
  Widget _buildOfficeFilterBar(double attendanceRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_city_rounded, color: accentIndigo, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Company Office / Branch Filter:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOfficeId,
                    isExpanded: true,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('🏢 All Offices & Branches (Consolidated View)'),
                      ),
                      ..._offices.map((o) => DropdownMenuItem<String>(
                            value: o['id'].toString(),
                            child: Text('🏢 ${o['office_code']} • ${o['office_name']}'),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedOfficeId = val);
                        _loadDashboardData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: attendanceRate >= 75
                  ? const Color(0xFFDCFCE7)
                  : (attendanceRate >= 50 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${attendanceRate.toStringAsFixed(1)}% Turnout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: attendanceRate >= 75
                        ? const Color(0xFF15803D)
                        : (attendanceRate >= 50 ? const Color(0xFFB45309) : dangerRed),
                  ),
                ),
                Text(
                  '$_presentToday of $_totalEmployees on Duty',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // High-Impact KPI Grid (8 Cards)
  // -------------------------------------------------------------
  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final count = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
        final width = (constraints.maxWidth - ((count - 1) * 14)) / count;

        final cards = [
          _kpiCard(
            title: 'Present Today',
            value: '$_presentToday Staff',
            subtitle: '$_absentToday absent • $_onLeaveToday on leave',
            icon: Icons.check_circle_rounded,
            color: successGreen,
            bgColor: const Color(0xFFDCFCE7),
          ),
          _kpiCard(
            title: 'Total Workforce',
            value: '$_totalEmployees Employees',
            subtitle: '${_offices.length} configured offices',
            icon: Icons.people_alt_rounded,
            color: accentIndigo,
            bgColor: const Color(0xFFEEF2FF),
          ),
          _kpiCard(
            title: 'Late Arrivals',
            value: '$_lateArrivalsToday Staff Late',
            subtitle: 'Exceeded shift grace period',
            icon: Icons.timer_outlined,
            color: warningAmber,
            bgColor: const Color(0xFFFEF3C7),
          ),
          _kpiCard(
            title: 'Early Departures',
            value: '$_earlyDeparturesToday Early Exits',
            subtitle: 'Left before scheduled shift end',
            icon: Icons.logout_rounded,
            color: dangerRed,
            bgColor: const Color(0xFFFEE2E2),
          ),
          _kpiCard(
            title: 'Total Hours Worked',
            value: '${_totalWorkHours.toStringAsFixed(1)} Hours',
            subtitle: 'Aggregate workforce duration',
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
          ),
          _kpiCard(
            title: 'Overtime Tracked',
            value: '${_totalOvertimeHours.toStringAsFixed(1)} OT Hours',
            subtitle: 'Approved extra shift hours',
            icon: Icons.more_time_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),
          _kpiCard(
            title: 'Geofence Compliance',
            value: _geofenceViolationsToday == 0
                ? '100% Compliant'
                : '$_geofenceViolationsToday Out of Range',
            subtitle: 'Within office GPS perimeter',
            icon: Icons.radar_rounded,
            color: _geofenceViolationsToday == 0 ? successGreen : dangerRed,
            bgColor: _geofenceViolationsToday == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
          ),
          _kpiCard(
            title: 'Pending Leaves',
            value: '${_pendingLeaves.length} Applications',
            subtitle: 'Awaiting manager approval',
            icon: Icons.event_note_rounded,
            color: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
          ),
        ];

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((c) => SizedBox(width: width, child: c)).toList(),
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryNavy)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Action Hub Navigation Bar
  // -------------------------------------------------------------
  Widget _buildActionHubBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: accentIndigo, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'HR Operations Hub:',
                style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _hubButton(
                label: 'Employee Management',
                icon: Icons.people_outline,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen()))
                    .then((_) => _loadDashboardData()),
              ),
              _hubButton(
                label: 'Attendance & Leaves',
                icon: Icons.access_time_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))
                    .then((_) => _loadDashboardData()),
              ),
              _hubButton(
                label: 'Payroll Processing',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen()))
                    .then((_) => _loadDashboardData()),
              ),
              _hubButton(
                label: 'Office & Geofences',
                icon: Icons.location_city_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmsMastersScreen()))
                    .then((_) => _loadDashboardData()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hubButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlight ? accentIndigo : const Color(0xFFF8FAFC),
        foregroundColor: isHighlight ? Colors.white : const Color(0xFF334155),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isHighlight ? accentIndigo : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      icon: Icon(icon, size: 15, color: isHighlight ? Colors.white : const Color(0xFF64748B)),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }

  // -------------------------------------------------------------
  // Panel 1: Today's Geotagged Attendance Live Feed
  // -------------------------------------------------------------
  Widget _buildTodayPunchesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: accentIndigo, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Today's Attendance & Geotag Feed",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  child: const Text('View Full Log →', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderSubtle),
          if (_todayPunches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No attendance punches recorded yet for today.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayPunches.take(6).length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final p = _todayPunches[idx];
                final emp = p['employee'] ?? {};
                final empName = emp['full_name'] ?? 'Employee #${p['employee_id']}';
                final inTime = _formatPunchTime(p['punch_in']);
                final offName = p['office']?['office_name'] ?? emp['office_name'] ?? 'office';
                final rawDist = p['checkin_distance_meters'] ?? p['distance_meters'];
                final inDist = rawDist != null
                    ? '${(rawDist as num).toStringAsFixed(0)}m'
                    : '—';
                final isComp = p['is_geofence_compliant'] != false;
                final lateMins = p['late_arrival_mins'] ?? p['late_minutes'] ?? p['lateness_mins'] ?? 0;
                final status = p['status']?.toString() ?? 'Present';

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: accentIndigo, fontSize: 13),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        empName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryNavy),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: status.toLowerCase() == 'present'
                              ? const Color(0xFFDCFCE7)
                              : (status.toLowerCase().contains('leave') ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: status.toLowerCase() == 'present'
                                ? successGreen
                                : (status.toLowerCase().contains('leave') ? warningAmber : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Checked in: $inTime • $inDist from $offName',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((lateMins as num) > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                          child: Text('$lateMins m late', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: warningAmber)),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isComp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isComp ? 'Within Radius' : 'Out of Bounds',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isComp ? successGreen : dangerRed),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Panel 2: Pending Leave Approvals
  // -------------------------------------------------------------
  Widget _buildPendingLeavesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_available_rounded, color: Color(0xFFEA580C), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Pending Leave Requests',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                    ),
                  ],
                ),
                Text(
                  '${_pendingLeaves.length} Pending',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFEA580C)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderSubtle),
          if (_pendingLeaves.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No leave applications awaiting approval.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingLeaves.take(4).length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final l = _pendingLeaves[idx];
                final emp = l['employee'] ?? {};
                final empName = emp['full_name'] ?? 'Employee #${l['employee_id']}';
                final leaveType = l['leave_type']?['name'] ?? l['leave_type_name'] ?? 'Leave';
                final days = l['days_count'] ?? l['days'] ?? 1;

                return ListTile(
                  dense: true,
                  title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    '$leaveType • $days days (${l['start_date']} to ${l['end_date']})',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded, color: successGreen, size: 20),
                        tooltip: 'Approve',
                        onPressed: () async {
                          await ApiClient.put('${ApiEndpoints.hrmsLeaves}/${l['id']}/status', {'status': 'Approved'});
                          _loadDashboardData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: dangerRed, size: 20),
                        tooltip: 'Reject',
                        onPressed: () async {
                          await ApiClient.put('${ApiEndpoints.hrmsLeaves}/${l['id']}/status', {'status': 'Rejected'});
                          _loadDashboardData();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
