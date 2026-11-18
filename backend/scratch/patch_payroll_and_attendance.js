const fs = require('fs');
const path = require('path');

// 1. Patch payroll_screen.dart
const payrollFile = path.resolve('lib/screens/hrms/payroll_screen.dart');
let pCode = fs.readFileSync(payrollFile, 'utf8');

// Add office state
if (!pCode.includes('_selectedOfficeId')) {
  pCode = pCode.replace(
    'int? _activeRunId;',
    `int? _activeRunId;\n  String _selectedOfficeId = 'all';\n  List<Map<String, dynamic>> _offices = [];`
  );
}

// In _loadTabContent, load offices and pass office_id
pCode = pCode.replace(
  'Future<void> _loadTabContent() async {\n    setState(() => _loadingTab = true);\n    try {',
  `Future<void> _loadTabContent() async {
    setState(() => _loadingTab = true);
    try {
      if (_offices.isEmpty) {
        try {
          final offRes = await ApiClient.get(ApiEndpoints.hrmsOffices);
          if (offRes['success'] == true && offRes['data'] is List) {
            _offices = List<Map<String, dynamic>>.from(offRes['data']);
          }
        } catch (_) {}
      }`
);

// In _fetchPreviewData, pass office_id
pCode = pCode.replace(
  "final res = await ApiClient.post('/api/hrms/payroll/preview', {'pay_period': period});",
  `final payload = {
        'pay_period': period,
        if (_selectedOfficeId != 'all') 'office_id': int.tryParse(_selectedOfficeId),
      };
      final res = await ApiClient.post('/api/hrms/payroll/preview', payload);`
);

// In run payroll, pass office_id
pCode = pCode.replace(
  "await ApiClient.post('/api/hrms/payroll/run', {\n                        'pay_period': DateFormat('yyyy-MM').format(_currentMonth)\n                      });",
  `await ApiClient.post('/api/hrms/payroll/run', {
                        'pay_period': DateFormat('yyyy-MM').format(_currentMonth),
                        if (_selectedOfficeId != 'all') 'office_id': int.tryParse(_selectedOfficeId),
                      });`
);

// In _buildPayRunHeader, add Office Dropdown filter
if (!pCode.includes("child: Text('🏢 All Offices & Branches')")) {
  pCode = pCode.replace(
    "_buildStatusChip(_runStatus),\n            ],",
    `_buildStatusChip(_runStatus),
              const SizedBox(width: 10),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_city, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedOfficeId,
                        isDense: true,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('🏢 All Offices & Branches')),
                          ..._offices.map((o) => DropdownMenuItem(
                                value: o['id'].toString(),
                                child: Text('\${o['office_code']} - \${o['office_name']}'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedOfficeId = val;
                              _previewData.clear();
                              _showPreview = false;
                            });
                            _fetchPreviewData();
                            _loadTabContent();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],`
  );
}

fs.writeFileSync(payrollFile, pCode, 'utf8');
console.log('Patched payroll_screen.dart successfully!');

// 2. Patch attendance_screen.dart
const attFile = path.resolve('lib/screens/hrms/attendance_screen.dart');
let aCode = fs.readFileSync(attFile, 'utf8');

// Robust _loadData
aCode = aCode.replace(
  /Future<void> _loadData\(\) async \{[\s\S]*?finally \{ setState\(\(\) => _isLoading = false\); \}\s*\}/,
  `Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final monthStr = '\${_currentMonth.year}-\${_currentMonth.month.toString().padLeft(2, '0')}';
    try {
      final safeGet = (String ep) async {
        try {
          return await ApiClient.get(ep);
        } catch (_) {
          return {'success': false, 'data': []};
        }
      };

      final results = await Future.wait([
        safeGet(ApiEndpoints.hrmsEmployees),
        safeGet('\${ApiEndpoints.hrmsAttendance}?month=\$monthStr'),
        safeGet(ApiEndpoints.hrmsLeaves),
        safeGet(ApiEndpoints.hrmsLoans),
        safeGet(ApiEndpoints.hrmsShifts),
        safeGet('/api/hrms/holidays'),
        safeGet(ApiEndpoints.hrmsLeaveTypes),
        safeGet(ApiEndpoints.hrmsOffices),
      ]);

      setState(() {
        _employeesList     = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _attendancePunches = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _leaveRequests     = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _loanRequests      = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
        _shiftsList        = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);
        _holidaysList      = List<Map<String, dynamic>>.from(results[5]['data'] ?? []);
        _leaveTypesList    = List<Map<String, dynamic>>.from(results[6]['data'] ?? []);
        _offices           = List<Map<String, dynamic>>.from(results[7]['data'] ?? []);
      });
    } catch (_) {}
    finally { setState(() => _isLoading = false); }
  }`
);

// Connect _selectedOffice filter in filteredEmployees on Summary tab
aCode = aCode.replace(
  /final filteredEmployees = _employeesList\.where\(\(emp\) \{[\s\S]*?return name\.contains\(query\) \|\| code\.contains\(query\);\s*\}\)\.toList\(\);/,
  `final filteredEmployees = _employeesList.where((emp) {
      if (_selectedOffice != 'All' && emp['office_id']?.toString() != _selectedOffice) return false;
      final name = (emp['full_name'] ?? '').toString().toLowerCase();
      final code = (emp['employee_code'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();`
);

// Add office dropdown to Summary tab next to search bar
if (!aCode.includes("SummaryOfficeFilterBar")) {
  aCode = aCode.replace(
    /Padding\(\s*padding: const EdgeInsets\.symmetric\(horizontal: 16\),\s*child: TextField\(\s*controller: _searchCtrl,[\s\S]*?\),\s*\),/,
    `/* SummaryOfficeFilterBar */
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedOffice,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
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
              ),
            ],
          ),
        ),`
  );
}

// In _buildApprovalsTab, also filter pending requests by _selectedOffice
aCode = aCode.replace(
  /final pendingLeaves = _leaveRequests\.where\(\(r\) => r\['status'\] == 'Pending'\)\.toList\(\);/,
  `final pendingLeaves = _leaveRequests.where((r) {
      if (r['status'] != 'Pending') return false;
      if (_selectedOffice != 'All' && r['employee']?['office_id']?.toString() != _selectedOffice) return false;
      return true;
    }).toList();`
);
aCode = aCode.replace(
  /final pendingLoans = _loanRequests\.where\(\(l\) => l\['status'\] == 'Pending'\)\.toList\(\);/,
  `final pendingLoans = _loanRequests.where((l) {
      if (l['status'] != 'Pending') return false;
      if (_selectedOffice != 'All' && l['employee']?['office_id']?.toString() != _selectedOffice) return false;
      return true;
    }).toList();`
);

fs.writeFileSync(attFile, aCode, 'utf8');
console.log('Patched attendance_screen.dart successfully!');
