const fs = require('fs');
const path = require('path');

const file = path.resolve('lib/screens/hrms/hrms_masters_screen.dart');
let code = fs.readFileSync(file, 'utf8');

// 1. Add state variable _selectedOfficeFilter
if (!code.includes('_selectedOfficeFilter')) {
  code = code.replace(
    'List<Map<String, dynamic>> _offices       = [];',
    `List<Map<String, dynamic>> _offices       = [];
  String _selectedOfficeFilter = 'all';`
  );
}

// 2. In _loadAll, add ApiClient.get(ApiEndpoints.hrmsOffices)
code = code.replace(
  /final results = await Future\.wait\(\[\s*ApiClient\.get\(ApiEndpoints\.hrmsLeaveTypes\),\s*ApiClient\.get\(ApiEndpoints\.hrmsShifts\),\s*ApiClient\.get\(ApiEndpoints\.hrmsDesignations\),\s*ApiClient\.get\(ApiEndpoints\.hrmsSalaryComponents\),\s*ApiClient\.get\(ApiEndpoints\.hrmsPayStructures\),\s*\]\);/,
  `final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsDesignations),
        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
        ApiClient.get(ApiEndpoints.hrmsOffices),
      ]);`
);
code = code.replace(
  /_payStructures = _parseList\(results\[4\]\);\s*_loading = false;/,
  `_payStructures = _parseList(results[4]);
        _offices       = _parseList(results[5]);
        _loading = false;`
);

// 3. Add _buildOfficeFilterBar, _officeBadge, _buildOfficeSelector before _buildOffices
const helperWidgets = `
  // ─── OFFICE FILTER & SCOPE HELPERS ─────────────────────────
  Widget _buildOfficeFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_city_rounded, color: Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Master Scope / Office:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedOfficeFilter,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('🌐 All Offices & Branches (Show All)'),
                  ),
                  ..._offices.map((o) => DropdownMenuItem(
                    value: o['id'].toString(),
                    child: Text('🏢 \${o['office_code']} - \${o['office_name']}'),
                  )),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedOfficeFilter = v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _officeBadge(dynamic officeId) {
    if (officeId == null) {
      return _badge('All Offices', const Color(0xFFEFF6FF), const Color(0xFF2563EB));
    }
    final off = _offices.firstWhere((o) => o['id']?.toString() == officeId.toString(), orElse: () => {});
    final name = off.isNotEmpty ? (off['office_code'] ?? off['office_name'] ?? 'Branch') : 'Branch #\$officeId';
    return _badge(name.toString(), const Color(0xFFF0FDF4), const Color(0xFF16A34A));
  }

  Widget _buildOfficeSelector({
    required String? selectedOfficeId,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _label('OFFICE / BRANCH APPLICABILITY'),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedOfficeId,
              isExpanded: true,
              hint: const Text('All Offices (Company-wide)', style: TextStyle(fontSize: 12, color: _grey40)),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('🌐 All Offices & Branches (Company-wide)', style: TextStyle(fontSize: 12, color: _navy, fontWeight: FontWeight.w600)),
                ),
                ..._offices.map((o) => DropdownMenuItem<String?>(
                  value: o['id'].toString(),
                  child: Text('🏢 \${o['office_code']} - \${o['office_name']}', style: const TextStyle(fontSize: 12, color: _navy)),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
`;

if (!code.includes('_buildOfficeFilterBar()')) {
  code = code.replace('  // ═══ OFFICES & GEOFENCING', helperWidgets + '\n  // ═══ OFFICES & GEOFENCING');
}

// 4. In build(), add _buildOfficeFilterBar() to ListView
if (!code.includes('_buildOfficeFilterBar(),')) {
  code = code.replace(
    'children: [\n                      _buildOffices(),',
    'children: [\n                      _buildOfficeFilterBar(),\n                      _buildOffices(),'
  );
}

// 5. Update _buildDesignations to filter and _desigTile to show badge
code = code.replace(
  /_buildDesignations\(\) \{[\s\S]*?body: _designations\.isEmpty[\s\S]*?: Column\(children: _designations\.asMap\(\)\.entries/,
  `_buildDesignations() {
    final filtered = _selectedOfficeFilter == 'all'
        ? _designations
        : _designations.where((d) => d['office_id'] == null || d['office_id']?.toString() == _selectedOfficeFilter).toList();
    return _sectionCard(
      title: 'Designations',
      icon: Icons.badge_outlined,
      iconColor: _blue,
      iconBg: const Color(0xFFEFF6FF),
      onAdd: _addDesignation,
      body: filtered.isEmpty
          ? _emptyRow('No designations matching filter. Tap Add →')
          : Column(children: filtered.asMap().entries`
);

code = code.replace(
  /Expanded\(\s*child: Text\(name,\s*style: const TextStyle\(\s*fontWeight: FontWeight\.w600,\s*fontSize: 14, color: _navy\)\),\s*\),/,
  `Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14, color: _navy)),
              ),
              const SizedBox(width: 8),
              _officeBadge(d['office_id']),
            ],
          ),
        ),`
);

// 6. Update _buildShifts and _shiftTile
code = code.replace(
  /_buildShifts\(\) \{[\s\S]*?body: _shifts\.isEmpty[\s\S]*?: Column\(children: _shifts\.asMap\(\)\.entries/,
  `_buildShifts() {
    final filtered = _selectedOfficeFilter == 'all'
        ? _shifts
        : _shifts.where((s) => s['office_id'] == null || s['office_id']?.toString() == _selectedOfficeFilter).toList();
    return _sectionCard(
      title: 'Shifts',
      icon: Icons.schedule,
      iconColor: const Color(0xFF7C3AED),
      iconBg: const Color(0xFFF5F3FF),
      onAdd: _addShift,
      body: filtered.isEmpty
          ? _emptyRow('No shifts matching filter. Tap Add →')
          : Column(children: filtered.asMap().entries`
);

code = code.replace(
  /Text\(name,\s*style: const TextStyle\(\s*fontWeight: FontWeight\.w600,\s*fontSize: 14, color: _navy\)\),\s*const SizedBox\(height: 2\),\s*Text\('\$start – \$end/,
  `Row(
              children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14, color: _navy)),
                ),
                const SizedBox(width: 8),
                _officeBadge(s['office_id']),
              ],
            ),
            const SizedBox(height: 2),
            Text('$start – $end`
);

// 7. Update _buildLeaveTypes and _leaveTile
code = code.replace(
  /_buildLeaveTypes\(\) \{[\s\S]*?body: _leaveTypes\.isEmpty[\s\S]*?: Column\(children: _leaveTypes\.asMap\(\)\.entries/,
  `_buildLeaveTypes() {
    final filtered = _selectedOfficeFilter == 'all'
        ? _leaveTypes
        : _leaveTypes.where((l) => l['office_id'] == null || l['office_id']?.toString() == _selectedOfficeFilter).toList();
    return _sectionCard(
      title: 'Leave Types',
      icon: Icons.event_available,
      iconColor: _amber,
      iconBg: const Color(0xFFFFFBEB),
      onAdd: _addLeaveType,
      body: filtered.isEmpty
          ? _emptyRow('No leave types matching filter. Tap Add →')
          : Column(children: filtered.asMap().entries`
);

code = code.replace(
  /Text\(name,\s*style: const TextStyle\(\s*fontWeight: FontWeight\.w600,\s*fontSize: 14, color: _navy\)\),\s*const SizedBox\(height: 2\),\s*Text\('\$quota days\/year/,
  `Row(
              children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14, color: _navy)),
                ),
                const SizedBox(width: 8),
                _officeBadge(l['office_id']),
              ],
            ),
            const SizedBox(height: 2),
            Text('$quota days/year`
);

// 8. Update _buildSalaryComponents and _compTile
code = code.replace(
  /Widget _buildSalaryComponents\(\) \{[\s\S]*?body: _salaryComps\.isEmpty[\s\S]*?: Column\(children: \[/,
  `Widget _buildSalaryComponents() {
    final filtered = _selectedOfficeFilter == 'all'
        ? _salaryComps
        : _salaryComps.where((c) => c['office_id'] == null || c['office_id']?.toString() == _selectedOfficeFilter).toList();
    final earnings   = filtered.where((c) => c['nature'] == 'Earning').toList();
    final deductions = filtered.where((c) => c['nature'] != 'Earning').toList();
    return _sectionCard(
      title: 'Salary Components',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: _red,
      iconBg: const Color(0xFFFEF2F2),
      onAdd: _addSalaryComponent,
      body: filtered.isEmpty
          ? _emptyRow('No salary components matching filter. Tap Add →')
          : Column(children: [`
);

code = code.replace(
  /Text\(name,\s*style: const TextStyle\(\s*fontWeight: FontWeight\.w600,\s*fontSize: 13, color: _navy\)\),\s*if \(type != 'Fixed'/,
  `Row(
              children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13, color: _navy)),
                ),
                const SizedBox(width: 8),
                _officeBadge(c['office_id']),
              ],
            ),
            if (type != 'Fixed'`
);

// 9. Update _buildPayStructures and _psTile
code = code.replace(
  /Widget _buildPayStructures\(\) \{[\s\S]*?body: _payStructures\.isEmpty[\s\S]*?: Column\(children: _payStructures\.asMap\(\)\.entries/,
  `Widget _buildPayStructures() {
    final filtered = _selectedOfficeFilter == 'all'
        ? _payStructures
        : _payStructures.where((p) => p['office_id'] == null || p['office_id']?.toString() == _selectedOfficeFilter).toList();
    return _sectionCard(
      title: 'Pay Structures',
      icon: Icons.receipt_long_outlined,
      iconColor: const Color(0xFF0891B2),
      iconBg: const Color(0xFFECFEFF),
      onAdd: _addPayStructure,
      body: filtered.isEmpty
          ? _emptyRow('No pay structures matching filter. Tap Add →')
          : Column(children: filtered.asMap().entries`
);

code = code.replace(
  /Text\(name,\s*style: const TextStyle\(\s*fontWeight: FontWeight\.w600,\s*fontSize: 14, color: _navy\)\),\s*if \(desc\.isNotEmpty\)/,
  `Row(
              children: [
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14, color: _navy)),
                ),
                const SizedBox(width: 8),
                _officeBadge(p['office_id']),
              ],
            ),
            if (desc.isNotEmpty)`
);

// 10. Update _addDesignation and _editDesignation
code = code.replace(
  /Future<void> _addDesignation\(\) async \{[\s\S]*?if \(ok == true\) _loadAll\(\);\s*\}/,
  `Future<void> _addDesignation() async {
    final ctrl = TextEditingController();
    String? selectedOfficeId = _selectedOfficeFilter == 'all' ? null : _selectedOfficeFilter;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Add Designation',
          icon: Icons.badge_outlined,
          iconColor: _blue,
          iconBg: const Color(0xFFEFF6FF),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    'Designation Title *', 'e.g. Sales Manager',
                    Icons.badge_outlined),
              ),
              _buildOfficeSelector(
                selectedOfficeId: selectedOfficeId,
                onChanged: (v) => setS(() => selectedOfficeId = v),
              ),
            ],
          ),
          onSave: () async {
            if (ctrl.text.trim().isEmpty) return false;
            await ApiClient.post(ApiEndpoints.hrmsDesignations, {
              'name': ctrl.text.trim(),
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }`
);

code = code.replace(
  /Future<void> _editDesignation\(Map<String, dynamic> d\) async \{[\s\S]*?if \(ok == true\) _loadAll\(\);\s*\}/,
  `Future<void> _editDesignation(Map<String, dynamic> d) async {
    final ctrl = TextEditingController(text: d['name']?.toString() ?? '');
    String? selectedOfficeId = d['office_id']?.toString();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Edit Designation',
          icon: Icons.badge_outlined,
          iconColor: _blue,
          iconBg: const Color(0xFFEFF6FF),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    'Designation Title *', 'e.g. Sales Manager',
                    Icons.badge_outlined),
              ),
              _buildOfficeSelector(
                selectedOfficeId: selectedOfficeId,
                onChanged: (v) => setS(() => selectedOfficeId = v),
              ),
            ],
          ),
          onSave: () async {
            if (ctrl.text.trim().isEmpty) return false;
            await ApiClient.put('\${ApiEndpoints.hrmsDesignations}/\${d['id']}', {
              'name': ctrl.text.trim(),
              'is_active': d['is_active'] != false,
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }`
);

// 11. Update _addShift and _editShift
code = code.replace(
  /Future<void> _addShift\(\) async \{[\s\S]*?final selectedOffs = <String>\['Sunday'\];/,
  `Future<void> _addShift() async {
    final nameCtrl  = TextEditingController();
    final graceCtrl = TextEditingController(text: '15');
    String? selectedOfficeId = _selectedOfficeFilter == 'all' ? null : _selectedOfficeFilter;
    final selectedOffs = <String>['Sunday'];`
);

code = code.replace(
  /TextField\(\s*controller: graceCtrl,[\s\S]*?Icons\.timer_outlined\),\s*\),/,
  `TextField(
                controller: graceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    'Grace Period (mins)', '15', Icons.timer_outlined),
              ),
              _buildOfficeSelector(
                selectedOfficeId: selectedOfficeId,
                onChanged: (v) => setS(() => selectedOfficeId = v),
              ),`
);

code = code.replace(
  /await ApiClient\.post\(ApiEndpoints\.hrmsShifts, \{\s*'name': nameCtrl\.text\.trim\(\),[\s\S]*?'weekly_offs': selectedOffs,\s*\}\);/,
  `await ApiClient.post(ApiEndpoints.hrmsShifts, {
                'name': nameCtrl.text.trim(),
                'start_time': '\${startTime!.hour.toString().padLeft(2, '0')}:\${startTime!.minute.toString().padLeft(2, '0')}',
                'end_time': '\${endTime!.hour.toString().padLeft(2, '0')}:\${endTime!.minute.toString().padLeft(2, '0')}',
                'grace_period_mins': int.tryParse(graceCtrl.text) ?? 15,
                'weekly_offs': selectedOffs,
                'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
              });`
);

code = code.replace(
  /Future<void> _editShift\(Map<String, dynamic> s\) async \{[\s\S]*?final selectedOffs = List<String>\.from\(s\['weekly_offs'\] \?\? \['Sunday'\]\);/,
  `Future<void> _editShift(Map<String, dynamic> s) async {
    final nameCtrl  = TextEditingController(text: s['name']?.toString() ?? '');
    final graceCtrl = TextEditingController(text: s['grace_period_mins']?.toString() ?? '15');
    String? selectedOfficeId = s['office_id']?.toString();
    final selectedOffs = List<String>.from(s['weekly_offs'] ?? ['Sunday']);`
);

code = code.replace(
  /await ApiClient\.put\('\$\{ApiEndpoints\.hrmsShifts\}\/\$\{s\['id'\]\}', \{\s*'name': nameCtrl\.text\.trim\(\),[\s\S]*?'weekly_offs': selectedOffs,\s*'is_active': s\['is_active'\] != false,\s*\}\);/,
  `await ApiClient.put('\${ApiEndpoints.hrmsShifts}/\${s['id']}', {
                'name': nameCtrl.text.trim(),
                'start_time': '\${startTime!.hour.toString().padLeft(2, '0')}:\${startTime!.minute.toString().padLeft(2, '0')}',
                'end_time': '\${endTime!.hour.toString().padLeft(2, '0')}:\${endTime!.minute.toString().padLeft(2, '0')}',
                'grace_period_mins': int.tryParse(graceCtrl.text) ?? 15,
                'weekly_offs': selectedOffs,
                'is_active': s['is_active'] != false,
                'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
              });`
);

// 12. Update _addLeaveType and _editLeaveType
code = code.replace(
  /Future<void> _addLeaveType\(\) async \{[\s\S]*?bool isPaid = true;/,
  `Future<void> _addLeaveType() async {
    final nameCtrl  = TextEditingController();
    final quotaCtrl = TextEditingController(text: '14');
    String? selectedOfficeId = _selectedOfficeFilter == 'all' ? null : _selectedOfficeFilter;
    bool isPaid = true;`
);

code = code.replace(
  /onChanged: \(v\) => setS\(\(\) => isPaid = v\),\s*\),\s*\]\),\s*\]\),/,
  `onChanged: (v) => setS(() => isPaid = v),
              ),
            ]),
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
          ]),`
);

code = code.replace(
  /await ApiClient\.post\(ApiEndpoints\.hrmsLeaveTypes, \{\s*'name'\s*: nameCtrl\.text\.trim\(\),\s*'annual_quota': int\.tryParse\(quotaCtrl\.text\) \?\? 14,\s*'is_paid'\s*: isPaid,\s*\}\);/,
  `await ApiClient.post(ApiEndpoints.hrmsLeaveTypes, {
              'name': nameCtrl.text.trim(),
              'annual_quota': int.tryParse(quotaCtrl.text) ?? 14,
              'is_paid': isPaid,
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });`
);

code = code.replace(
  /Future<void> _editLeaveType\(Map<String, dynamic> l\) async \{[\s\S]*?bool isPaid = l\['is_paid'\] != false;/,
  `Future<void> _editLeaveType(Map<String, dynamic> l) async {
    final nameCtrl  = TextEditingController(text: l['name']?.toString() ?? '');
    final quotaCtrl = TextEditingController(text: l['annual_quota']?.toString() ?? '14');
    String? selectedOfficeId = l['office_id']?.toString();
    bool isPaid = l['is_paid'] != false;`
);

code = code.replace(
  /await ApiClient\.put\('\$\{ApiEndpoints\.hrmsLeaveTypes\}\/\$\{l\['id'\]\}', \{\s*'name'\s*: nameCtrl\.text\.trim\(\),\s*'annual_quota': int\.tryParse\(quotaCtrl\.text\) \?\? 14,\s*'is_paid'\s*: isPaid,\s*'is_active'\s*: l\['is_active'\] != false,\s*\}\);/,
  `await ApiClient.put('\${ApiEndpoints.hrmsLeaveTypes}/\${l['id']}', {
              'name': nameCtrl.text.trim(),
              'annual_quota': int.tryParse(quotaCtrl.text) ?? 14,
              'is_paid': isPaid,
              'is_active': l['is_active'] != false,
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });`
);

// 13. Update _addSalaryComponent and _editSalaryComponent
code = code.replace(
  /Future<void> _addSalaryComponent\(\) async \{[\s\S]*?bool\s*isTaxable = true;/,
  `Future<void> _addSalaryComponent() async {
    final nameCtrl    = TextEditingController();
    final formulaCtrl = TextEditingController();
    String? selectedOfficeId = _selectedOfficeFilter == 'all' ? null : _selectedOfficeFilter;
    String nature    = 'Earning';
    String type      = 'Fixed';
    bool   isTaxable = true;`
);

code = code.replace(
  /if \(type != 'Fixed'\) \.\.\.\[[\s\S]*?Icons\.functions\),\s*\),\s*const SizedBox\(height: 8\),\s*Row\(mainAxisAlignment: MainAxisAlignment\.spaceBetween,/,
  `if (type != 'Fixed') ...[
              TextField(
                controller: formulaCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    type == 'Percentage'
                        ? 'Percentage of Basic *'
                        : 'Formula Expression *',
                    type == 'Percentage' ? 'e.g. 50' : 'e.g. Basic * 0.4',
                    Icons.functions),
              ),
              const SizedBox(height: 8),
            ],
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,`
);

code = code.replace(
  /await ApiClient\.post\(ApiEndpoints\.hrmsSalaryComponents, payload\);/,
  `payload['office_id'] = selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null;
            await ApiClient.post(ApiEndpoints.hrmsSalaryComponents, payload);`
);

code = code.replace(
  /Future<void> _editSalaryComponent\(Map<String, dynamic> c\) async \{[\s\S]*?bool\s*isTaxable = c\['is_taxable'\] == true;/,
  `Future<void> _editSalaryComponent(Map<String, dynamic> c) async {
    final nameCtrl    = TextEditingController(text: c['name']?.toString() ?? '');
    final formulaCtrl = TextEditingController(text: c['formula']?.toString() ?? '');
    String? selectedOfficeId = c['office_id']?.toString();
    String nature    = c['nature']?.toString() ?? 'Earning';
    String type      = c['type']?.toString()   ?? 'Fixed';
    bool   isTaxable = c['is_taxable'] == true;`
);

code = code.replace(
  /await ApiClient\.put\('\$\{ApiEndpoints\.hrmsSalaryComponents\}\/\$\{c\['id'\]\}', payload\);/,
  `payload['office_id'] = selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null;
            await ApiClient.put('\${ApiEndpoints.hrmsSalaryComponents}/\${c['id']}', payload);`
);

// 14. Update _addPayStructure and _editPayStructure
code = code.replace(
  /Future<void> _addPayStructure\(\) async \{[\s\S]*?final Set<int> selectedIds = \{\};/,
  `Future<void> _addPayStructure() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedOfficeId = _selectedOfficeFilter == 'all' ? null : _selectedOfficeFilter;
    final Set<int> selectedIds = {};`
);

code = code.replace(
  /TextField\(\s*controller: descCtrl,[\s\S]*?Icons\.notes\),\s*\),\s*if \(_salaryComps\.isNotEmpty\) \.\.\.\[/,
  `TextField(
              controller: descCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor(
                  'Description', 'Optional notes', Icons.notes),
            ),
            _buildOfficeSelector(
              selectedOfficeId: selectedOfficeId,
              onChanged: (v) => setS(() => selectedOfficeId = v),
            ),
            if (_salaryComps.isNotEmpty) ...[`
);

code = code.replace(
  /await ApiClient\.post\(ApiEndpoints\.hrmsPayStructures, \{\s*'name'\s*: nameCtrl\.text\.trim\(\),[\s\S]*?'componentIds': selectedIds\.toList\(\),\s*\}\);/,
  `await ApiClient.post(ApiEndpoints.hrmsPayStructures, {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'componentIds': selectedIds.toList(),
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });`
);

code = code.replace(
  /Future<void> _editPayStructure\(Map<String, dynamic> p\) async \{[\s\S]*?final Set<int> selectedIds = rawComps/,
  `Future<void> _editPayStructure(Map<String, dynamic> p) async {
    final nameCtrl = TextEditingController(text: p['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: p['description']?.toString() ?? '');
    String? selectedOfficeId = p['office_id']?.toString();
    final rawComps = (p['hr_salary_components'] as List? ?? p['components'] as List? ?? []);
    final Set<int> selectedIds = rawComps`
);

code = code.replace(
  /await ApiClient\.put\('\$\{ApiEndpoints\.hrmsPayStructures\}\/\$\{p\['id'\]\}', \{\s*'name'\s*: nameCtrl\.text\.trim\(\),[\s\S]*?'componentIds': selectedIds\.toList\(\),\s*'is_active'\s*: p\['is_active'\] != false,\s*\}\);/,
  `await ApiClient.put('\${ApiEndpoints.hrmsPayStructures}/\${p['id']}', {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'componentIds': selectedIds.toList(),
              'is_active': p['is_active'] != false,
              'office_id': selectedOfficeId != null ? int.tryParse(selectedOfficeId!) : null,
            });`
);

fs.writeFileSync(file, code, 'utf8');
console.log('Successfully patched hrms_masters_screen.dart!');
