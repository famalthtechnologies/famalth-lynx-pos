const fs = require('fs');
const file = 'lib/screens/hrms/employee_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

// 1. In _EmployeeScreenState, add _offices
if (!txt.includes('List<Map<String, dynamic>> _offices = [];')) {
  txt = txt.replace('List<Map<String, dynamic>> _payStructures = [];', 'List<Map<String, dynamic>> _payStructures = [];\n  List<Map<String, dynamic>> _offices = [];');
}

// 2. In _loadAll, fetch ApiEndpoints.hrmsOffices
if (!txt.includes('ApiClient.get(ApiEndpoints.hrmsOffices)')) {
  txt = txt.replace(
`        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
      ]);
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _designations = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _shifts = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _payStructures = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
      });`,
`        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
        ApiClient.get(ApiEndpoints.hrmsOffices),
      ]);
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _designations = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _shifts = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _payStructures = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
        _offices = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);
      });`
  );
}

// 3. In _buildEmployeeCard, show office badge
if (!txt.includes("final officeName = emp['office']")) {
  txt = txt.replace(
`    final status = emp['status'] ?? 'Active';`,
`    final status = emp['status'] ?? 'Active';
    final officeName = emp['office'] != null
        ? (emp['office'] is Map ? (emp['office']['office_name'] ?? emp['office']['office_code'] ?? '') : emp['office'].toString())
        : (emp['office_name'] ?? '');`
  );

  txt = txt.replace(
`                        if (shiftStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(shiftStr,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],`,
`                        if (shiftStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(shiftStr,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (officeName.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('📍 \${officeName}',
                                style: const TextStyle(
                                    color: Color(0xFF15803D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],`
  );
}

// 4. In _AddEmployeeFormState, add _offices, _officeId, _passwordCtrl, _obscurePassword
if (!txt.includes('int? _officeId;')) {
  txt = txt.replace(
`  List<Map<String, dynamic>> _users = [];

  // Sentinel int for the "+ Add New" item in dropdowns`,
`  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _offices = [];
  int? _officeId;
  final _passwordCtrl = TextEditingController(text: '123456');
  bool _obscurePassword = true;

  // Sentinel int for the "+ Add New" item in dropdowns`
  );
}

// 5. In _AddEmployeeFormState.initState / widget.employee != null: load office_id
if (!txt.includes("_officeId = emp['office_id'] as int?;")) {
  txt = txt.replace(
`      _shiftId = emp['shift_id'] as int?;`,
`      _shiftId = emp['shift_id'] as int?;
      _officeId = emp['office_id'] as int?;`
  );
}

// 6. In _loadMasters of _AddEmployeeFormState: load offices
if (!txt.includes('_offices = List<Map<String, dynamic>>.from(results[6][\'data\']')) {
  txt = txt.replace(
`        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
      ]);`,
`        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
        ApiClient.get(ApiEndpoints.hrmsOffices),
      ]);`
  );

  txt = txt.replace(
`        _leaveTypes   = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);`,
`        _leaveTypes   = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);
        _offices      = List<Map<String, dynamic>>.from(results[6]['data'] ?? []);
        if (_officeId == null && _offices.isNotEmpty) {
          _officeId = _offices.first['id'] as int?;
        }`
  );
}

// 7. In _validateStep: validate officeId
if (!txt.includes('_officeId == null')) {
  txt = txt.replace(
`      if (_designationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Designation is required! Please select a designation.'))
        );
        return false;
      }`,
`      if (_officeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Office / Branch is required! Please select an assigned office.'))
        );
        return false;
      }
      if (_designationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Designation is required! Please select a designation.'))
        );
        return false;
      }`
  );
}

// 8. In _save: add office_id and initial_password
if (!txt.includes("'office_id'          : _officeId,")) {
  txt = txt.replace(
`        'hire_date'          : _hireDate!.toIso8601String().split('T')[0],
        'designation_id'     : _designationId,`,
`        'hire_date'          : _hireDate!.toIso8601String().split('T')[0],
        'office_id'          : _officeId,
        'initial_password'   : _passwordCtrl.text.trim(),
        'designation_id'     : _designationId,`
  );
}

// 9. In Step 1 UI (Work Details), add Office dropdown and initial password field
if (!txt.includes("label: 'Office / Branch *',")) {
  txt = txt.replace(
`        _sectionLabel('Work Details'),
        _dateTile(
          label: 'Hire Date *',`,
`        _sectionLabel('Work Details'),
        _dropdownField<int>(
          label: 'Office / Branch *',
          icon: Icons.location_city_rounded,
          value: _officeId,
          items: _offices.map((o) => DropdownMenuItem<int>(
            value: o['id'] as int?,
            child: Text('\${o['office_code']} • \${o['office_name']}'),
          )).toList(),
          onChanged: (v) => setState(() => _officeId = v),
        ),
        const SizedBox(height: 12),
        if (widget.employee == null) ...[
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Initial Login Password *',
              helperText: 'Temporary password sent to employee via welcome email',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _dateTile(
          label: 'Hire Date *',`
  );
}

fs.writeFileSync(file, txt, 'utf8');
console.log('Successfully patched employee_screen.dart!');
